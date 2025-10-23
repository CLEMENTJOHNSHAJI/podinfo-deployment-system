#!/bin/bash

echo "Podinfo Deployment System Setup"
echo "=================================="
echo ""

# Get user input
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -p "Enter your AWS Account ID (12 digits): " AWS_ACCOUNT_ID
read -p "Enter your AWS region (default: us-west-2): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-west-2}

echo ""
echo "Configuration Summary:"
echo "GitHub Username: $GITHUB_USERNAME"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo ""

cat > infra/terraform.tfvars << EOF
environment = "dev"
github_org = "$GITHUB_USERNAME"
github_repo = "podinfo-deployment-system"
github_branch = "main"
aws_region = "$AWS_REGION"
aws_account_id = "$AWS_ACCOUNT_ID"
EOF

echo "Created infra/terraform.tfvars"
echo ""

cat > github-secrets-template.txt << EOF
AWS_ROLE_ARN = "arn:aws:iam::${AWS_ACCOUNT_ID}:role/podinfo-github-actions-role"
AWS_ACCOUNT_ID = "${AWS_ACCOUNT_ID}"
AWS_REGION = "${AWS_REGION}"
EOF

echo "Created github-secrets-template.txt"
echo ""

cat > DEPLOYMENT_INSTRUCTIONS.md << EOF
# Deployment Instructions

## Prerequisites Setup

1. **GitHub Repository**: https://github.com/$GITHUB_USERNAME/podinfo-deployment-system
2. **AWS Account**: Configured with CLI
3. **Tools Installed**: AWS CLI, Terraform, Docker

## Step 1: Deploy Infrastructure

\`\`\`bash
cd terraform
terraform init
terraform plan
terraform apply
\`\`\`

## Step 2: Configure GitHub Secrets

Go to: https://github.com/$GITHUB_USERNAME/podinfo-deployment-system/settings/secrets/actions

Add these secrets:
- AWS_ROLE_ARN: (from Terraform output)
- AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID
- AWS_REGION: $AWS_REGION

## Step 3: Test Deployment

\`\`\`bash
git add .
git commit -m "Configure deployment"
git push origin main
\`\`\`

## Step 4: Monitor Deployment

- GitHub Actions: https://github.com/$GITHUB_USERNAME/podinfo-deployment-system/actions
- AWS Console: https://$AWS_REGION.console.aws.amazon.com/
- CloudWatch Dashboard: (URL from Terraform output)

## Troubleshooting

If deployment fails:
1. Check GitHub Actions logs
2. Verify AWS permissions
3. Check Terraform state
4. Review CloudWatch logs

## Cleanup

To remove all resources:
\`\`\`bash
cd terraform
terraform destroy
\`\`\`
EOF

echo "Created DEPLOYMENT_INSTRUCTIONS.md"
echo ""

echo "Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Review the generated files"
echo "2. Follow DEPLOYMENT_INSTRUCTIONS.md"
echo "3. Deploy your infrastructure with Terraform"
echo "4. Configure GitHub secrets"
echo "5. Push to GitHub to trigger deployment"

