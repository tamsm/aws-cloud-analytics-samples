# create Redshift Serverless Namespace
resource "aws_redshiftserverless_namespace" "serverless" {
  namespace_name      = var.redshift_serverless_namespace_name
  db_name             = var.redshift_serverless_database_name
  admin_username      = var.redshift_serverless_admin_username
  admin_user_password = random_password.this.result
  kms_key_id          = var.kms_key_id
  iam_roles           = [aws_iam_role.redshift-serverless-role.arn]
  # export all three https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-audit-logging.html
  log_exports         = ["userlog","connectionlog","useractivitylog"]
  tags = var.tags
}

################################################

# create the Redshift Serverless Workgroup
resource "aws_redshiftserverless_workgroup" "serverless" {
  namespace_name = aws_redshiftserverless_namespace.serverless.id
  workgroup_name = var.redshift_serverless_workgroup_name
  base_capacity  = var.redshift_serverless_base_capacity
  enhanced_vpc_routing = true
  port           = 5439
  security_group_ids  = [aws_security_group.redshift_server.id]
  subnet_ids          = var.vpc_subnet_ids
  publicly_accessible = var.redshift_serverless_publicly_accessible

  tags = merge( var.tags, {name = "${var.tags.name}-workgroup"})
}

resource "aws_redshiftserverless_endpoint_access" "serverless" {
  workgroup_name = aws_redshiftserverless_workgroup.serverless.workgroup_name
  endpoint_name  = "${var.tags.name}-main"   # Customize the endpoint name
  subnet_ids = var.vpc_subnet_ids
  vpc_security_group_ids = [aws_security_group.redshift_client.id]
}


# Create an IAM Role for Redshift
resource "aws_iam_role" "redshift-serverless-role" {
  name = "${var.app_name}-${var.app_environment}-redshift-serverless-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })
  tags = var.tags
}

# Create and assign an IAM Role Policy to access S3 Buckets
resource "aws_iam_role_policy" "redshift-s3-full-access-policy" {
  name = "${var.app_name}-${var.app_environment}-redshift-serverless-role-s3-policy"
  role = aws_iam_role.redshift-serverless-role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "*"
      }
    ]
  })
}

# Get the AmazonRedshiftAllCommandsFullAccess policy
data "aws_iam_policy" "redshift_full_access_policy" {
  name = "AmazonRedshiftAllCommandsFullAccess"
}

# Attach the policy to the Redshift role
resource "aws_iam_role_policy_attachment" "redshift_full_access_policy" {
  role       = aws_iam_role.redshift-serverless-role.name
  policy_arn = data.aws_iam_policy.redshift_full_access_policy.arn
}
#################
# Security Groups
#################

resource "aws_security_group" "redshift_server" {
  name        = "${var.app_environment}-${var.app_name}-redshift-server"
  description = "Access from Redshift cluster ${var.app_environment}-${var.app_name} server SG"
  vpc_id      = var.vpc_id

  tags = var.tags
}

resource "aws_security_group_rule" "redshift_ingress_clients_remote_sg" {
  count             = length(var.redshift_serverless_allow_cidr_blocks)
  security_group_id = aws_security_group.redshift_server.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 5439
  to_port           = 5439
  cidr_blocks       = [element(keys(var.redshift_serverless_allow_cidr_blocks[count.index]), 0)]
  description       = "allow ${element(values(var.redshift_serverless_allow_cidr_blocks[count.index]), 0)}"
}

resource "aws_security_group_rule" "redshift_ingress_client" {
  security_group_id = aws_security_group.redshift_server.id
  description       = "Incoming connections from ${aws_security_group.redshift_client.name} SG"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 5349
  to_port           = 5349
  source_security_group_id = aws_security_group.redshift_client.id
}

# This could be further limited to access only to S3, but then we would also have to
# limit access to buckets outside of our own ones via the VPCe.
# allow any traffic to port 443.

resource "aws_security_group_rule" "redshift_egress_https" {
  security_group_id = aws_security_group.redshift_server.id
  description       = "Allow outbound traffic to port 443"
  type        = "egress"
  protocol    = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group" "redshift_client" {
  name        = "${var.tags.name}-redshift-client-sg"
  description = "Access to Redshift cluster ${var.app_name}-${var.app_environment} client SG"
  vpc_id      = var.vpc_id
  tags = var.tags
}

resource "aws_security_group_rule" "redshift_client_egress_server" {
  security_group_id = aws_security_group.redshift_client.id
  description       = "Egress connections to ${aws_security_group.redshift_server.name}."

  type      = "egress"
  protocol  = "tcp"
  from_port = 5439
  to_port   = 5439

  source_security_group_id = aws_security_group.redshift_server.id
}

resource "aws_security_group_rule" "redshift_allow_sec_group_self" {
  security_group_id = aws_security_group.redshift_server.id
  type              = "ingress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  self              = true
  description       = "allow self"
}

resource "aws_security_group_rule" "redshift_allow_all_outbound" {
  security_group_id = aws_security_group.redshift_server.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow everyone for any outbound port"
}



resource "random_password" "this" {
  length           = 16
  special          = true
  override_special = "_%@"
}