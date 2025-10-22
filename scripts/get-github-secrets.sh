#!/bin/bash
# Helper script to get values for GitHub Secrets

set -e

AWS_REGION=${AWS_REGION:-us-west-2}

echo "========================================="
echo "GitHub Secrets Configuration Helper"
echo "========================================="
echo ""

echo "Getting AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID"
echo ""

echo "Getting latest Amazon Linux 2023 AMI..."
EC2_AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*x86_64" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region $AWS_REGION)
echo "✅ EC2_AMI_ID=$EC2_AMI_ID"
echo ""

echo "Getting Security Group ID..."
EC2_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=podinfo-*" \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --region $AWS_REGION 2>/dev/null || echo "")

if [ -z "$EC2_SECURITY_GROUP_ID" ] || [ "$EC2_SECURITY_GROUP_ID" == "None" ]; then
  echo "⚠️  EC2_SECURITY_GROUP_ID not found via filter"
  echo "   Getting from Terraform output..."
  cd infra
  EC2_SECURITY_GROUP_ID=$(terraform output -raw ec2_security_group_id 2>/dev/null || echo "")
  cd ..
fi

if [ -n "$EC2_SECURITY_GROUP_ID" ] && [ "$EC2_SECURITY_GROUP_ID" != "None" ]; then
  echo "✅ EC2_SECURITY_GROUP_ID=$EC2_SECURITY_GROUP_ID"
else
  echo "❌ EC2_SECURITY_GROUP_ID not found"
  echo "   Please check AWS Console or Terraform state"
fi
echo ""

echo "Getting ECR Repository URLs..."
ECR_REPOSITORY_LAMBDA="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/podinfo-podinfo-lambda"
ECR_REPOSITORY_EC2="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/podinfo-podinfo"
echo "✅ ECR_REPOSITORY_LAMBDA=$ECR_REPOSITORY_LAMBDA"
echo "✅ ECR_REPOSITORY_EC2=$ECR_REPOSITORY_EC2"
echo ""

echo "Getting IAM Role ARN..."
AWS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/podinfo-github-actions-role"
echo "✅ AWS_ROLE_ARN=$AWS_ROLE_ARN"
echo ""

echo "========================================="
echo "COPY THESE TO GITHUB SECRETS"
echo "========================================="
echo ""
echo "Go to: https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions"
echo ""
echo "Required Secrets:"
echo "-----------------"
echo "AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID"
echo "AWS_REGION=$AWS_REGION"
echo "AWS_ROLE_ARN=$AWS_ROLE_ARN"
echo "ECR_REPOSITORY_LAMBDA=$ECR_REPOSITORY_LAMBDA"
echo "ECR_REPOSITORY_EC2=$ECR_REPOSITORY_EC2"
echo "EC2_AMI_ID=$EC2_AMI_ID"

if [ -n "$EC2_SECURITY_GROUP_ID" ] && [ "$EC2_SECURITY_GROUP_ID" != "None" ]; then
  echo "EC2_SECURITY_GROUP_ID=$EC2_SECURITY_GROUP_ID"
else
  echo "EC2_SECURITY_GROUP_ID=<GET_FROM_TERRAFORM_OUTPUT>"
fi

echo "ENABLE_CODEDEPLOY=true"
echo ""
echo "========================================="
echo "QUICK COPY FORMAT (for terminal)"
echo "========================================="
echo ""
cat << EOF
# Copy and paste these into GitHub Secrets (one at a time):
AWS_ACCOUNT_ID
$AWS_ACCOUNT_ID

AWS_REGION
$AWS_REGION

AWS_ROLE_ARN
$AWS_ROLE_ARN

ECR_REPOSITORY_LAMBDA
$ECR_REPOSITORY_LAMBDA

ECR_REPOSITORY_EC2
$ECR_REPOSITORY_EC2

EC2_AMI_ID
$EC2_AMI_ID

EC2_SECURITY_GROUP_ID
${EC2_SECURITY_GROUP_ID:-<GET_FROM_TERRAFORM_OUTPUT>}

ENABLE_CODEDEPLOY
true
EOF

echo ""
echo "✅ Done!"

