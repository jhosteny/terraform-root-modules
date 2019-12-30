terraform {
  backend "s3" {}
}

provider "aws" {
  assume_role {
    role_arn = var.aws_assume_role_arn
  }
}

module "default_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
  attributes = var.attributes
  delimiter  = var.delimiter
}

locals {
  domain_name     = var.domain_name != "" ? var.domain_name : "${var.name}.${var.dns_zone_name}"
  tsa_domain_name = var.domain_name != "" ? "tsa-${var.domain_name}" : "${var.name}-tsa.${var.dns_zone_name}"
}

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=tags/0.8.1"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  cidr_block = "172.16.0.0/16"
}

data "aws_availability_zones" "available" {}

module "subnets" {
  source               = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.18.1"
  availability_zones   = data.aws_availability_zones.available.names
  namespace            = var.namespace
  stage                = var.stage
  name                 = var.name
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = true // TODO: needed?
  nat_instance_enabled = false
}

resource "random_pet" "rds_db_name" {
  separator = "_"
}

resource "random_string" "rds_admin_user" {
  length  = 8
  special = false
  number  = false
}

resource "random_password" "rds_admin_password" {
  length      = 16
  special     = true
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

module "rds" {
  source              = "git::https://github.com/cloudposse/terraform-aws-rds?ref=tags/0.17.0"
  namespace           = var.namespace
  stage               = var.stage
  name                = var.name
  attributes          = concat(var.attributes, ["rds"])
  database_name       = random_pet.rds_db_name.id
  database_user       = random_string.rds_admin_user.result
  database_password   = random_password.rds_admin_password.result
  database_port       = 5432
  multi_az            = false
  storage_type        = "gp2"
  allocated_storage   = "20"
  storage_encrypted   = true
  engine              = "postgres"
  engine_version      = "11.5"
  instance_class      = "db.t3.small"
  db_parameter_group  = "postgres11"
  publicly_accessible = false
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.subnets.private_subnet_ids
  security_group_ids  = [module.ecs.ecs_service_security_group_id]
  apply_immediately   = true
}

data "aws_kms_alias" "chamber" {
  name = var.chamber_kms_key_alias
}

module "worker_ssh_key" {
  source      = "git::https://github.com/cloudposse/terraform-aws-ssm-tls-ssh-key-pair.git?ref=tags/0.4.0"
  enabled     = var.concourse_worker_ssh_key_enabled
  namespace   = var.namespace
  stage       = var.stage
  name        = var.name
  kms_key_id  = data.aws_kms_alias.chamber.target_key_id
}

resource "aws_key_pair" "default" {
  key_name    = module.default_label.id
  public_key  = module.worker_ssh_key.public_key
}

module "worker" {
  source     = "git::https://github.com/jhosteny/terraform-aws-concourse-ec2-worker?ref=tags/0.0.1"
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
  attributes = concat(var.attributes, ["worker"])
  delimiter  = var.delimiter
  region     = var.region

  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.subnets.public_subnet_ids
  keys_bucket_id          = module.keys.bucket_id
  keys_bucket_arn         = module.keys.bucket_arn
  concourse_tsa_hostname  = local.tsa_domain_name
  ssh_key_name            = aws_key_pair.default.key_name
  associate_public_ip_address = true # TODO: disable
}

module "keys" {
  source     = "git::https://github.com/jhosteny/terraform-aws-concourse-keys-s3?ref=tags/0.0.1"
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
  attributes = concat(var.attributes, ["keys"])
  delimiter  = var.delimiter

  worker_iam_role_arns = [module.worker.worker_iam_role_arn]
  bucket_force_destroy = true
}

module "ecs" {
  source     = "git::https://github.com/jhosteny/terraform-aws-concourse-web?ref=tags/0.0.1"
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
  attributes = concat(var.attributes, ["ecs"])
  delimiter  = var.delimiter
  region     = var.region

  vpc_id                = module.vpc.vpc_id
  certificate_arn       = module.acm_request_certificate.arn
  tsa_certificate_arn   = module.acm_request_certificate_tsa.arn
  external_url_https    = "https://${local.domain_name}"
  public_subnet_ids     = module.subnets.public_subnet_ids
  private_subnet_ids    = module.subnets.private_subnet_ids
  db_security_group_id  = module.rds.security_group_id
  db_hostname           = module.rds.instance_address # TODO: hostname, if zone supplied
  db_port               = 5432
  db_name               = random_pet.rds_db_name.id
  db_version            = "11.5"
  db_admin_username     = random_string.rds_admin_user.result
  db_admin_password     = random_password.rds_admin_password.result
  keys_bucket_id        = module.keys.bucket_id
  keys_bucket_arn       = module.keys.bucket_arn
  chamber_kms_key_arn   = data.aws_kms_alias.chamber.target_key_arn

  concourse_github_auth_client_id     = var.concourse_github_auth_client_id
  concourse_github_auth_client_secret = var.concourse_github_auth_client_secret
  concourse_main_team_github_org      = var.concourse_main_team_github_org
  concourse_main_team_github_team     = var.concourse_main_team_github_team
}

data "aws_route53_zone" "default" {
  name = var.dns_zone_name
}

module "acm_request_certificate" {
  source      = "git::https://github.com/cloudposse/terraform-aws-acm-request-certificate.git?ref=tags/0.4.0"
  zone_name   = var.dns_zone_name
  domain_name = local.domain_name
  ttl         = 300
  tags        = var.tags
}

resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.default.zone_id
  name    = local.domain_name
  type    = "CNAME"
  ttl     = 300
  records = [module.ecs.alb_dns_name]
}

module "acm_request_certificate_tsa" {
  source      = "git::https://github.com/cloudposse/terraform-aws-acm-request-certificate.git?ref=tags/0.4.0"
  zone_name   = var.dns_zone_name
  domain_name = local.tsa_domain_name
  ttl         = 300
  tags        = var.tags
}

resource "aws_route53_record" "nlb" {
  zone_id = data.aws_route53_zone.default.zone_id
  name    = local.tsa_domain_name
  type    = "CNAME"
  ttl     = 300
  records = [module.ecs.nlb_dns_name]
}

data "aws_caller_identity" "default" {}

data "aws_iam_policy_document" "default" {
  statement {
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "${format("arn:aws:ssm:%s:%s:parameter/concourse/*", var.region, data.aws_caller_identity.default.account_id)}"
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = ["${data.aws_kms_alias.chamber.target_key_arn}"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "kms:ListAliases",
      "kms:ListKeys"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "default" {
  name   = module.default_label.id
  policy = data.aws_iam_policy_document.default.json
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = module.ecs.ecs_task_role_name
  policy_arn = aws_iam_policy.default.arn
}
