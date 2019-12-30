module "chamber_kms_key" {
  source      = "git::https://github.com/cloudposse/terraform-aws-kms-key.git?ref=tags/0.1.0"
  namespace   = "${var.namespace}"
  stage       = "${var.stage}"
  name        = "chamber"
  description = "KMS key for chamber"
}

output "chamber_kms_key_arn" {
  value       = "${module.chamber_kms_key.key_arn}"
  description = "KMS key ARN"
}

output "chamber_kms_key_id" {
  value       = "${module.chamber_kms_key.key_id}"
  description = "KMS key ID"
}

output "chamber_kms_key_alias_arn" {
  value       = "${module.chamber_kms_key.alias_arn}"
  description = "KMS key alias ARN"
}

output "chamber_kms_key_alias_name" {
  value       = "${module.chamber_kms_key.alias_name}"
  description = "KMS key alias name"
}

resource "aws_ssm_parameter" "chamber_kms_key_arn" {
  name        = "${format("/chamber/%s", "chamber_kms_key_arn")}"
  value       = "${module.chamber_kms_key.key_arn}"
  description = "Chamber KMS Key ARN"
  type        = "String"
  overwrite   = "true"
}
