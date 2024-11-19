# Initialising local variables for a basic tagging and resource naming
locals {
  stage    = "staging"
  instance = "kzheide"
  app      = "dw"
  name     = "${local.stage}-${local.instance}-${local.app}"
  tags     = {
    stage    = local.stage
    instance = local.instance
    app      = local.app
    name     = local.name
  }
}
# Contains: KMS key
module "base" {
  source = "../../components/base"
  tags = local.tags
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${local.name}-lakehouse-vpc"
  #4,096 -(5 aws-reserved) reusable IP addresses in a /20 network
  cidr = "10.0.0.0/20"
  azs             = ["eu-west-1a", "eu-west-1b"]
  # use the > cidrsubnet("10.0.0.0/20", 2,n) for an even split across 2 az's
  public_subnets  = ["10.0.0.0/22", "10.0.4.0/22"]
  private_subnets = ["10.0.8.0/22", "10.0.12.0/22"]

  #  enable_nat_gateway = true
  #  enable_vpn_gateway = true

  tags = merge(
    local.tags, { Terraform = "true" }
  )
}

module "redshift" {
  source                                  = "../../components/redshift"
  aws_region                              = data.aws_region.this.name
  vpc_id                                  = module.vpc.vpc_id
  vpc_subnet_ids                          = module.vpc.private_subnets
  kms_key_id                              = module.base.kms_key_arn
  redshift_serverless_workgroup_name      = "${local.name}"
  redshift_serverless_namespace_name      = "${local.name}"
  redshift_serverless_database_name       = local.app
  redshift_serverless_admin_username      = "admin"
  redshift_serverless_publicly_accessible = false
  app_name                                = "${local.name}"
  redshift_serverless_allow_cidr_blocks   = [
    { "95.91.243.228/32" : "home" }
  ]
  tags = local.tags
}

module "bastion_host" {
  source     = "../../components/bastion-host"
  instance_type = "t4g.micro"
  ubuntu_version = "24.04"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets
  # name, shell, ssh_authorized_keys
  users                         = []
  # list of additional sg's: [redshift, airflow, etc.]
  additional_security_group_ids = [module.redshift.aws_redshiftserverless_server_sg]
  # list incoming tunnel IP's below
  source_ip_cidrs               = []
  tags                          = merge(
    local.tags, { Terraform = "true" }
  )
}

module "mwaa" {
  version = "0.0.6"
  source = "aws-ia/mwaa/aws"

  name = "${local.name}-airflow"
  airflow_version      = "2.9.2"
  environment_class    = "mw1.small"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnets
  kms_key               = module.base.kms_key_arn
  min_workers           = 1
  max_workers           = 3
  webserver_access_mode = "PUBLIC_ONLY" # Default PRIVATE_ONLY for production environments
  weekly_maintenance_window_start = "SUN:07:00"
  iam_role_additional_policies = {
    # "additional-policy-1" = "<ENTER_POLICY_ARN1>"
    # "additional-policy-2" = "<ENTER_POLICY_ARN2>"
  }

  logging_configuration = {
    dag_processing_logs = {
      enabled   = true
      log_level = "INFO"
    }

    scheduler_logs = {
      enabled   = true
      log_level = "INFO"
    }

    task_logs = {
      enabled   = true
      log_level = "INFO"
    }

    webserver_logs = {
      enabled   = true
      log_level = "INFO"
    }

    worker_logs = {
      enabled   = true
      log_level = "INFO"
    }
  }

  airflow_configuration_options = {
    "core.load_default_connections" = "false"
    "core.load_examples"            = "false"
    "webserver.dag_default_view"    = "tree"
    "webserver.dag_orientation"     = "TB"
    "logging.logging_level"         = "INFO"
  }
  tags = local.tags
}
# first version of dbt-core ecs container task
module "dbt" {
  source     = "../../components/dbt"
  aws_region = data.aws_region.this.name
  vpc_id     = module.vpc.vpc_id
  subnets    = module.vpc.public_subnets
  vpc_cidr_block = module.vpc.vpc_cidr_block
  container_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.this.name}.amazonaws.com/dbt-core-redshift"
  tags = merge(
    local.tags, { app = "dbt" }
  )
}