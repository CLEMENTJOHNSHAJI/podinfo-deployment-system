# Deployment Instructions

## Prerequisites Setup ✅

1. **GitHub Repository**: https://github.com/CLEMENTJOHNSHAJI/podinfo-deployment-system
2. **AWS Account**: Configured with CLI
3. **Tools Installed**: AWS CLI, Terraform, Docker

## Step 1: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Step 2: Configure GitHub Secrets

Go to: https://github.com/CLEMENTJOHNSHAJI/podinfo-deployment-system/settings/secrets/actions

Add these secrets:
- AWS_ROLE_ARN: (from Terraform output)
- AWS_ACCOUNT_ID: 484826611466
- AWS_REGION: us-west-2

## Step 3: Test Deployment

```bash
git add .
git commit -m "Configure deployment"
git push origin main
```

## Step 4: Monitor Deployment

- GitHub Actions: https://github.com/CLEMENTJOHNSHAJI/podinfo-deployment-system/actions
- AWS Console: https://us-west-2.console.aws.amazon.com/
- CloudWatch Dashboard: (URL from Terraform output)

## Troubleshooting

If deployment fails:
1. Check GitHub Actions logs
2. Verify AWS permissions
3. Check Terraform state
4. Review CloudWatch logs

## Cleanup

To remove all resources:
```bash
cd terraform
terraform destroy
```
