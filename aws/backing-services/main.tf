terraform {
  backend "s3" {}
}

provider "aws" {
  assume_role {
    role_arn = var.aws_assume_role_arn
  }
}

variable "aws_assume_role_arn" {
  type = string
}

variable "zone_name" {
  type        = string
  description = "DNS zone name"
}

data "aws_availability_zones" "available" {}

data "aws_route53_zone" "default" {
  name = var.zone_name
}

data "aws_region" "current" {}

locals {
  null               = ""
  zone_id            = data.aws_route53_zone.default.zone_id
  availability_zones = length(var.availability_zones) == 0 ? data.aws_availability_zones.available.names : var.availability_zones
  # TODO: this no longer works with TF 0.12. The path /conf/backing-services/.module expands to .module
  chamber_service    = var.chamber_service == "" ? basename(pathexpand(path.module)) : var.chamber_service
  #  chamber_service    = var.chamber_service == "" ? basename(pathexpand("${path.root}/${path.module}")) : var.chamber_service
}

output "parameter_store_prefix" {
  value = format(var.chamber_parameter_name, local.chamber_service, "")
}

output "region" {
  description = "AWS region of backing services"
  value       = data.aws_region.current.name
}
