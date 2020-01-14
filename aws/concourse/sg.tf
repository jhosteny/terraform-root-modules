resource "aws_security_group" "default" {
  description = "Controls access to the ECS instances"
  vpc_id      = var.vpc_id
  name        = module.default_label.id
  tags        = module.default_label.tags
}

resource "aws_security_group_rule" "ntp" {
  type              = "egress"
  security_group_id = aws_security_group.default.id
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "http" {
  type              = "egress"
  security_group_id = aws_security_group.default.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

// TODO: is this needed?
resource "aws_security_group_rule" "https" {
  type              = "egress"
  security_group_id = aws_security_group.default.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ssh" {
  type              = "egress"
  security_group_id = aws_security_group.default.id
  from_port         = 2222
  to_port           = 2222
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "postgres" {
  type                     = "egress"
  security_group_id        = aws_security_group.default.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.rds_security_group_id
}

resource "aws_security_group_rule" "http_in" {
  type                     = "ingress"
  security_group_id        = aws_security_group.default.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.alb.security_group_id
}

# See https://docs.aws.amazon.com/elasticloadbalancing/latest/network/target-group-register-targets.html#target-security-groups
data "aws_network_interfaces" "alb" {
  filter {
    name   = "description"
    values = ["ELB net/${module.nlb.nlb_name}/*"]
  }
}

data "aws_network_interface" "alb" {
  count = length(data.aws_network_interfaces.alb.ids)
  id    = sort(data.aws_network_interfaces.alb.ids)[count.index]
}

resource "aws_security_group_rule" "tsa_http_health_check_in" {
  count             = length(data.aws_network_interface.alb.*.id)
  type              = "ingress"
  security_group_id = aws_security_group.default.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["${data.aws_network_interface.alb.*.private_ip[count.index]}/32"]
  description       = "Ingress health check from NLB"
}

/*
data "aws_vpc" "default" {
  id = var.vpc_id
}

resource "aws_security_group_rule" "tsa_http_health_check_in" {
  type                      = "ingress"
  security_group_id         = aws_security_group.default.id
  from_port                 = 80
  to_port                   = 80
  protocol                  = "tcp"
  cidr_blocks               = [data.aws_vpc.default.cidr_block]
}
*/

resource "aws_security_group_rule" "tsa_ssh_in" {
  type              = "ingress"
  security_group_id = aws_security_group.default.id
  from_port         = 2222
  to_port           = 2222
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Ingress from NLB"
}

# It would probably be preferable to pass the security group
# to the RDS module, and let it apply the ingress rule, but
# the RDS is currently in a separate service group that must
# be stood up before concourse.
#
# TODO: use the aforementioned method if we refactor this to
# create a VPC and dedicated RDS instance for Concourse. That
# is probably the right course of action, so that roles created
# for different DBs do not get access to other DBs (among other
# reasons).
resource "aws_security_group_rule" "rds" {
  type                     = "ingress"
  security_group_id        = var.rds_security_group_id
  from_port                = var.rds_port
  to_port                  = var.rds_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.default.id
}
