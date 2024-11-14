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
  #4,091 usable IP addresses in a /20 network
  cidr = "10.0.0.0/20"
  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  # use the > cidrsubnet("10.0.0.0/20", 3,n) for an even split across 3 az's
  public_subnets  = ["10.0.2.0/23", "10.0.4.0/23", "10.0.6.0/23"]
  private_subnets = ["10.0.8.0/23", "10.0.10.0/23", "10.0.12.0/23"]

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
  #
  users                         = []
  # list of additional sg's: [redshift, airflow, etc.]
  additional_security_group_ids = [module.redshift.aws_redshiftserverless_server_sg]
  # list incoming tunnel IP's below
  source_ip_cidrs               = []
  tags                          = merge(
    local.tags, { Terraform = "true" }
  )
}