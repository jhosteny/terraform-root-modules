variable "namespace" {
  type        = string
  description = "Namespace (e.g. `eg` or `cp`)"
}

variable "stage" {
  type        = string
  description = "Stage (e.g. `prod`, `dev`, `staging`)"
}

variable "name" {
  type        = string
  description = "Distinguish the backing services from others"
  default     = "backing-services"
}

variable "attributes" {
  type        = list(string)
  description = "Additional attributes to distinguish the backing services from others in this account"
  default     = []
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags (e.g. map(`BusinessUnit`,`XYZ`)"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "availability_zones" {
  type        = list(string)
  description = "AWS region availability zones to use (e.g.: ['us-west-2a', 'us-west-2b']). If empty will use all available zones"
  default     = []
}

variable "chamber_service" {
  type        = string
  default     = "backing-services"
  description = "`chamber` service name. See [chamber usage](https://github.com/segmentio/chamber#usage) for more details"
}

variable "chamber_parameter_name" {
  type    = string
  default = "/%s/%s"
}
