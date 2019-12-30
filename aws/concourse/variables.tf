variable "aws_assume_role_arn" {
  type = string
}

variable "namespace" {
  type        = string
  description = "Namespace (e.g. `cp` or `cloudposse`)"
}

variable "stage" {
  type        = string
  description = "Stage (e.g. `prod`, `dev`, `staging`)"
}

variable "name" {
  type        = string
  description = "Application or solution name (e.g. `app`)"
  default     = "concourse"
}

variable "delimiter" {
  type        = string
  default     = "-"
  description = "Delimiter to be used between `namespace`, `stage`, `name` and `attributes`"
}

variable "attributes" {
  type        = list(string)
  default     = []
  description = "Additional attributes (e.g. `1`)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags (e.g. map(`BusinessUnit`,`XYZ`)"
}

variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-2"
}

variable "dns_zone_name" {
  type        = string
  description = "DNS zone name (E.g. staging.cloudposse.co)"
}

variable "domain_name" {
  type        = string
  description = "Domain name (E.g. staging.cloudposse.co)"
  default     = ""
}

variable "chamber_kms_key_alias" {
  type        = string
  description = "Alias of the chamber KMS key"
  default     = ""
}

variable "chamber_kms_key_id" {
  type        = string
  description = "ID of the chamber KMS key"
  default     = ""
}

variable "concourse_worker_ssh_key_enabled" {
  type        = bool
  description = "Boolean flag to enable / disable SSH worker access"
  default     = true
}

variable "concourse_github_auth_client_id" {
  description = "Github client id"
  default     = null
  type        = string
}

variable "concourse_github_auth_client_secret" {
  description = "Github client secret"
  default     = null
  type        = string
}

variable "concourse_main_team_github_org" {
  description = "Github team that can login"
  default     = null
  type        = string
}

variable "concourse_main_team_github_team" {
  description = "Github team that can login"
  default     = null
  type        = string
}

variable "concourse_version" {
  type        = string
  description = "Concourse version to use"
  default     = "5.8.0"
}
