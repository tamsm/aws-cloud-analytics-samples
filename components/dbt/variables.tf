variable "tags" {
  description = "A map of default tags to be applied to the resources within this module"
  type        = map(string)
  default     = {
    stage       = ""
    instance    = ""
    application = ""
    name        = ""
  }
}

variable "aws_region" {
  type        = string
  description = "Deployment target region"
}

variable "vpc_id" {
  type = string
}

variable "cidr_block" {
  type        = string
  description = "The cidr block used in vpc"
}

variable "subnets" {
  type        = list(string)
  default     = []
  description = "Destination subnets used ECS tasks. Ideally use private"
}

variable "container_image" {
  type        = string
  description = "The ECR dbt image"
}
