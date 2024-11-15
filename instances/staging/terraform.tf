# Terraform provider and backend configuration
provider "aws" {
  profile = "dev-admin"
  region  = "eu-west-1"
}

terraform {
  backend "s3" {
    bucket         = "data-lake-infrastructure"
    key            = "dev/kz-heide/data-infrastructure.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "tf-backend"
    encrypt        = true
  }
}