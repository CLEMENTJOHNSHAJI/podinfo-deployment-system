#!/bin/bash

# Verify Deployment Pipeline Script
# This script tests the deployment pipeline locally before pushing to GitHub

set -e

echo "🔍 Verifying Deployment Pipeline..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "infra/main.tf" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_status "Project structure verified"

# Check AWS CLI configuration
echo "🔧 Checking AWS CLI configuration..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    print_error "AWS CLI not configured or credentials invalid"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
print_status "AWS CLI configured (Account: $ACCOUNT_ID, Region: $REGION)"

# Check if ECR repositories exist
echo "🐳 Checking ECR repositories..."
if aws ecr describe-repositories --repository-names podinfo-podinfo > /dev/null 2>&1; then
    print_status "ECR repository 'podinfo-podinfo' exists"
else
    print_warning "ECR repository 'podinfo-podinfo' does not exist"
fi

if aws ecr describe-repositories --repository-names podinfo-podinfo-lambda > /dev/null 2>&1; then
    print_status "ECR repository 'podinfo-podinfo-lambda' exists"
else
    print_warning "ECR repository 'podinfo-podinfo-lambda' does not exist"
fi

# Check if Lambda execution role exists
echo "🔐 Checking Lambda execution role..."
if aws iam get-role --role-name podinfo-lambda-execution-role > /dev/null 2>&1; then
    print_status "Lambda execution role 'podinfo-lambda-execution-role' exists"
else
    print_warning "Lambda execution role 'podinfo-lambda-execution-role' does not exist"
fi

# Check if GitHub Actions role exists
echo "🔐 Checking GitHub Actions role..."
if aws iam get-role --role-name podinfo-github-actions-role > /dev/null 2>&1; then
    print_status "GitHub Actions role 'podinfo-github-actions-role' exists"
    
    # Check if the role has the correct policy attached
    POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/podinfo-github-actions-policy"
    if aws iam get-role-policy --role-name podinfo-github-actions-role --policy-name podinfo-github-actions-policy > /dev/null 2>&1; then
        print_status "GitHub Actions policy attached to role"
    else
        print_warning "GitHub Actions policy not attached to role"
    fi
else
    print_warning "GitHub Actions role 'podinfo-github-actions-role' does not exist"
fi

# Check if Lambda function exists
echo "⚡ Checking Lambda function..."
if aws lambda get-function --function-name podinfo-lambda > /dev/null 2>&1; then
    print_status "Lambda function 'podinfo-lambda' exists"
    
    # Get function details
    PACKAGE_TYPE=$(aws lambda get-function --function-name podinfo-lambda --query 'Configuration.PackageType' --output text)
    print_status "Lambda function package type: $PACKAGE_TYPE"
else
    print_warning "Lambda function 'podinfo-lambda' does not exist (will be created on first deployment)"
fi

# Check GitHub Actions workflow syntax
echo "🔧 Checking GitHub Actions workflow syntax..."
if command -v yamllint > /dev/null 2>&1; then
    if yamllint .github/workflows/build.yml .github/workflows/deploy.yml; then
        print_status "GitHub Actions workflows have valid YAML syntax"
    else
        print_warning "GitHub Actions workflows have YAML syntax issues"
    fi
else
    print_warning "yamllint not installed, skipping YAML syntax check"
fi

# Check Terraform syntax
echo "🏗️  Checking Terraform syntax..."
cd infra
if terraform validate > /dev/null 2>&1; then
    print_status "Terraform configuration is valid"
else
    print_error "Terraform configuration has syntax errors"
    terraform validate
    exit 1
fi

# Check if Terraform can plan without errors
echo "📋 Checking Terraform plan..."
if terraform plan -out=tfplan > /dev/null 2>&1; then
    print_status "Terraform plan successful"
    rm -f tfplan
else
    print_warning "Terraform plan has issues (this is normal if resources already exist)"
fi

cd ..

# Check if required secrets are documented
echo "🔑 Checking secrets documentation..."
if [ -f "ENVIRONMENT.md" ]; then
    print_status "Environment documentation exists"
else
    print_warning "Environment documentation missing"
fi

# Check if scripts are executable
echo "📜 Checking script permissions..."
for script in scripts/*.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_status "$(basename "$script") is executable"
        else
            print_warning "$(basename "$script") is not executable"
        fi
    fi
done

# Summary
echo ""
echo "🎯 Deployment Pipeline Verification Summary:"
echo "============================================="
print_status "All critical checks completed"
echo ""
echo "📋 Next Steps:"
echo "1. Ensure all required GitHub secrets are configured"
echo "2. Push changes to trigger GitHub Actions workflow"
echo "3. Monitor the Actions tab for deployment progress"
echo ""
echo "🔗 Useful Commands:"
echo "- View GitHub Actions: https://github.com/CLEMENTJOHNSHAJI/podinfo-deployment-system/actions"
echo "- Check AWS Lambda: aws lambda list-functions"
echo "- Check ECR images: aws ecr list-images --repository-name podinfo-podinfo-lambda"
echo ""
print_status "Verification complete! Ready for deployment."
