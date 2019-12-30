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

variable "vpc_id" {
  type        = string
  description = "VPC ID for deployment"
}

variable "public_subnet_ids" {
  type        = string
  description = "Comma-separated string list of public VPC subnet IDs"
}

variable "private_subnet_ids" {
  type        = string
  description = "Comma-separated string list of private VPC subnet IDs"
}

variable "rds_security_group_id" {
  type        = string
  description = "RDS security group ID"
}

variable "rds_hostname" {
  description = "Postgresql server hostname or IP"
  type        = string
}

variable "rds_port" {
  description = "Port of the postgresql server"
  default     = "5432"
  type        = string
}

variable "rds_db_name" {
  description = "Default postgres database"
  default     = "postgres"
  type        = string
}


variable "rds_engine_version" {
  description = "Postgres engine version used in the Concourse database server. Only needed if `auto_create_db` is set to `true`"
  default     = null
  type        = string
}

variable "rds_admin_username" {
  description = "Admin user of the Postgres database server. Only needed if `auto_create_db` is set to `true`"
  default     = ""
  type        = string
}

variable "rds_admin_password" {
  description = "Admin password of the Postgres database server. Only needed if `auto_create_db` is set to `true`"
  default     = ""
  type        = string
}

variable "chamber_kms_key_arn" {
  type        = string
  description = "ARN of the chamber KMS key"
  default     = ""
}

variable "concourse_worker_ssh_key_name" {
  type        = string
  description = "SSH key name for access to the Concourse workers"
  default     = ""
}

variable "concourse_db_username" {
  description = "Database user to logon to postgresql"
  default     = "concourse"
  type        = string
}

variable "concourse_db_password" {
  description = "Password to logon to postgresql"
  type        = string
}

variable "auto_create_db" {
  description = "If set to `true`, the Concourse web container will attempt to create the postgres database if it's not already created"
  default     = true
  type        = bool
}

variable "concourse_db_name" {
  description = "Database name to use on the postgresql server"
  default     = "concourse"
  type        = string
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

variable "concourse_auth_username" {
  description = "Basic authentication username"
  default     = null
  type        = string
}

variable "concourse_auth_password" {
  description = "Basic authentication password"
  default     = null
  type        = string
}

variable "concourse_main_team_local_user" {
  description = "Local user to allow access to the main team"
  default     = null
  type        = string
}

variable "concourse_docker_image" {
  description = "Concourse docker image"
  default     = "concourse/concourse"
  type        = string
}

variable "concourse_version" {
  type        = string
  description = "Concourse version to use"
  default     = "5.8.0"
}

variable "autoscaling_enabled" {
  type        = bool
  description = "A boolean to enable/disable Autoscaling policy for ECS Service"
  default     = false
}

variable "autoscaling_dimension" {
  type        = string
  description = "Dimension to autoscale on (valid options: cpu, memory)"
  default     = "cpu"
}

