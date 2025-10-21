# CloudWatch Log Redaction for Secrets
# This file implements log filtering to prevent secrets from appearing in logs

# Lambda function for log redaction
resource "aws_lambda_function" "log_redaction" {
  filename         = data.archive_file.log_redaction.output_path
  function_name    = "${var.name_prefix}-log-redaction"
  role            = aws_iam_role.log_redaction.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.log_redaction.output_base64sha256
  runtime         = "python3.9"
  timeout         = 60
  
  environment {
    variables = {
      REDACTION_PATTERNS = jsonencode([
        "SUPER_SECRET_TOKEN",
        "DATABASE_URL",
        "API_KEY",
        "password",
        "secret",
        "token"
      ])
    }
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-log-redaction"
  })
}

# Archive for log redaction function
data "archive_file" "log_redaction" {
  type        = "zip"
  output_path = "${path.module}/log_redaction.zip"
  
  source {
    content = <<EOF
import json
import re
import base64
import gzip
import os

# Patterns to redact
REDACTION_PATTERNS = json.loads(os.environ.get('REDACTION_PATTERNS', '[]'))

def lambda_handler(event, context):
    """
    CloudWatch Logs subscription filter handler that redacts sensitive data
    """
    # Decode and decompress the log data
    compressed_data = base64.b64decode(event['awslogs']['data'])
    log_data = json.loads(gzip.decompress(compressed_data))
    
    # Process each log event
    redacted_events = []
    for log_event in log_data['logEvents']:
        message = log_event['message']
        
        # Redact sensitive patterns
        for pattern in REDACTION_PATTERNS:
            # Match pattern and surrounding value
            # E.g., "SUPER_SECRET_TOKEN": "abc123" -> "SUPER_SECRET_TOKEN": "[REDACTED]"
            message = re.sub(
                rf'("{pattern}"\s*:\s*)"[^"]*"',
                r'\1"[REDACTED]"',
                message,
                flags=re.IGNORECASE
            )
            # Match pattern=value
            message = re.sub(
                rf'{pattern}[=:]\s*\S+',
                f'{pattern}=[REDACTED]',
                message,
                flags=re.IGNORECASE
            )
            # Match Bearer tokens
            message = re.sub(
                r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',
                'Bearer [REDACTED]',
                message,
                flags=re.IGNORECASE
            )
        
        redacted_events.append({
            'id': log_event['id'],
            'timestamp': log_event['timestamp'],
            'message': message
        })
    
    # Return redacted log data
    return {
        'messageType': log_data['messageType'],
        'owner': log_data['owner'],
        'logGroup': log_data['logGroup'],
        'logStream': log_data['logStream'],
        'subscriptionFilters': log_data['subscriptionFilters'],
        'logEvents': redacted_events
    }
EOF
    filename = "index.py"
  }
}

# IAM Role for log redaction Lambda
resource "aws_iam_role" "log_redaction" {
  name = "${var.name_prefix}-log-redaction-role"
  
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
    Name = "${var.name_prefix}-log-redaction-role"
  })
}

# IAM Policy for log redaction Lambda
resource "aws_iam_policy" "log_redaction" {
  name        = "${var.name_prefix}-log-redaction-policy"
  description = "Policy for log redaction Lambda"
  
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
          "logs:PutSubscriptionFilter",
          "logs:DescribeSubscriptionFilters",
          "logs:DeleteSubscriptionFilter"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${var.name_prefix}*"
      }
    ]
  })
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-log-redaction-policy"
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "log_redaction" {
  role       = aws_iam_role.log_redaction.name
  policy_arn = aws_iam_policy.log_redaction.arn
}

# Attach basic execution policy
resource "aws_iam_role_policy_attachment" "log_redaction_basic" {
  role       = aws_iam_role.log_redaction.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Log Group for redaction function
resource "aws_cloudwatch_log_group" "log_redaction" {
  name              = "/aws/lambda/${var.name_prefix}-log-redaction"
  retention_in_days = 7
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-log-redaction-logs"
  })
}

# Destination for redacted logs
resource "aws_cloudwatch_log_group" "redacted_logs" {
  name              = "/aws/redacted/${var.name_prefix}"
  retention_in_days = 30
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-redacted-logs"
  })
}

# Lambda permission for CloudWatch Logs
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_redaction.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}*:*"
}

# Note: Subscription filters need to be created for each log group
# This is typically done after the Lambda function is deployed
# Example (manual or via separate Terraform module):
# 
# resource "aws_cloudwatch_log_subscription_filter" "lambda_logs" {
#   name            = "${var.name_prefix}-lambda-redaction"
#   log_group_name  = "/aws/lambda/${var.name_prefix}-lambda"
#   filter_pattern  = ""  # Empty pattern processes all logs
#   destination_arn = aws_lambda_function.log_redaction.arn
#   depends_on      = [aws_lambda_permission.allow_cloudwatch]
# }

# Outputs
output "log_redaction_function_arn" {
  description = "ARN of the log redaction Lambda function"
  value       = aws_lambda_function.log_redaction.arn
}

output "redacted_logs_group" {
  description = "CloudWatch log group for redacted logs"
  value       = aws_cloudwatch_log_group.redacted_logs.name
}

