# ECS: cluster, task-definition, container-definition, service
resource "aws_ecs_cluster" "this" {
  name = var.tags.name
  tags = var.tags
}

module "dbt_ecs" {
  source = "cloudposse/ecs-container-definition/aws"
  version = "0.61.1"
  container_image = var.container_image
  container_name  = "${var.tags.stage}-${var.tags.instance}-dbt"
  # cpu             = 256 # Minimal Fargate CPU (0.25 vCPU)
  # memory          = 512 # Minimal Fargate Memory (0.5 GB)
  essential       = true
  # TODO: figure out env or file injection
  environment     = [
    { "name" = "AWS_REGION",  "value" = "${var.aws_region}" },
    { "name" = "IAM_PROFILE", "value" = "${var.tags.stage}-${var.tags.instance}-dbt-core-task" },
    { "name" = "CLUSTER_ID",  "value" = "${var.cluster_id}" },
    { "name" = "DB_HOST",     "value" = "${var.hostname}" },
    { "name" = "DBT_USER",    "value" = "admin" }
  ]
  command = ["dbt", "debug"]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-region        = var.aws_region
      awslogs-group         = aws_cloudwatch_log_group.logs.name
      awslogs-stream-prefix = "ecs"
    }
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.tags.stage}-${var.tags.instance}-dbt-core"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256 # Minimal Fargate CPU (0.25 vCPU)
  memory                   = 512 # Minimal Fargate Memory (0.5 GB)
  container_definitions    = "[${module.dbt_ecs.json_map_encoded}]"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  tags                     = var.tags
}

resource "aws_ecs_service" "this" {
  name             = var.tags.name
  cluster          = aws_ecs_cluster.this.name
  task_definition  = aws_ecs_task_definition.this.arn
  launch_type      = "FARGATE"
  desired_count    = 0
  platform_version = "1.4.0"

  network_configuration {
    security_groups = [aws_security_group.dbt_core_sg.id]
    subnets = var.subnets
    assign_public_ip = true
  }
  tags = var.tags
}

# IAM
# ECS agent to perform actions: pull ECR; write logs
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.tags.stage}-${var.tags.instance}-dbt-core-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_execution_policy" {
  name        = "${var.tags.name}-task-execution-policy"
  description = "Policy for ECS task to pull image and write logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:CreateLogGroup",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_policy.arn
}

# This role is used by the container itself
# Will use the redshift data api
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.tags.stage}-${var.tags.instance}-dbt-core-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_cloudwatch_log_group" "logs" {
  name              = "/ecs/${var.tags.stage}-${var.tags.instance}-dbt"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_stream" "log_stream" {
  log_group_name = aws_cloudwatch_log_group.logs.name
  name           = var.tags.name
}

# Security group for the ECS tasks
resource "aws_security_group" "dbt_core_sg" {
  name        = "${var.tags.stage}-${var.tags.instance}-dbt-core-sg"
  description = "Security group for dbt-core ECS tasks"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "allow_inbound" {
  security_group_id = aws_security_group.dbt_core_sg.id
  description = "Allow all inbound from vpc cidr"
  cidr_ipv4   = var.vpc_cidr_block
  from_port   = 0
  to_port     = 65535
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_443" {
  security_group_id = aws_security_group.dbt_core_sg.id
  description = "Allow all outbound traffic on 443, ecr, ssm, other services"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "allow_outbound_5439" {
  security_group_id = aws_security_group.dbt_core_sg.id
  description = "Allow outbound traffic on 5439,rs"
  cidr_ipv4   = var.vpc_cidr_block
  from_port   = 5439
  to_port     = 5439
  ip_protocol = "tcp"
}
# TODO: split the dbt project to another repo, &introduce git  pull $dbt-project within the container
# S3 bucket definition
module "dbt_files_bucket" {
  source      = "terraform-aws-modules/s3-bucket/aws"
  version     = "4.0.0"
  # S3 bucket name
  bucket      = "${var.tags.stage}-${var.tags.instance}-dbt"
  # Tags for the bucket
  tags = var.tags
  # Enable versioning for safety
  versioning = {
    enabled = true
  }
  # Make the bucket private
}

resource "aws_s3_object" "this" {
  for_each = fileset(var.dbt_project_dir, "**/*")
  bucket   = module.dbt_files_bucket.s3_bucket_id
  key      = each.value
  source   = "${var.dbt_project_dir}/${each.value}"
  etag     = filemd5("${var.dbt_project_dir}/${each.value}")
}

resource "aws_iam_policy" "ecs_task_s3_access_policy" {
  name        = "ecs_task_s3_access_policy"
  description = "Policy for accessing S3 bucket with dbt files"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          module.dbt_files_bucket.s3_bucket_arn,
          "${module.dbt_files_bucket.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_access_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_s3_access_policy.arn
}

resource "aws_iam_policy" "dbt_redshift_iam_policy" {
  name        = "dbt_redshift_iam_policy"
  description = "Policy to allow dbt to access Redshift using IAM authentication"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "redshift:GetClusterCredentials",
          "redshift:DescribeClusters",
          "redshift-data:ExecuteStatement",
          "redshift-data:GetStatementResult",
          "redshift-data:DescribeStatement"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dbt_redshift_iam_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.dbt_redshift_iam_policy.arn
}