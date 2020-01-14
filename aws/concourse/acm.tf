variable "subject_alternative_names" {
  type        = list(string)
  description = "A list of domains that should be SANs in the issued certificate"
  default     = []
}

variable "tsa_subject_alternative_names" {
  type        = list(string)
  description = "A list of domains that should be SANs in the issued certificate"
  default     = []
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

variable "tsa_domain_name" {
  type        = string
  description = "TSA domain name (E.g. staging.cloudposse.co)"
  default     = ""
}

locals {
  domain_name     = var.domain_name != "" ? var.domain_name : "${var.name}.${var.dns_zone_name}"
  tsa_domain_name = var.tsa_domain_name != "" ? var.tsa_domain_name : "${var.name}-tsa.${var.dns_zone_name}"

  subject_alternative_names = distinct(
    concat(
      var.subject_alternative_names,
      formatlist("*.%s", [local.domain_name])
    )
  )

  tsa_subject_alternative_names = distinct(
    concat(
      var.tsa_subject_alternative_names,
      formatlist("*.%s", [local.tsa_domain_name])
    )
  )
}

module "acm_request_certificate" {
  source                    = "git::https://github.com/cloudposse/terraform-aws-acm-request-certificate.git?ref=tags/0.4.0"
  zone_name                 = var.dns_zone_name
  domain_name               = local.domain_name
  ttl                       = 300
  subject_alternative_names = [] # local.subject_alternative_names
  tags                      = var.tags
}

module "acm_request_certificate_tsa" {
  source                    = "git::https://github.com/cloudposse/terraform-aws-acm-request-certificate.git?ref=tags/0.4.0"
  zone_name                 = var.dns_zone_name
  domain_name               = local.tsa_domain_name
  ttl                       = 300
  subject_alternative_names = [] # local.subject_alternative_names
  tags                      = var.tags
}
