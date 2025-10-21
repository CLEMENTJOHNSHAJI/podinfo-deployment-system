# Environment Configuration

This document describes the environment variables, configuration values, and secret names required for the Podinfo deployment system.

## Prerequisites

### Required Tools
- **Terraform**: >= 1.0
- **AWS CLI**: >= 2.0
- **Docker**: >= 20.0 (optional - builds run in GitHub Actions)
- **Git**: >= 2.0

### AWS Account Requirements
- AWS Account with billing enabled
- IAM permissions for resource creation
- ECR, Lambda, EC2, VPC, CloudWatch, CodeDeploy access

## Environment Variables

### Core Configuration
```bash
# AWS Configuration
AWS_REGION=us-west-2
AWS_ACCOUNT_ID=123456789012

# GitHub Configuration
REPO_OWNER=your-github-username
REPO_NAME=podinfo-deployment-system
GITHUB_BRANCH=main

# Application Configuration
ENVIRONMENT=dev
APP_NAME=podinfo
```

### Optional Features
```bash
# CodeDeploy (blue/green deployments)
ENABLE_CODEDEPLOY=true

# Secrets rotation
ENABLE_SECRETS_ROTATION=false

# Lambda provisioned concurrency
ENABLE_PROVISIONED_CONCURRENCY=false
PROVISIONED_CONCURRENCY=1
```

## GitHub Secrets

### Required Secrets
Set these in your GitHub repository settings under "Secrets and variables" → "Actions":

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ROLE_ARN` | IAM role for GitHub Actions | `arn:aws:iam::123456789012:role/podinfo-github-actions-role` |
| `AWS_REGION` | AWS region for deployment | `us-west-2` |
| `AWS_ACCOUNT_ID` | AWS account ID | `123456789012` |
| `ECR_REPOSITORY_LAMBDA` | ECR repository for Lambda images | `123456789012.dkr.ecr.us-west-2.amazonaws.com/podinfo-podinfo-lambda` |
| `ECR_REPOSITORY_EC2` | ECR repository for EC2 images | `123456789012.dkr.ecr.us-west-2.amazonaws.com/podinfo-podinfo` |
| `REPO_OWNER` | GitHub repository owner | `your-github-username` |
| `REPO_NAME` | GitHub repository name | `podinfo-deployment-system` |

### Optional Secrets
| Secret Name | Description | Default Value |
|-------------|-------------|---------------|
| `ENABLE_CODEDEPLOY` | Enable CodeDeploy for blue/green deployments | `false` |
| `ENABLE_SECRETS_ROTATION` | Enable automatic secrets rotation | `false` |
| `ENABLE_PROVISIONED_CONCURRENCY` | Enable Lambda provisioned concurrency | `false` |
| `PROVISIONED_CONCURRENCY` | Number of provisioned concurrency units | `1` |

## 🏗️ Infrastructure Configuration

### Terraform Variables
Located in `infra/terraform.tfvars`:

```hcl
# Basic Configuration
aws_region     = "us-west-2"
aws_account_id = "123456789012"
environment   = "dev"

# GitHub Configuration
github_org    = "your-github-username"
github_repo   = "podinfo-deployment-system"
github_branch = "main"

# EC2 Configuration
instance_type      = "t3.micro"
asg_min_size      = 1
asg_max_size      = 3
asg_desired_capacity = 1

# Lambda Configuration
lambda_timeout = 30
lambda_memory  = 512

# Feature Toggles
enable_codedeploy           = true
enable_secrets_rotation     = false
enable_provisioned_concurrency = false
provisioned_concurrency     = 1
```

## 🔑 AWS Secrets Manager

### Secret Names
The system creates the following secrets in AWS Secrets Manager:

| Secret Name | Description | Rotation |
|-------------|-------------|----------|
| `podinfo/api-keys` | API keys for external services | Configurable |
| `podinfo/database` | Database connection credentials | Configurable |

### Secret ARNs
Generated ARNs follow the pattern:
```
arn:aws:secretsmanager:REGION:ACCOUNT:secret:podinfo/SECRET-NAME-RANDOM
```

Example:
```
arn:aws:secretsmanager:us-west-2:123456789012:secret:podinfo/api-keys-hePXHT
```

## 🌐 Network Configuration

### VPC Settings
- **CIDR Block**: `10.0.0.0/16`
- **Availability Zones**: 2 (us-west-2a, us-west-2b)
- **Public Subnets**: `10.0.1.0/24`, `10.0.2.0/24`
- **Private Subnets**: `10.0.10.0/24`, `10.0.20.0/24`

### Security Groups
- **ALB**: Port 80 (HTTP), Port 443 (HTTPS)
- **EC2**: Port 8080 (Application)
- **Lambda**: VPC access to private subnets

## Monitoring Configuration

### CloudWatch Log Groups
- `/aws/lambda/podinfo-lambda`
- `/aws/apigateway/podinfo-api`
- `/aws/applicationloadbalancer/podinfo-alb`
- `/aws/ec2/podinfo-ec2`

### CloudWatch Alarms
- Lambda errors > 5% in 5 minutes
- EC2 CPU utilization > 80% in 5 minutes
- ALB target health < 100%
- Application health check failures

### Dashboard
- **Name**: `podinfo-dashboard`
- **URL**: `https://console.aws.amazon.com/cloudwatch/home#dashboards:name=podinfo-dashboard`

## 🐳 Container Configuration

### Base Images
- **Build**: `public.ecr.aws/docker/library/golang:1.21-alpine`
- **Runtime**: `public.ecr.aws/docker/library/alpine:3.18`

### Image Tags
- **Latest**: `latest`
- **Versioned**: Git commit SHA
- **Digest**: SHA256 hash for immutable references

## Security Configuration

### IAM Roles
- **GitHub Actions**: `podinfo-github-actions-role`
- **Lambda Execution**: `podinfo-lambda-execution-role`
- **EC2 Instance**: `podinfo-ec2-role`
- **CodeDeploy**: `podinfo-codedeploy-role`

### KMS Key
- **Alias**: `alias/podinfo-key`
- **Rotation**: Enabled (if configured)
- **Usage**: ECR encryption, CloudWatch log encryption

## Deployment Configuration

### CodeDeploy Applications
- **Lambda**: `podinfo-lambda-deploy`
- **EC2**: `podinfo-ec2-deploy`

### Deployment Groups
- **Lambda**: `podinfo-lambda-group`
- **EC2**: `podinfo-ec2-group`

### Deployment Configurations
- **Lambda**: `CodeDeployDefault.LambdaCanary10Percent5Minutes`
- **EC2**: `CodeDeployDefault.AllAtOnce`

## Scaling Configuration

### Auto Scaling Group
- **Min Size**: 1
- **Max Size**: 3
- **Desired Capacity**: 1
- **Instance Type**: t3.micro (Free Tier eligible)

### Lambda Scaling
- **Memory**: 512 MB
- **Timeout**: 30 seconds
- **Concurrency**: Unlimited (or provisioned if enabled)

## Environment-Specific Settings

### Development
- Single EC2 instance
- Basic monitoring
- CodeDeploy optional

### Production
- Multiple EC2 instances
- Enhanced monitoring
- CodeDeploy required
- Human approval gates

## Notes

- All ARNs and resource names are generated by Terraform
- Secret values are auto-generated and stored securely
- ECR repositories are created automatically
- CloudWatch dashboards are updated automatically
- All resources are tagged for cost tracking and management