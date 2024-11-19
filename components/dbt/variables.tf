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

variable "vpc_cidr_block" {
  type        = string
  description = "The cidr block used in vpc"
}

variable "subnets" {
  type        = list(string)
  default     = []
  description = "Destination subnets used ECS tasks. Ideally use private"
}
# TODO: use when placed private subnets, vpc-endpoints for s3, ecr, logs, etc.
variable "private_route_table_ids" {
  type        = list(string)
  default     = []
  description = "Private route table ids needed for S3 vpc-endpoint"
}

variable "container_image" {
  type        = string
  description = "The ECR dbt image"
}
