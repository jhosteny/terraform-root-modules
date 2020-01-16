terraform {
  required_version = ">= 0.11.2"

  backend "s3" {}
}

provider "aws" {
  assume_role {
    role_arn = var.aws_assume_role_arn
  }
}

data "aws_region" "default" {}
data "aws_caller_identity" "default" {}

locals {
  public_subnet_ids  = compact(split(",", var.public_subnet_ids))
  private_subnet_ids = compact(split(",", var.private_subnet_ids))
  postgres_version   = coalesce(var.rds_engine_version, "latest")
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

# TODO: get this from chamber
resource "aws_key_pair" "default" {
  key_name   = module.default_label.id
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDEYuMFEnJ2maOFvuqdq9VAiWerQqmFIMtvUOolG+RCx/AhXX69vNDa6mo8N5DlD05ncPAWF3o71djTeoLbKOK/KZdaU7m7mYKoDZAJ3kSonnfY+xZwXV1wx8kupZTXilsw+kz3WmI4RCaVorFg5YuYUQnltWB0y2wQuU9LHZ9H0RH+S7AWODa3361NTVro/O8B+0JsbQdZolshm/xegbXyHDKUSHGT8oTV+me4ELZC0257HP6V0op1nqh6hPw65BD6pLkBOG79/BhUL/lDhHa9jlAOCL3fRjhmUR4FI2wfwWxMUmOwrzg1PEXa0S/eV/j3pouJivupENzxF2cAqvIR jhosteny@ITAM-306"
}

module "worker" {
  source     = "/home/jhosteny/src/github/jhosteny/terraform-aws-concourse-ec2-worker"
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
  attributes = concat(var.attributes, ["worker"])
  delimiter  = var.delimiter
  region     = var.region

  vpc_id                 = var.vpc_id
  subnet_ids             = local.public_subnet_ids
  ssh_key_name           = aws_key_pair.default.key_name
  keys_bucket_id         = module.keys.bucket_id
  keys_bucket_arn        = module.keys.bucket_arn
  concourse_tsa_hostname = local.tsa_domain_name
}

module "keys" {
  # TODO: pin to tag at some point
  source     = "git::https://github.com/jhosteny/terraform-aws-concourse-keys-s3?ref=master"
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
  attributes = concat(var.attributes, ["keys"])
  delimiter  = var.delimiter

  worker_iam_role_arns = [module.worker.worker_iam_role_arn]
  bucket_force_destroy = true
}

variable "alb_ingress_cidr_blocks_https" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of CIDR blocks allowed to access environment over HTTPS"
}

module "alb" {
  source             = "git::https://github.com/cloudposse/terraform-aws-alb.git?ref=tags/0.8.0"
  name               = var.name
  namespace          = var.namespace
  stage              = var.stage
  attributes         = compact(concat(var.attributes, ["alb"]))
  vpc_id             = var.vpc_id
  ip_address_type    = "ipv4"
  subnet_ids         = local.public_subnet_ids
  access_logs_region = var.region
  #security_group_ids = [aws_security_group.default.id]

  http_enabled              = false
  https_enabled             = true
  https_port                = 443
  target_group_port         = 80
  https_ingress_cidr_blocks = var.alb_ingress_cidr_blocks_https
  certificate_arn           = module.acm_request_certificate.arn
  health_check_interval     = 60
  health_check_path         = "/api/v1/info"
  health_check_matcher      = "200"

  alb_access_logs_s3_bucket_force_destroy = true
}

data "aws_route53_zone" "default" {
  name = var.dns_zone_name
}

resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.default.zone_id
  name    = local.domain_name
  type    = "CNAME"
  ttl     = 300
  records = [module.alb.alb_dns_name]
}

module "nlb" {
  # TODO: pin at specific version
  source             = "git::https://github.com/jhosteny/terraform-aws-nlb.git?ref=master"
  name               = var.name
  namespace          = var.namespace
  stage              = var.stage
  attributes         = compact(concat(var.attributes, ["nlb"]))
  vpc_id             = var.vpc_id
  ip_address_type    = "ipv4"
  subnet_ids         = local.public_subnet_ids
  access_logs_region = var.region

  tcp_enabled           = true
  tcp_port              = 2222
  target_group_port     = 2222
  certificate_arn       = module.acm_request_certificate_tsa.arn
  health_check_protocol = "HTTP"
  health_check_port     = 80
  health_check_interval = 30
  health_check_path     = "/api/v1/info"

  nlb_access_logs_s3_bucket_force_destroy = true
}

resource "aws_route53_record" "nlb" {
  zone_id = data.aws_route53_zone.default.zone_id
  name    = local.tsa_domain_name
  type    = "CNAME"
  ttl     = 300
  records = [module.nlb.nlb_dns_name]
}

data "aws_iam_policy_document" "ecs_task_key_policy" {
  statement {
    effect = "Allow"
    resources = [
      "${module.keys.bucket_arn}",
      "${module.keys.bucket_arn}/*"
    ]
    actions = [
      "s3:Get*",
      "s3:List*"
    ]
  }
}

module "task_key_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  context    = module.default_label.context
  attributes = compact(concat(var.attributes, ["task", "key"]))
}

resource "aws_iam_policy" "task_key" {
  name   = module.task_key_label.id
  policy = data.aws_iam_policy_document.ecs_task_key_policy.json
}

resource "aws_iam_role_policy_attachment" "task_key" {
  role       = module.web.ecs_task_role_name
  policy_arn = aws_iam_policy.task_key.arn
}

data "aws_iam_policy_document" "ecs_task_ssm_policy" {
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
      "${format("arn:aws:ssm:%s:%s:parameter/concourse/*", data.aws_region.default.name, data.aws_caller_identity.default.account_id)}"
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = ["${var.chamber_kms_key_arn}"]
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

module "task_ssm_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  context    = module.default_label.context
  attributes = compact(concat(var.attributes, ["task", "ssm"]))
}

resource "aws_iam_policy" "task_ssm" {
  name   = module.task_ssm_label.id
  policy = data.aws_iam_policy_document.ecs_task_ssm_policy.json
}

resource "aws_iam_role_policy_attachment" "task_ssm" {
  role       = module.web.ecs_task_role_name
  policy_arn = aws_iam_policy.task_ssm.arn
}

resource "aws_cloudwatch_log_group" "default" {
  name = module.default_label.id
  tags = module.default_label.tags
}

module "download_keys_container_definition" {
  source          = "git::https://github.com/cloudposse/terraform-aws-ecs-container-definition.git?ref=tags/0.22.0"
  container_name  = "download_keys"
  container_image = "mesosphere/aws-cli:latest"
  essential       = false
  command = [
    "s3",
    "cp",
    "s3://${module.keys.bucket_id}",
    "/concourse-keys",
    "--recursive"
  ]

  port_mappings = []
  mount_points = [
    {
      containerPath = "/concourse-keys",
      sourceVolume  = "concourse_keys"
    }
  ]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = var.region
      "awslogs-group"         = aws_cloudwatch_log_group.default.name
      "awslogs-stream-prefix" = "keys"
    }
    secretOptions = null
  }
}

resource "random_password" "concourse_db_password" {
  length  = 24
  number  = true
  special = false
}

module "create_db_container_definition" {
  source          = "git::https://github.com/cloudposse/terraform-aws-ecs-container-definition.git?ref=tags/0.22.0"
  container_name  = "create_db"
  container_image = "postgres:${local.postgres_version}"
  essential       = false
  port_mappings   = []
  command = [
    "/bin/sh",
    "-exc",
    # This command creates the database and adds a role for ATC with privileges.
    # It is complicated by the fact that it is designed to fail on genuine problems,
    # yet run to completion without error if the aforementioned steps are in any
    # state of application (e.g., unapplied, database created but role not created,
    # fully applied, etc.).
    #
    # The end effect is that the init containers are idempotent, and we can thus
    # update the task definition at will.
    <<-EOT
      psql <<-EOC
        \set ON_ERROR_STOP on
        SELECT 'CREATE DATABASE $CONCOURSE_POSTGRES_DATABASE' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$CONCOURSE_POSTGRES_DATABASE')\gexec
        DO
        \$\$
        BEGIN
          IF NOT EXISTS (
            SELECT
              FROM  pg_catalog.pg_roles
              WHERE rolname = '$CONCOURSE_POSTGRES_USER') THEN
            CREATE ROLE $CONCOURSE_POSTGRES_USER LOGIN PASSWORD '$CONCOURSE_POSTGRES_PASSWORD';
            GRANT ALL PRIVILEGES ON DATABASE $CONCOURSE_POSTGRES_DATABASE TO $CONCOURSE_POSTGRES_USER;
          ELSE
            ALTER ROLE $CONCOURSE_POSTGRES_USER WITH PASSWORD '$CONCOURSE_POSTGRES_PASSWORD';
          END IF;
        END
        \$\$;
      EOC
    EOT
  ]

  environment = [
    { name = "PGUSER", value = var.rds_admin_username },
    { name = "PGHOST", value = var.rds_hostname },
    { name = "PGPORT", value = var.rds_port },
    { name = "PGDATABASE", value = var.rds_db_name },
    { name = "PGPASSWORD", value = var.rds_admin_password },
    { name = "CONCOURSE_POSTGRES_USER", value = var.concourse_db_username },
    { name = "CONCOURSE_POSTGRES_PASSWORD", value = random_password.concourse_db_password.result },
    { name = "CONCOURSE_POSTGRES_DATABASE", value = var.concourse_db_name },
  ]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = var.region
      "awslogs-group"         = aws_cloudwatch_log_group.default.name
      "awslogs-stream-prefix" = "create_db"
    }
    secretOptions = null
  }
}

# ECS Cluster (needed even if using FARGATE launch type)
resource "aws_ecs_cluster" "default" {
  name = module.default_label.id
}

resource "aws_sns_topic" "sns_topic" {
  name = module.default_label.id
  tags = module.default_label.tags
}

module "web" {
  source     = "git::https://github.com/cloudposse/terraform-aws-ecs-web-app.git?ref=tags/0.26.0"
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
  attributes = compact(concat(var.attributes, ["web"]))
  delimiter  = var.delimiter
  region     = var.region
  vpc_id     = var.vpc_id

  container_image = "${var.concourse_docker_image}:${var.concourse_version}"
  command         = ["web"]
  task_cpu        = 1024
  task_memory     = 2048

  init_containers = [
    {
      container_definition = module.download_keys_container_definition.json_map,
      condition            = "SUCCESS"
    },
    {
      container_definition = module.create_db_container_definition.json_map,
      condition            = "SUCCESS"
    }
  ]

  container_port     = 80
  nlb_container_port = 2222

  port_mappings = [
    {
      hostPort      = 80,
      containerPort = 80,
      protocol      = "tcp"
    },
    {
      hostPort      = 2222,
      containerPort = 2222,
      protocol      = "tcp"
    },
  ]

  ulimits = [
    {
      name      = "nofile",
      softLimit = 20000,
      hardLimit = 20000
    }
  ]

  volumes = [
    {
      name                        = "concourse_keys",
      host_path                   = null,
      docker_volume_configuration = []
    }
  ]

  mount_points = [
    {
      containerPath = "/concourse-keys",
      sourceVolume  = "concourse_keys"
    }
  ]

  environment = [
    { name = "CONCOURSE_POSTGRES_HOST", value = var.rds_hostname },
    { name = "CONCOURSE_POSTGRES_PORT", value = var.rds_port },
    { name = "CONCOURSE_POSTGRES_USER", value = var.concourse_db_username },
    { name = "CONCOURSE_POSTGRES_PASSWORD", value = random_password.concourse_db_password.result },
    { name = "CONCOURSE_POSTGRES_DATABASE", value = var.concourse_db_name },
    { name = "CONCOURSE_EXTERNAL_URL", value = "https://${local.domain_name}" },
    { name = "CONCOURSE_BIND_PORT", value = 80 },
    { name = "CONCOURSE_GITHUB_CLIENT_ID", value = var.concourse_github_auth_client_id },
    { name = "CONCOURSE_GITHUB_CLIENT_SECRET", value = var.concourse_github_auth_client_secret },
    { name = "CONCOURSE_MAIN_TEAM_GITHUB_ORG", value = var.concourse_main_team_github_org },
    { name = "CONCOURSE_MAIN_TEAM_GITHUB_TEAM", value = var.concourse_main_team_github_team },
    { name = "CONCOURSE_AWS_SSM_REGION", value = var.region },
    { name = "LAUNCH_TYPE", value = "FARGATE" },
    { name = "VPC_ID", value = var.vpc_id }
  ]

  codepipeline_enabled  = false
  repo_owner            = "dummy"
  github_webhooks_token = "dummy"
  autoscaling_enabled   = var.autoscaling_enabled
  autoscaling_dimension = var.autoscaling_dimension

  aws_logs_region        = var.region
  ecs_cluster_arn        = aws_ecs_cluster.default.arn
  ecs_cluster_name       = aws_ecs_cluster.default.name
  ecs_private_subnet_ids = local.private_subnet_ids

  ecs_security_group_ids                            = [aws_security_group.default.id]
  alb_security_group                                = aws_security_group.default.arn
  alb_target_group_alarms_insufficient_data_actions = [aws_sns_topic.sns_topic.arn]
  alb_target_group_alarms_ok_actions                = [aws_sns_topic.sns_topic.arn]
  alb_target_group_alarms_alarm_actions             = [aws_sns_topic.sns_topic.arn]

  nlb_ingress_target_group_arn = module.nlb.default_target_group_arn
  alb_arn_suffix               = module.alb.alb_arn_suffix

  alb_ingress_healthcheck_path = "/api/v1/info"

  # Without authentication, both HTTP and HTTPS endpoints are supported
  alb_ingress_unauthenticated_listener_arns       = [module.alb.https_listener_arn]
  alb_ingress_unauthenticated_listener_arns_count = 1

  # All paths are unauthenticated
  alb_ingress_unauthenticated_paths             = ["/*"]
  alb_ingress_listener_unauthenticated_priority = 100
}

