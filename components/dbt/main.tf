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
  environment     = [{ "name" = "DBT_ENV_VAR", "value" = "some_value" }]
  command = ["dbt", "debug"]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-region        = var.aws_region
      awslogs-group         = aws_cloudwatch_log_group.logs.name
      awslogs-stream-prefix = aws_cloudwatch_log_stream.log_stream.name
      awslogs-stream-prefix = "ecs"
    }
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.tags.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256 # Minimal Fargate CPU (0.25 vCPU)
  memory                   = 512
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
  }
  tags = var.tags
}

# IAM
# ECS agent to perform actions: pull ECR; write logs
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

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
  name = "ecs_task_role"

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

resource "aws_iam_role" "redshift_data_api_role" {
  name = "${var.tags.stage}-${var.tags.instance}-dbt-role"

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

resource "aws_iam_policy" "redshift_data_api_policy" {
  name        = "${var.tags.stage}-${var.tags.instance}-dbt-policy"
  description = "Policy for accessing Redshift Data API"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "redshift:GetClusterCredentials",
          "redshift-data:ExecuteStatement",
          "redshift-data:GetStatementResult",
          "redshift-data:DescribeStatement"
        ]
        Effect   = "Allow"
        Resource = "*"
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

  # Allow outbound access to Redshift in private subnets
  egress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  # Allow inbound responses (from Redshift or other services if needed)
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }
}