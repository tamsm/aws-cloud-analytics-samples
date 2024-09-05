variable "tags" {
  description = "A map of default tags to be applied to the resources within this module"
  type        = map(string)
  default     = {
    stage       = "dev"
    instance    = "default"
    app         = "default"
    name        = "default"
  }
}