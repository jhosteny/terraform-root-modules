variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "vpc_nat_gateway_enabled" {
  type    = bool
  default = true
}

variable "vpc_nat_instance_enabled" {
  type        = bool
  description = "Flag to enable/disable NAT Instances to allow servers in the private subnets to access the Internet"
  default     = false
}

variable "vpc_nat_instance_type" {
  description = "NAT Instance type"
  default     = "t3.micro"
}

variable "vpc_max_subnet_count" {
  default     = 0
  description = "The maximum count of subnets to provision. 0 will provision a subnet for each availability zone within the region"
}

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=tags/0.8.1"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  cidr_block = var.vpc_cidr_block
  attributes = var.attributes
  tags       = var.tags
}

module "subnets" {
  source               = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.18.1"
  availability_zones   = local.availability_zones
  namespace            = var.namespace
  stage                = var.stage
  name                 = var.name
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = var.vpc_nat_gateway_enabled
  nat_instance_enabled = var.vpc_nat_instance_enabled
  nat_instance_type    = var.vpc_nat_instance_type
  max_subnet_count     = var.vpc_max_subnet_count
  attributes           = var.attributes
  tags                 = var.tags
}

resource "aws_ssm_parameter" "vpc_id" {
  description = "VPC ID of backing services"
  name        = format(var.chamber_parameter_name, local.chamber_service, "vpc_id")
  value       = module.vpc.vpc_id
  type        = "String"
  overwrite   = "true"
}

resource "aws_ssm_parameter" "igw_id" {
  description = "VPC ID of backing services"
  name        = format(var.chamber_parameter_name, local.chamber_service, "igw_id")
  value       = module.vpc.igw_id
  type        = "String"
  overwrite   = "true"
}

resource "aws_ssm_parameter" "cidr_block" {
  description = "VPC ID of backing services"
  name        = format(var.chamber_parameter_name, local.chamber_service, "cidr_block")
  value       = module.vpc.vpc_cidr_block
  type        = "String"
  overwrite   = "true"
}

resource "aws_ssm_parameter" "availability_zones" {
  name        = format(var.chamber_parameter_name, local.chamber_service, "availability_zones")
  value       = join(",", local.availability_zones)
  description = "VPC subnet availability zones"
  type        = "String"
  overwrite   = "true"
}

resource "aws_ssm_parameter" "nat_gateways" {
  count       = var.vpc_nat_gateway_enabled == "true" ? 1 : 0
  name        = format(var.chamber_parameter_name, local.chamber_service, "nat_gateways")
  value       = join(",", module.subnets.nat_gateway_ids)
  description = "VPC private NAT gateways"
  type        = "String"
  overwrite   = "true"
}

resource "aws_ssm_parameter" "nat_instances" {
  count       = var.vpc_nat_instance_enabled == "true" ? 1 : 0
  name        = format(var.chamber_parameter_name, local.chamber_service, "nat_instances")
  value       = join(",", module.subnets.nat_instance_ids)
  description = "VPC private NAT instances"
  type        = "String"
  overwrite   = "true"
}

resource "aws_ssm_parameter" "private_subnet_cidrs" {
  name        = format(var.chamber_parameter_name, local.chamber_service, "private_subnet_cidrs")
  value       = join(",", module.subnets.private_subnet_cidrs)
  description = "VPC private subnet CIDRs"
  type        = "String"
  overwrite   = "true"
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name        = format(var.chamber_parameter_name, local.chamber_service, "private_subnet_ids")
  value       = join(",", module.subnets.private_subnet_ids)
  description = "VPC private subnet IDs"
  type        = "String"
  overwrite   = "true"
}

resource "aws_ssm_parameter" "public_subnet_cidrs" {
  name        = format(var.chamber_parameter_name, local.chamber_service, "public_subnet_cidrs")
  value       = join(",", module.subnets.public_subnet_cidrs)
  description = "VPC public subnet CIDRs"
  type        = "String"
  overwrite   = "true"
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name        = format(var.chamber_parameter_name, local.chamber_service, "public_subnet_ids")
  value       = join(",", module.subnets.public_subnet_ids)
  description = "VPC public subnet IDs"
  type        = "String"
  overwrite   = "true"
}

/*
output "public_subnet_ids" {
  description = "Public subnet IDs of backing services"
  value       = [module.subnets.public_subnet_ids]
}

output "private_subnet_ids" {
  description = "Private subnet IDs of backing services"
  value       = [module.subnets.private_subnet_ids]
}
*/

output "vpc_id" {
  description = "VPC ID of backing services"
  value       = aws_ssm_parameter.vpc_id.value
}

output "igw_id" {
  description = "AWS ID of Internet Gateway for the VPC"
  value       = aws_ssm_parameter.igw_id.value
}

output "nat_gateways" {
  description = "Comma-separated string list of AWS IDs of NAT Gateways for the VPC"
  value       = join("",aws_ssm_parameter.nat_gateways.*.value)
}

output "cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_ssm_parameter.cidr_block.value
}

output "availability_zones" {
  description = "Comma-separated string list of avaialbility zones where subnets have been created"
  value       = aws_ssm_parameter.availability_zones.value
}

output "public_subnet_cidrs" {
  description = "Comma-separated string list of CIDR blocks of public VPC subnets"
  value       = aws_ssm_parameter.public_subnet_cidrs.value
}

output "public_subnet_ids" {
  description = "Comma-separated string list of public VPC subnet IDs"
  value       = aws_ssm_parameter.public_subnet_ids.value
}

output "private_subnet_cidrs" {
  description = "Comma-separated string list of CIDR blocks of private VPC subnets"
  value       = aws_ssm_parameter.private_subnet_cidrs.value
}

output "private_subnet_ids" {
  description = "Comma-separated string list of private VPC subnet IDs"
  value       = aws_ssm_parameter.private_subnet_ids.value
}
