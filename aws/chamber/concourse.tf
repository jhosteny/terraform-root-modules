variable "aws_region" {
  type        = "string"
  description = "AWS region"
}

variable "zone_name" {
  type        = "string"
  description = "DNS zone name"
}

variable "concourse_kiam_enabled" {
  default     = "true"
  description = "Set to false to prevent the module from creating kiam resources for Concourse"
}

# Chamber KIAM role for Concourse CI/CD
module "concourse_kiam_ssm_role" {
  source        = "git::https://github.com/jhosteny/terraform-aws-kops-kiam-ssm-role.git?ref=master"
  namespace     = "${var.namespace}"
  stage         = "${var.stage}"
  name          = "kiam-ssm"
  enabled       = "${var.concourse_kiam_enabled}"
  attributes    = ["concourse"]
  cluster_name  = "${var.aws_region}.${var.zone_name}"
  kms_key_arn   = "${module.chamber_kms_key.key_arn}"

  ssm_resources = [
    "${format("arn:aws:ssm:%s:%s:parameter/concourse/*", data.aws_region.default.name, data.aws_caller_identity.default.account_id)}"
  ]
}

output "concourse_kiam_ssm_role_name" {
  value       = "${module.concourse_kiam_ssm_role.role_name}"
  description = "IAM role name"
}

output "concourse_kiam_ssm_role_arn" {
  value       = "${module.concourse_kiam_ssm_role.role_arn}"
  description = "IAM role ARN"
}
