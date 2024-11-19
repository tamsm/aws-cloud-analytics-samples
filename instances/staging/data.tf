data "aws_availability_zones" "this" {
  state = "available"
}

data "aws_region" "this" {}
data "aws_caller_identity" "current" {}
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}