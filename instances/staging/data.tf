data "aws_availability_zones" "this" {
  state = "available"
}

data "aws_region" "this" {}