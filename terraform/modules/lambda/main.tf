# Lambda Infrastructure Module
# Creates API Gateway, Lambda function, and CodeDeploy configuration for Lambda

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Placeholder Lambda function code
data "archive_file" "lambda_placeholder" {
  type        = "zip"
  output_path = "/tmp/lambda_placeholder.zip"
  source {
    content = <<EOF
def handler(event, context):
    return {
        'statusCode': 200,
        'body': '{"message": "Podinfo Lambda placeholder - Docker image not yet built"}'
    }
EOF
    filename = "index.py"
  }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "main" {
  name          = var.api_gateway_name
  protocol_type = "HTTP"
  description   = "API Gateway for ${var.name_prefix} Lambda function"
  
  cors_configuration {
    allow_credentials = false
    allow_headers     = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token"]
    allow_methods     = ["*"]
    allow_origins     = ["*"]
    expose_headers    = ["date", "keep-alive"]
    max_age          = 86400
  }
  
  tags = merge(var.common_tags, {
    Name = var.api_gateway_name
  })
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.api_stage_name
  auto_deploy = true
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      userAgent      = "$context.identity.userAgent"
      correlationId  = "$context.requestId"
    })
  }
  
  default_route_settings {
    throttling_rate_limit  = 1000
    throttling_burst_limit = 2000
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.api_gateway_name}-${var.api_stage_name}"
  })
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.api_gateway_name}"
  retention_in_days = 30
  
  tags = merge(var.common_tags, {
    Name = "${var.api_gateway_name}-logs"
  })
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution" {
  name = "${var.name_prefix}-lambda-execution-role"
  
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
    Name = "${var.name_prefix}-lambda-execution-role"
  })
}

# Lambda Execution Policy
resource "aws_iam_policy" "lambda_execution" {
  name        = "${var.name_prefix}-lambda-execution-policy"
  description = "Policy for Lambda execution"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-lambda-execution-policy"
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_execution.arn
}

# Attach VPC execution policy if VPC is configured
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Security Group
resource "aws_security_group" "lambda" {
  count = var.vpc_config != null ? 1 : 0
  
  name_prefix = "${var.name_prefix}-lambda-"
  vpc_id      = var.vpc_config.vpc_id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-lambda-sg"
  })
}

# Lambda Function - Using placeholder until Docker image is built
resource "aws_lambda_function" "main" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Zip"
  filename      = data.archive_file.lambda_placeholder.output_path
  handler       = "index.handler"
  runtime       = "python3.9"
  
  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory
  
  vpc_config {
    subnet_ids         = var.vpc_config != null ? var.vpc_config.subnet_ids : []
    security_group_ids = var.vpc_config != null ? [aws_security_group.lambda[0].id] : []
  }
  
  environment {
    variables = {
      ENVIRONMENT = var.environment
      LOG_LEVEL   = "INFO"
    }
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_execution,
    aws_cloudwatch_log_group.lambda
  ]
  
  tags = merge(var.common_tags, {
    Name = var.lambda_function_name
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 30
  
  tags = merge(var.common_tags, {
    Name = "${var.lambda_function_name}-logs"
  })
}

# Lambda Alias for Blue/Green deployments
resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Live alias for blue/green deployments"
  function_name    = aws_lambda_function.main.function_name
  function_version = "$LATEST"
  
  lifecycle {
    ignore_changes = [function_version]
  }
}

# Provisioned concurrency (guarded)
resource "aws_lambda_provisioned_concurrency_config" "live" {
  count                          = var.enable_provisioned_concurrency ? 1 : 0
  function_name                  = aws_lambda_function.main.function_name
  qualifier                      = aws_lambda_alias.live.name
  provisioned_concurrent_executions = var.provisioned_concurrency
}

# CodeDeploy Application (guarded)
resource "aws_codedeploy_app" "main" {
  count            = var.enable_codedeploy ? 1 : 0
  compute_platform = "Lambda"
  name             = var.codedeploy_app_name
  
  tags = merge(var.common_tags, {
    Name = var.codedeploy_app_name
  })
}

# CodeDeploy Deployment Group (guarded)
resource "aws_codedeploy_deployment_group" "main" {
  count = var.enable_codedeploy ? 1 : 0
  app_name              = aws_codedeploy_app.main[0].name
  deployment_group_name = var.codedeploy_group_name
  service_role_arn      = aws_iam_role.codedeploy[0].arn
  
  deployment_config_name = "CodeDeployDefault.LambdaAllAtOnce"
  
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  
  alarm_configuration {
    alarms  = [aws_cloudwatch_metric_alarm.lambda_errors.alarm_name]
    enabled = true
  }
  
  tags = merge(var.common_tags, {
    Name = var.codedeploy_group_name
  })
}

# CodeDeploy IAM Role (guarded)
resource "aws_iam_role" "codedeploy" {
  count = var.enable_codedeploy ? 1 : 0
  name  = "${var.name_prefix}-codedeploy-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-codedeploy-role"
  })
}

# CodeDeploy IAM Policy (guarded)
resource "aws_iam_policy" "codedeploy" {
  count       = var.enable_codedeploy ? 1 : 0
  name        = "${var.name_prefix}-codedeploy-policy"
  description = "Policy for CodeDeploy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:GetAlias",
          "lambda:ListAliases",
          "lambda:ListVersionsByFunction",
          "lambda:UpdateAlias",
          "lambda:CreateAlias",
          "lambda:DeleteAlias"
        ]
        Resource = [
          aws_lambda_function.main.arn,
          "${aws_lambda_function.main.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      }
    ]
  })
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-codedeploy-policy"
  })
}

# Attach policy to role (guarded)
resource "aws_iam_role_policy_attachment" "codedeploy" {
  count      = var.enable_codedeploy ? 1 : 0
  role       = aws_iam_role.codedeploy[0].name
  policy_arn = aws_iam_policy.codedeploy[0].arn
}

# CloudWatch Alarm for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors"
  
  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }
  
  alarm_actions = [var.sns_topic_arn]
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-lambda-errors"
  })
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  
  integration_method = "POST"
  integration_uri    = aws_lambda_function.main.invoke_arn
  payload_format_version = "2.0"
}

# API Gateway Route
resource "aws_apigatewayv2_route" "lambda" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
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

variable "api_gateway_name" {
  description = "API Gateway name"
  type        = string
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory" {
  description = "Lambda memory in MB"
  type        = number
  default     = 512
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "enable_codedeploy" {
  description = "Enable CodeDeploy resources in this module"
  type        = bool
  default     = false
}

variable "codedeploy_app_name" {
  description = "CodeDeploy application name"
  type        = string
}

variable "codedeploy_group_name" {
  description = "CodeDeploy deployment group name"
  type        = string
}

variable "vpc_config" {
  description = "VPC configuration for Lambda"
  type = object({
    vpc_id     = string
    subnet_ids = list(string)
  })
  default = null
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
}

variable "enable_provisioned_concurrency" {
  description = "Enable provisioned concurrency for the Lambda alias"
  type        = bool
  default     = false
}

variable "provisioned_concurrency" {
  description = "Number of provisioned concurrent executions for the alias"
  type        = number
  default     = 100
}

# Outputs
output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.main.function_name
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.main.arn
}

output "function_url" {
  description = "API Gateway URL"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

output "lambda_security_group_id" {
  description = "Lambda security group ID"
  value       = var.vpc_config != null ? aws_security_group.lambda[0].id : null
}

# CodeDeploy outputs - Temporarily disabled
output "codedeploy_app_name" {
  description = "CodeDeploy application name"
  value       = var.enable_codedeploy ? aws_codedeploy_app.main[0].name : null
}

output "codedeploy_group_name" {
  description = "CodeDeploy deployment group name"
  value       = var.enable_codedeploy ? aws_codedeploy_deployment_group.main[0].deployment_group_name : null
}
