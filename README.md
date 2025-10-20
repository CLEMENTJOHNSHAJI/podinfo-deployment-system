# Podinfo Multi-Target Deployment System

A comprehensive, secure deployment system that builds, signs, and ships the Podinfo container from GitHub Actions (OIDC) into AWS, then rolls it out in parallel to Lambda (container image behind API Gateway) and to a dual-host EC2/ALB stack.

## 🏗️ Architecture Overview

- Build & Sign via GitHub Actions (OIDC)
- AWS ECR registry (images signed; SBOM generated)
- Targets: Lambda (API Gateway) and EC2 behind ALB
- Strategy: Blue/Green with canary and rollback (via CodeDeploy)
- Secrets: AWS Secrets Manager (rotation optional)
- Observability: CloudWatch dashboards, alarms, logging
- Promotion: Dev → Prod with immutable digests

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
terraform plan

# Deploy infrastructure
terraform apply
```

### 4. Configure GitHub OIDC
In your GitHub repository Settings → Secrets and variables → Actions, set the required AWS and ECR secrets as described in `ENVIRONMENT.md`.

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
Deployed resources include ECR repositories, a Lambda function (with API Gateway), an ALB with EC2 capacity, CloudWatch monitoring, and Secrets Manager entries. Exact names are output by Terraform at apply time.

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
- Deploy to Lambda by digest (canary via CodeDeploy when enabled)
- Deploy to EC2 with blue/green (CodeDeploy)
- Run smoke tests and validate health checks

### 3. Promotion (Dev → Prod)
- Verify image signatures
- Deploy to production with same digest
- Run production smoke tests
- Monitor for issues

## 🔒 Security Features

### Supply Chain Security
- Image signing with cosign
- SBOM generation (syft)
- Vulnerability scanning (Trivy)
- Policy gate: only signed digests deploy

### Access Control
- OIDC to AWS (no static keys in CI)
- IAM least privilege
- Encryption at rest and VPC isolation

### Secrets Management
- AWS Secrets Manager for centralized secrets
- Optional rotation support (enable when needed)
- Ensure logs do not print secret values

## 📈 Scalability

### Current Implementation
- Optional Lambda pre-warming (provisioned concurrency)
- EC2 scaling via ASG and ALB

### Multi-Region Plan (overview)
- Active/active with Route 53 weighted or failover routing
- Replicated registries and secrets
- Health-based failover

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
Use Terraform variables and CI pipeline to adjust capacity (e.g., provisioned concurrency or ASG sizes). Avoid ad-hoc scaling commands unless for incident response.

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

## 📄 License
MIT License; see LICENSE for details.
