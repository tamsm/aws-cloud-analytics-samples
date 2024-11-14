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

variable "vpc_id" {}

variable "subnet_ids" {
  type = list(any)
}

variable "ubuntu_version" {
  default     = "24.04"
  description = "Will be used to search for an AMI"
}

variable "instance_type" {
  default     = "t4g.micro"
  description = "The default instance type"
}

variable "users" {
  type = list(object({
    name                = string
    shell               = string
    ssh_authorized_keys = list(string)
  }))
  default = []
}

variable "source_ip_cidrs" {
  description = "CIDR ranges that are allowed as source IPs, CIDR as key, description as value"
  type        = list(string)
  default     = []
}

variable "additional_security_group_ids" {
  description = "Client security group IDs that should be attached and then allow incoming traffic to the DB server"
  type        = list(string)
  default     = []
}
