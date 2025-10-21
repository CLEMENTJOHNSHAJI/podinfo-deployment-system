# Podinfo Multi-Target Deployment Infrastructure
# This module creates the complete AWS infrastructure for secure, multi-target deployment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values
locals {
  name_prefix = "podinfo"
  common_tags = {
    Project     = "PodinfoDeployment"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  # Security defaults
  default_ports = {
    http  = 80
    https = 443
    app   = 8080
  }
  
  health_paths = {
    readiness = "/healthz"
    liveness  = "/healthz"
    metrics   = "/metrics"
  }
  
  timeouts = {
    deployment = "15m"
    health_check = "5m"
    rollback = "10m"
  }
}

# Global Infrastructure Module
module "global" {
  source = "./global"
  
  name_prefix = local.name_prefix
  environment = var.environment
  common_tags = local.common_tags
  
  # GitHub OIDC Configuration
  github_org  = var.github_org
  github_repo = var.github_repo
  github_branch = var.github_branch
  
  # ECR Configuration
  ecr_repositories = [
    "podinfo",
    "podinfo-lambda"
  ]
  
  # KMS Configuration
  enable_kms = true
  kms_key_rotation = true
}

# Secrets Management Module
module "secrets" {
  source = "./secrets"
  
  name_prefix  = local.name_prefix
  environment  = var.environment
  enable_rotation = var.enable_secrets_rotation
}

# Lambda Infrastructure Module
module "lambda" {
  source = "./lambda"
  
  name_prefix = local.name_prefix
  environment = var.environment
  common_tags = local.common_tags
  
  # API Gateway Configuration
  api_gateway_name = "${local.name_prefix}-api"
  api_stage_name   = var.environment
  
  # Lambda Configuration
  lambda_function_name = "${local.name_prefix}-lambda"
  lambda_timeout = 30
  lambda_memory = 512
  
  # ECR Repository
  ecr_repository_url = module.global.ecr_repository_urls["podinfo-lambda"]
  
  # CodeDeploy Configuration
  codedeploy_app_name = "${local.name_prefix}-lambda-deploy"
  codedeploy_group_name = "${local.name_prefix}-lambda-group"
  
  # SNS Topic for notifications
  sns_topic_arn = module.global.sns_topic_arn
  
  # Security - will be configured after Lambda is created
  vpc_config = {
    vpc_id             = module.ec2.vpc_id
    subnet_ids         = module.ec2.private_subnet_ids
    security_group_ids = []
  }
  
  depends_on = [module.global, module.ec2]
}

# EC2 Infrastructure Module
module "ec2" {
  source = "./ec2"
  
  name_prefix = local.name_prefix
  environment = var.environment
  common_tags = local.common_tags
  
  # VPC Configuration
  vpc_cidr = "10.0.0.0/16"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # ALB Configuration
  alb_name = "${local.name_prefix}-alb"
  alb_internal = false
  
  # Auto Scaling Configuration
  asg_name = "${local.name_prefix}-asg"
  asg_min_size = var.asg_min_size
  asg_max_size = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity
  
  # Instance Configuration
  instance_type = var.instance_type
  instance_ami = data.aws_ami.amazon_linux.id
  
  # Application Configuration
  app_port = local.default_ports.app
  health_check_path = local.health_paths.readiness
  
  # CodeDeploy Configuration
  codedeploy_app_name = "${local.name_prefix}-ec2-deploy"
  codedeploy_group_name = "${local.name_prefix}-ec2-group"
  
  # ECR Repository
  ecr_repository_url = module.global.ecr_repository_urls["podinfo"]
  
  # SNS Topic for notifications
  sns_topic_arn = module.global.sns_topic_arn
  
  depends_on = [module.global]
}


# Observability Module
module "observability" {
  source = "./global/observability"
  
  name_prefix = local.name_prefix
  environment = var.environment
  common_tags = local.common_tags
  
  # CloudWatch Configuration
  log_groups = [
    "${local.name_prefix}-lambda",
    "${local.name_prefix}-ec2",
    "${local.name_prefix}-alb"
  ]
  
  # Dashboard Configuration
  dashboard_name = "${local.name_prefix}-dashboard"
  
  # Alarms Configuration
  alarms = {
    lambda_errors = {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      threshold   = 5
    }
    ec2_cpu_high = {
      metric_name = "CPUUtilization"
      namespace   = "AWS/EC2"
      threshold   = 80
    }
    alb_target_health = {
      metric_name = "TargetResponseTime"
      namespace   = "AWS/ApplicationELB"
      threshold   = 2.0
    }
  }
  
  # SNS Topic for notifications
  sns_topic_arn = module.global.sns_topic_arn
  
  depends_on = [module.lambda, module.ec2, module.global]
}

# Data source for Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Variables are now defined in variables.tf

# Outputs
output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.global.ecr_repository_urls
}

output "secret_arn" {
  description = "ARN of the application secret"
  value       = module.secrets.secret_arn
}

output "secret_name" {
  description = "Name of the application secret"
  value       = module.secrets.secret_name
}

output "lambda_function_url" {
  description = "Lambda function URL"
  value       = module.lambda.function_url
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.ec2.alb_dns_name
}


output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = module.observability.dashboard_url
}
