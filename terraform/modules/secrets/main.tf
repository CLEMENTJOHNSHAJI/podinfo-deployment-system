# Secrets Management Module
# Creates AWS Secrets Manager secrets with rotation policies

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Secrets Manager Secrets
resource "aws_secretsmanager_secret" "secrets" {
  for_each = var.secrets
  
  name                    = each.key
  description             = each.value.description
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = 7
  
  tags = merge(var.common_tags, {
    Name = each.key
  })
}

# Initial secret values
resource "aws_secretsmanager_secret_version" "secrets" {
  for_each = aws_secretsmanager_secret.secrets
  
  secret_id = each.value.id
  secret_string = jsonencode({
    username = "podinfo-user"
    password = random_password.secrets[each.key].result
    token    = random_password.tokens[each.key].result
    api_key  = random_password.api_keys[each.key].result
  })
}

# Random passwords for secrets
resource "random_password" "secrets" {
  for_each = var.secrets
  
  length  = 32
  special = true
}

# Random tokens for secrets
resource "random_password" "tokens" {
  for_each = var.secrets
  
  length  = 64
  special = false
}

# Random API keys for secrets
resource "random_password" "api_keys" {
  for_each = var.secrets
  
  length  = 48
  special = false
}

# Rotation Lambda Function
resource "aws_lambda_function" "rotation" {
  for_each = { for k, v in var.secrets : k => v if v.rotation_days > 0 }
  
  function_name = "${var.name_prefix}-rotation-${replace(each.key, "/", "-")}"
  role          = aws_iam_role.rotation[each.key].arn
  handler       = "index.handler"
  runtime       = "python3.9"
  timeout       = 60
  
  filename         = data.archive_file.rotation[each.key].output_path
  source_code_hash = data.archive_file.rotation[each.key].output_base64sha256
  
  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.secrets[each.key].arn
    }
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rotation-${replace(each.key, "/", "-")}"
  })
}

# Rotation Lambda IAM Role
resource "aws_iam_role" "rotation" {
  for_each = { for k, v in var.secrets : k => v if v.rotation_days > 0 }
  
  name = "${var.name_prefix}-rotation-${replace(each.key, "/", "-")}-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rotation-${replace(each.key, "/", "-")}-role"
  })
}

# Rotation Lambda IAM Policy
resource "aws_iam_policy" "rotation" {
  for_each = { for k, v in var.secrets : k => v if v.rotation_days > 0 }
  
  name        = "${var.name_prefix}-rotation-${replace(each.key, "/", "-")}-policy"
  description = "Policy for secret rotation Lambda"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.secrets[each.key].arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rotation-${replace(each.key, "/", "-")}-policy"
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "rotation" {
  for_each = { for k, v in var.secrets : k => v if v.rotation_days > 0 }
  
  role       = aws_iam_role.rotation[each.key].name
  policy_arn = aws_iam_policy.rotation[each.key].arn
}

# Rotation Lambda code
data "archive_file" "rotation" {
  for_each = { for k, v in var.secrets : k => v if v.rotation_days > 0 }
  
  type        = "zip"
  output_path = "/tmp/rotation-${replace(each.key, "/", "-")}.zip"
  
  source {
    content = templatefile("${path.module}/rotation.py", {
      secret_name = each.key
    })
    filename = "index.py"
  }
}

# Rotation schedule
resource "aws_secretsmanager_secret_rotation" "rotation" {
  for_each = { for k, v in var.secrets : k => v if v.rotation_days > 0 }
  
  secret_id           = aws_secretsmanager_secret.secrets[each.key].id
  rotation_lambda_arn = aws_lambda_function.rotation[each.key].arn
  
  rotation_rules {
    automatically_after_days = each.value.rotation_days
  }
}

# Variables
variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    description     = string
    rotation_days   = number
  }))
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

# Outputs
output "secret_arns" {
  description = "Secret ARNs"
  value = {
    for k, v in aws_secretsmanager_secret.secrets : k => v.arn
  }
}

output "secret_names" {
  description = "Secret names"
  value = {
    for k, v in aws_secretsmanager_secret.secrets : k => v.name
  }
}
