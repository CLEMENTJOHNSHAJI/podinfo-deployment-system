# Podinfo Multi-Target Deployment System

A comprehensive, secure deployment system that builds, signs, and ships the Podinfo container from GitHub Actions (OIDC) into AWS, then rolls it out in parallel to Lambda (container image behind API Gateway) and to a dual-host EC2/ALB stack.

## 🏗️ Architecture Overview

- **Build & Sign**: GitHub Actions with OIDC authentication
- **Container Registry**: AWS ECR with image signing and SBOM generation
- **Deployment Targets**: 
  - Lambda (API Gateway fronted)
  - EC2 instances behind ALB
- **Deployment Strategy**: Blue/Green with canary releases and automatic rollback
- **Secrets Management**: AWS Secrets Manager with rotation
- **Observability**: CloudWatch dashboards, alarms, and logging
- **Promotion**: Dev → Prod with immutable tags

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- GitHub repository with Actions enabled
- Docker (for local development)

### 1. Clone and Setup
```bash
git clone <repository-url>
cd podinfo-deployment-system
```

### 2. Configure AWS
```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity
```

### 3. Deploy Infrastructure
```bash
# Navigate to Terraform directory
cd terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="github_org=your-org" -var="github_repo=your-repo"

# Deploy infrastructure
terraform apply -var="github_org=your-org" -var="github_repo=your-repo"
```

### 4. Configure GitHub OIDC
1. Go to your GitHub repository settings
2. Navigate to "Secrets and variables" → "Actions"
3. Add the following secrets:
   - `AWS_ROLE_ARN`: The ARN from Terraform output
   - `AWS_ACCOUNT_ID`: Your AWS account ID

### 5. Deploy Application
```bash
# Push to trigger deployment
git push origin main
```

## 📁 Directory Structure

```
├── terraform/                 # Infrastructure as Code
│   ├── modules/              # Reusable Terraform modules
│   │   ├── global/          # Global infrastructure
│   │   ├── lambda/          # Lambda infrastructure
│   │   ├── ec2/             # EC2 infrastructure
│   │   ├── secrets/         # Secrets management
│   │   └── observability/   # Monitoring and logging
│   └── main.tf              # Root module
├── .github/workflows/        # GitHub Actions workflows
│   └── build.yml            # CI/CD pipeline
├── app/                     # Podinfo application
│   ├── main.go              # Go application
│   ├── go.mod               # Go dependencies
│   └── Dockerfile           # Container image
├── docs/                    # Documentation
│   ├── architecture.svg     # Architecture diagram
│   └── scalability-design.md # Scalability documentation
├── scripts/                 # Utility scripts
│   ├── synthetic-tests.sh   # Test script
│   └── teardown.sh          # Cleanup script
├── README.md                # This file
└── ENVIRONMENT.md           # Environment configuration
```

## ✨ Features

### Security & Compliance
- ✅ OIDC-based authentication (no static keys)
- ✅ Container image signing with cosign
- ✅ SBOM generation with syft
- ✅ Security scanning with Trivy
- ✅ Secrets rotation with AWS Secrets Manager
- ✅ Network isolation and least privilege access

### Deployment & Operations
- ✅ Multi-target deployment (Lambda + EC2)
- ✅ Blue/Green deployments with canary releases
- ✅ Automatic rollback on health check failures
- ✅ Immutable artifact promotion (dev → prod)
- ✅ Comprehensive observability and monitoring
- ✅ Cost optimization and scaling

### Development Experience
- ✅ GitOps workflow with GitHub Actions
- ✅ Infrastructure as Code with Terraform
- ✅ Automated testing and validation
- ✅ Comprehensive documentation
- ✅ Easy teardown and cleanup

## 🔧 Configuration

### Environment Variables
- `PORT`: Application port (default: 8080)
- `ENVIRONMENT`: Environment name (dev/prod)
- `LOG_LEVEL`: Logging level (info/debug)
- `VERSION`: Application version

### AWS Resources
- **ECR Repositories**: `podinfo`, `podinfo-lambda`
- **Lambda Function**: `podinfo-lambda`
- **API Gateway**: `podinfo-api`
- **ALB**: `podinfo-alb`
- **Auto Scaling Group**: `podinfo-asg`
- **Secrets**: `podinfo/database`, `podinfo/api-keys`

## 📊 Monitoring & Observability

### CloudWatch Dashboards
- **URL**: Available in Terraform output
- **Metrics**: Lambda, EC2, ALB, and application metrics
- **Alarms**: Automated rollback triggers

### Health Checks
- **Lambda**: `/healthz`, `/readyz`
- **EC2**: `/healthz`, `/readyz`
- **Endpoints**: `/metrics`, `/version`, `/info`

### Logging
- **Lambda Logs**: `/aws/lambda/podinfo-lambda`
- **EC2 Logs**: `/aws/podinfo-ec2`
- **ALB Logs**: `/aws/podinfo-alb`

## 🚀 Deployment Process

### 1. Build Stage
- Build and sign container images
- Generate SBOM with syft
- Push to ECR with security scanning
- Verify image signatures

### 2. Deploy Stage (Dev)
- Deploy to Lambda with canary (10% → 100%)
- Deploy to EC2 with blue/green
- Run smoke tests and synthetic tests
- Validate health checks

### 3. Promotion (Dev → Prod)
- Verify image signatures
- Deploy to production with same digest
- Run production smoke tests
- Monitor for issues

## 🔒 Security Features

### Supply Chain Security
- **Image Signing**: All images signed with cosign
- **SBOM Generation**: Software Bill of Materials for each build
- **Vulnerability Scanning**: Trivy security scans
- **Policy Gates**: Unsigned artifacts rejected

### Access Control
- **OIDC Authentication**: No hardcoded credentials
- **IAM Roles**: Least privilege access
- **KMS Encryption**: All data encrypted at rest
- **Network Security**: VPC isolation and security groups

### Secrets Management
- **AWS Secrets Manager**: Centralized secrets storage
- **Automatic Rotation**: Scheduled secret rotation
- **Log Redaction**: Secrets never appear in logs
- **Cross-Region Replication**: Secrets available in all regions

## 📈 Scalability

### Current Implementation
- **Lambda Pre-warming**: Provisioned concurrency for production
- **Auto Scaling**: EC2 instances scale based on CPU/memory
- **Load Balancing**: ALB distributes traffic across instances

### Multi-Region Plan
- **Active/Active**: Deploy to multiple regions
- **Route 53**: DNS-based traffic routing
- **Cross-Region Replication**: ECR and secrets replication
- **Failover**: Automatic failover on region outage

## 🛠️ Operations

### Deploy
```bash
# Deploy infrastructure
cd terraform
terraform apply

# Deploy application
git push origin main
```

### Monitor
```bash
# Check deployment status
aws codedeploy list-deployments --application-name podinfo-lambda-deploy

# View logs
aws logs tail /aws/lambda/podinfo-lambda --follow
```

### Scale
```bash
# Scale Lambda concurrency
aws lambda put-provisioned-concurrency-config \
  --function-name podinfo-lambda \
  --provisioned-concurrency-config ProvisionedConcurrencyCount=10

# Scale EC2 instances
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name podinfo-asg \
  --desired-capacity 4
```

### Teardown
```bash
# Destroy all resources
./scripts/teardown.sh dev

# Confirm destruction
./scripts/teardown.sh dev true
```

## 🔍 Troubleshooting

### Common Issues
1. **Deployment Failures**: Check CodeDeploy logs and health checks
2. **Performance Issues**: Monitor CloudWatch metrics and alarms
3. **Security Issues**: Review IAM policies and security groups
4. **Cost Issues**: Monitor AWS Cost Explorer and optimize resources

### Debug Commands
```bash
# Check Lambda function status
aws lambda get-function --function-name podinfo-lambda

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check CloudWatch alarms
aws cloudwatch describe-alarms --alarm-names podinfo-lambda-errors
```

## 📚 Documentation

- **[Architecture Diagram](docs/architecture.svg)**: Visual system architecture
- **[Scalability Design](docs/scalability-design.md)**: Scaling strategies and implementation
- **[Environment Config](ENVIRONMENT.md)**: Detailed environment configuration
- **[API Documentation](app/README.md)**: Application API endpoints

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Issues**: Create a GitHub issue
- **Documentation**: Check the docs/ directory
- **AWS Support**: Enterprise level support included
- **Team**: DevOps team for internal support

---

**Built with ❤️ for modern, secure, and scalable deployments**
