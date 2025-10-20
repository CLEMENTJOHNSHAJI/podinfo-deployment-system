# Secrets Manager module for Podinfo application
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Create the main application secret
resource "aws_secretsmanager_secret" "app_secret" {
  name                    = "${var.name_prefix}-app-secret"
  description             = "Application secret for Podinfo"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.name_prefix}-app-secret"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PodinfoDeployment"
  }
}

# Set the initial secret value
resource "aws_secretsmanager_secret_version" "app_secret" {
  secret_id = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode({
    SUPER_SECRET_TOKEN = var.initial_secret_value
    DATABASE_URL       = "postgresql://user:pass@localhost:5432/podinfo"
    API_KEY           = "dev-api-key-12345"
  })
}

# Create rotation function
resource "aws_lambda_function" "rotation" {
  count = var.enable_rotation ? 1 : 0
  
  filename         = data.archive_file.rotation[0].output_path
  function_name    = "${var.name_prefix}-secret-rotation"
  role            = aws_iam_role.rotation[0].arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.rotation[0].output_base64sha256
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.app_secret.arn
    }
  }

  tags = {
    Name        = "${var.name_prefix}-secret-rotation"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PodinfoDeployment"
  }
}

# Create rotation function code
data "archive_file" "rotation" {
  count = var.enable_rotation ? 1 : 0
  
  type        = "zip"
  output_path = "${path.module}/rotation.zip"
  
  source {
    content = <<EOF
import json
import boto3
import random
import string

def lambda_handler(event, context):
    """
    Rotate the application secret
    """
    secret_arn = event['SecretId']
    
    # Create a new secret value
    new_token = ''.join(random.choices(string.ascii_letters + string.digits, k=32))
    
    # Update the secret
    secrets_client = boto3.client('secretsmanager')
    
    try:
        # Get current secret
        current_secret = secrets_client.get_secret_value(SecretId=secret_arn)
        current_value = json.loads(current_secret['SecretString'])
        
        # Update with new token
        current_value['SUPER_SECRET_TOKEN'] = new_token
        
        # Update the secret
        secrets_client.update_secret(
            SecretId=secret_arn,
            SecretString=json.dumps(current_value)
        )
        
        print(f"Successfully rotated secret {secret_arn}")
        return {"statusCode": 200, "body": "Secret rotated successfully"}
        
    except Exception as e:
        print(f"Error rotating secret: {str(e)}")
        raise e
EOF
    filename = "index.py"
  }
}

# IAM role for rotation function
resource "aws_iam_role" "rotation" {
  count = var.enable_rotation ? 1 : 0
  
  name = "${var.name_prefix}-secret-rotation-role"

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

  tags = {
    Name        = "${var.name_prefix}-secret-rotation-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PodinfoDeployment"
  }
}

# IAM policy for rotation function
resource "aws_iam_policy" "rotation" {
  count = var.enable_rotation ? 1 : 0
  
  name = "${var.name_prefix}-secret-rotation-policy"

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
          "secretsmanager:UpdateSecret"
        ]
        Resource = aws_secretsmanager_secret.app_secret.arn
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-secret-rotation-policy"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PodinfoDeployment"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "rotation" {
  count = var.enable_rotation ? 1 : 0
  
  role       = aws_iam_role.rotation[0].name
  policy_arn = aws_iam_policy.rotation[0].arn
}

# Attach basic execution role
resource "aws_iam_role_policy_attachment" "rotation_basic" {
  count = var.enable_rotation ? 1 : 0
  
  role       = aws_iam_role.rotation[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Grant Secrets Manager permission to invoke the Lambda function
resource "aws_lambda_permission" "secrets_manager" {
  count = var.enable_rotation ? 1 : 0
  
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation[0].function_name
  principal     = "secretsmanager.amazonaws.com"
}

# Enable rotation
resource "aws_secretsmanager_secret_rotation" "app_secret" {
  count = var.enable_rotation ? 1 : 0
  
  secret_id           = aws_secretsmanager_secret.app_secret.id
  rotation_lambda_arn = aws_lambda_function.rotation[0].arn

  rotation_rules {
    automatically_after_days = 7
  }
}

# CloudWatch log group for rotation function
resource "aws_cloudwatch_log_group" "rotation" {
  count = var.enable_rotation ? 1 : 0
  
  name              = "/aws/lambda/${var.name_prefix}-secret-rotation"
  retention_in_days = 7

  tags = {
    Name        = "${var.name_prefix}-secret-rotation-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PodinfoDeployment"
  }
}
