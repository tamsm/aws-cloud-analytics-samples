variable "vpc_id" {
  type        = string
  description = "The subnets where redshift resides"
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "The subnets where redshift resides"
}

variable "kms_key_id" {
  type        = string
  description = "Arn of the customer managed key"
}

variable "tags" {
  description = "A map of default tags to be applied to the resources within this module"
  type        = map(string)
  default     = {
    stage       = "dev"
    instance    = "default"
    application = "default"
    name        = "default"
  }
}

variable "app_name" {
  type        = string
  description = "Data warehouse name"
}

variable "app_environment" {
  type        = string
  description = "Data warehouse name"
  default     = "dev"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "redshift_serverless_namespace_name" {
  type        = string
  description = "Redshift Serverless Namespace Name"
}

variable "redshift_serverless_database_name" {
  type        = string
  description = "Redshift Serverless Database Name"
}

variable "redshift_serverless_admin_username" {
  type        = string
  description = "Redshift Serverless Admin Username"
}


variable "redshift_serverless_workgroup_name" {
  type        = string
  description = "Redshift Serverless Workgroup Name"
}

variable "redshift_serverless_base_capacity" {
  type        = number
  description = "Redshift Serverless Base Capacity"
  default     = 32 // 32 RPUs to 512 RPUs in units of 8 (32,40,48...512)
}

variable "redshift_serverless_publicly_accessible" {
  type        = bool
  description = "Set the Redshift Serverless to be Publicly Accessible"
  default     = false
}

variable "redshift_serverless_allow_cidr_blocks" {
  type        = list(map(string))
  description = "List of allowed cidr blocks"
  default     = [{}]
}

variable "parameter_group_parameters" {
  description = "value"
  type        = map(any)
  default     = {}
}