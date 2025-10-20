# Podinfo Multi-Target Deployment System

A production-ready, secure deployment system for the Podinfo application across multiple AWS targets (Lambda and EC2) with blue/green deployments, image signing, and comprehensive monitoring.

## 🏗️ Architecture

This system deploys Podinfo to:
- **AWS Lambda** (API Gateway fronted) - Serverless compute
- **AWS EC2** (ALB fronted) - Traditional compute with Auto Scaling

Both targets support:
- Blue/green deployments via CodeDeploy
- Container image signing and verification
- Comprehensive monitoring and alerting
- Secrets management with rotation
- Supply chain security (SBOM, vulnerability scanning)

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- GitHub repository with OIDC configured
- Docker (optional - builds run in GitHub Actions)

### Bootstrap

1. **Clone and configure**:
   ```bash
   git clone <your-repo-url>
   cd podinfo-deployment-system
   ./scripts/bootstrap.sh
   ```

2. **Set GitHub secrets** (see `ENVIRONMENT.md` for complete list):
   ```bash
   # Required secrets
   AWS_ROLE_ARN=arn:aws:iam::ACCOUNT:role/podinfo-github-actions-role
   AWS_REGION=us-west-2
   AWS_ACCOUNT_ID=123456789012
   ECR_REPOSITORY_LAMBDA=ACCOUNT.dkr.ecr.REGION.amazonaws.com/podinfo-podinfo-lambda
   ECR_REPOSITORY_EC2=ACCOUNT.dkr.ecr.REGION.amazonaws.com/podinfo-podinfo
   REPO_OWNER=your-github-username
   REPO_NAME=podinfo-deployment-system
   
   # Optional features
   ENABLE_CODEDEPLOY=true
   ENABLE_SECRETS_ROTATION=false
   ```

3. **Deploy infrastructure**:
   ```bash
   cd infra
   terraform init
   terraform plan
   terraform apply
   ```

## 🏃 Run

### Development Deployment

Push to `develop` or `main` branch to trigger automatic deployment:

```bash
git add .
git commit -m "feat: new feature"
git push origin main
```

The system will:
1. Build and sign container images
2. Generate SBOM and security scans
3. Deploy to both Lambda and EC2 targets
4. Run smoke tests and validation

### Manual Deployment

```bash
# Deploy infrastructure only
cd infra
terraform apply

# Run smoke tests
./scripts/smoke-tests.sh dev
```

## 🔄 Promote

### Development → Production

1. **Merge to main branch**:
   ```bash
   git checkout main
   git merge develop
   git push origin main
   ```

2. **Production deployment** requires:
   - Human approval (GitHub environment protection)
   - Image signature verification
   - Comprehensive testing

3. **Monitor promotion**:
   - Check GitHub Actions for deployment status
   - Review CloudWatch dashboards
   - Validate both Lambda and EC2 endpoints

### Rollback

```bash
# Rollback to previous version
git revert <commit-hash>
git push origin main

# Or use CodeDeploy rollback (if enabled)
aws codedeploy stop-deployment --deployment-id <deployment-id>
```

## 🧹 Destroy

### Safe Teardown

```bash
./scripts/teardown.sh
```

This will:
- Destroy all AWS resources
- Clean up local Terraform state
- Preserve ECR images (manual cleanup required)

### Manual Cleanup

```bash
cd infra
terraform destroy
```

## 📊 Monitoring

- **CloudWatch Dashboard**: `https://console.aws.amazon.com/cloudwatch/home#dashboards:name=podinfo-dashboard`
- **Lambda URL**: Available in Terraform outputs
- **ALB URL**: Available in Terraform outputs

## 🔧 Configuration

See `ENVIRONMENT.md` for:
- Environment variables
- Secret names and ARNs
- Version requirements
- Region configuration

## 📁 Repository Structure

```
.github/workflows/     # CI/CD pipelines
├── build.yml          # Build, sign, SBOM generation
└── deploy.yml         # Dual target deployment, promotion

infra/                 # Terraform infrastructure
├── global/            # ECR, IAM OIDC, alarms, SNS, dashboards
├── lambda/            # Lambda-specific resources
├── ec2/               # EC2-specific resources
└── main.tf            # Root module

scripts/               # Deployment and utility scripts
├── bootstrap.sh       # Initial setup
├── smoke-tests.sh     # Health checks and validation
├── teardown.sh        # Safe resource cleanup
└── ec2-deployment-hooks.sh  # CodeDeploy hooks

docs/                  # Documentation
└── diagram.svg        # Architecture diagram

app/                   # Application source code
└── Dockerfile         # Container definition
```

## 🛡️ Security Features

- **Image Signing**: Cosign with keyless signing
- **SBOM Generation**: Software Bill of Materials
- **Vulnerability Scanning**: Trivy security scans
- **Secrets Management**: AWS Secrets Manager with rotation
- **Network Security**: VPC, security groups, ALB
- **Access Control**: IAM roles with least privilege

## 🚨 Troubleshooting

### Common Issues

1. **Deployment fails**: Check CloudWatch logs and GitHub Actions
2. **Health checks fail**: Verify security groups and ALB configuration
3. **Image pull errors**: Check ECR permissions and image existence
4. **CodeDeploy issues**: Verify service-linked roles and permissions

### Debug Commands

```bash
# Check Lambda function
aws lambda get-function --function-name podinfo-lambda

# Check ALB health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# View CloudWatch logs
aws logs tail /aws/lambda/podinfo-lambda --follow
```

## 📈 Scaling

The system supports:
- **Lambda**: Provisioned concurrency (configurable)
- **EC2**: Auto Scaling Groups with custom policies
- **ALB**: Load balancing across multiple AZs
- **Monitoring**: CloudWatch alarms and dashboards

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.