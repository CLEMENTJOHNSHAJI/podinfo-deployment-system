#!/bin/bash

# Teardown script for Podinfo deployment system
# This script safely destroys all AWS resources created by Terraform

set -e

echo "🧹 Starting teardown of Podinfo deployment system..."

# Check if we're in the right directory
if [ ! -f "infra/main.tf" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ Error: AWS CLI not configured. Please run 'aws configure' first"
    exit 1
fi

# Confirm teardown
echo "⚠️  WARNING: This will destroy ALL AWS resources created by this project!"
echo "This includes:"
echo "  - ECR repositories and images"
echo "  - Lambda functions"
echo "  - EC2 instances and Auto Scaling Groups"
echo "  - Application Load Balancer"
echo "  - VPC and networking resources"
echo "  - CloudWatch logs and dashboards"
echo "  - IAM roles and policies"
echo "  - Secrets Manager secrets"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Teardown cancelled"
    exit 1
fi

# Change to infra directory
cd infra

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Plan the destruction
echo "📋 Planning resource destruction..."
terraform plan -destroy

# Apply the destruction
echo "💥 Destroying resources..."
terraform destroy -auto-approve

# Clean up local files
echo "🧹 Cleaning up local files..."
cd ..
rm -f infra/terraform.tfstate*
rm -f infra/.terraform.lock.hcl
rm -rf infra/.terraform/

echo "✅ Teardown completed successfully!"
echo ""
echo "All AWS resources have been destroyed."
echo "You may want to:"
echo "  - Delete the GitHub repository if no longer needed"
echo "  - Remove any remaining ECR repositories manually if they weren't destroyed"
echo "  - Check AWS CloudWatch for any remaining log groups"