# Environment Configuration

This document describes the environment variables, configuration, and deployment settings for the Podinfo deployment system.

## AWS Configuration

### Regions
- **Primary Region**: `us-west-2` (Oregon)
- **Backup Region**: `us-east-1` (N. Virginia)

### Account Information
- **AWS Account ID**: `123456789012` (replace with actual account ID)
- **GitHub Organization**: `your-org`
- **GitHub Repository**: `podinfo-deployment-system`

## Infrastructure Components

### ECR Repositories
- **Podinfo (EC2)**: `123456789012.dkr.ecr.us-west-2.amazonaws.com/podinfo`
- **Podinfo Lambda**: `123456789012.dkr.ecr.us-west-2.amazonaws.com/podinfo-lambda`

### Lambda Configuration
- **Function Name**: `podinfo-lambda`
- **Runtime**: Container Image
- **Memory**: 512 MB
- **Timeout**: 30 seconds
- **API Gateway**: `podinfo-api`
- **Stage**: `dev` / `prod`

### EC2 Configuration
- **Instance Type**: `t3.medium`
- **AMI**: Amazon Linux 2
- **Auto Scaling Group**: `podinfo-asg`
- **Load Balancer**: `podinfo-alb`
- **Target Groups**: `podinfo-blue-tg`, `podinfo-green-tg`

### VPC Configuration
- **CIDR Block**: `10.0.0.0/16`
- **Public Subnets**: `10.0.1.0/24`, `10.0.2.0/24`
- **Private Subnets**: `10.0.11.0/24`, `10.0.12.0/24`
- **Availability Zones**: `us-west-2a`, `us-west-2b`

## Secrets Management

### AWS Secrets Manager
- **Secret Name**: `podinfo/database`
  - **Description**: Database connection secrets for Podinfo
  - **Rotation**: 30 days
  - **ARN**: `arn:aws:secretsmanager:us-west-2:123456789012:secret:podinfo/database-XXXXXX`

- **Secret Name**: `podinfo/api-keys`
  - **Description**: API keys for external services
  - **Rotation**: 90 days
  - **ARN**: `arn:aws:secretsmanager:us-west-2:123456789012:secret:podinfo/api-keys-XXXXXX`

### Secret Structure
```json
{
  "username": "podinfo-user",
  "password": "generated-password",
  "token": "generated-token",
  "api_key": "generated-api-key"
}
```

## CodeDeploy Configuration

### Lambda Deployment
- **Application**: `podinfo-lambda-deploy`
- **Deployment Group**: `podinfo-lambda-group`
- **Deployment Config**: `CodeDeployDefault.LambdaCanary10Percent5Minutes`
- **Rollback**: Automatic on deployment failure

### EC2 Deployment
- **Application**: `podinfo-ec2-deploy`
- **Deployment Group**: `podinfo-ec2-group`
- **Deployment Config**: `CodeDeployDefault.AllAtOnce`
- **Rollback**: Automatic on deployment failure

## Monitoring and Observability

### CloudWatch Dashboards
- **Dashboard Name**: `podinfo-dashboard`
- **URL**: `https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=podinfo-dashboard`

### Log Groups
- `/aws/lambda/podinfo-lambda`
- `/aws/podinfo-ec2`
- `/aws/podinfo-alb`
- `/aws/apigateway/podinfo-api`

### Alarms
- **Lambda Errors**: `podinfo-lambda-errors`
- **EC2 CPU High**: `podinfo-ec2-cpu-high`
- **ALB Target Health**: `podinfo-alb-target-health`
- **Application Health**: `podinfo-application-health`

### SNS Topics
- **Topic Name**: `podinfo-notifications`
- **ARN**: `arn:aws:sns:us-west-2:123456789012:podinfo-notifications`

## Security Configuration

### IAM Roles
- **GitHub Actions**: `podinfo-github-actions-role`
- **Lambda Execution**: `podinfo-lambda-execution-role`
- **EC2 Instance**: `podinfo-ec2-role`
- **CodeDeploy**: `podinfo-codedeploy-role`

### KMS Keys
- **Key Name**: `podinfo-key`
- **Key ID**: `arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012`
- **Rotation**: Enabled

### Security Groups
- **ALB**: `podinfo-alb-sg` (ports 80, 443)
- **EC2**: `podinfo-ec2-sg` (port 8080, 22)
- **Lambda**: `podinfo-lambda-sg` (outbound only)

## Application Configuration

### Environment Variables
- **PORT**: `8080`
- **ENVIRONMENT**: `dev` / `prod`
- **LOG_LEVEL**: `info`
- **VERSION**: `1.0.0`

### Health Check Endpoints
- **Health**: `/healthz`
- **Readiness**: `/readyz`
- **Metrics**: `/metrics`

### API Endpoints
- **Home**: `/`
- **Version**: `/version`
- **Info**: `/info`
- **Data**: `/api/data`
- **Secret**: `/api/secret`

## Deployment Configuration

### GitHub Actions
- **Workflow**: `.github/workflows/build.yml`
- **OIDC Role**: `podinfo-github-actions-role`
- **Branch Protection**: Required for `main` branch
- **Approval**: Required for production deployments

### Container Configuration
- **Base Image**: `alpine:3.18`
- **User**: `podinfo` (non-root)
- **Port**: `8080`
- **Health Check**: 30s interval, 10s timeout

### Deployment Strategy
- **Lambda**: Canary deployment (10% → 100% over 5 minutes)
- **EC2**: Blue/Green deployment with traffic shifting
- **Rollback**: Automatic on health check failures

## Network Configuration

### DNS
- **Lambda API**: `api.podinfo.dev.example.com` / `api.podinfo.prod.example.com`
- **ALB**: `podinfo.dev.example.com` / `podinfo.prod.example.com`

### SSL/TLS
- **Certificate**: AWS Certificate Manager
- **Protocol**: TLS 1.2+
- **Cipher Suites**: Modern standards

## Cost Optimization

### Resource Limits
- **EC2 Instances**: 2 (min), 2 (max)
- **Lambda Concurrency**: 1000
- **ALB**: 1 (Application Load Balancer)

### Monitoring Costs
- **CloudWatch Logs**: 30-day retention
- **CloudWatch Metrics**: Standard resolution
- **SNS**: Standard pricing

## Disaster Recovery

### Backup Strategy
- **EBS Snapshots**: Automated daily
- **RDS Snapshots**: Automated daily (if applicable)
- **S3 Cross-Region Replication**: Enabled

### Recovery Time Objectives
- **RTO**: 4 hours
- **RPO**: 1 hour

## Compliance and Governance

### Security Standards
- **Encryption**: At rest and in transit
- **Access Control**: Least privilege
- **Audit Logging**: CloudTrail enabled
- **Vulnerability Scanning**: ECR image scanning

### Compliance Frameworks
- **SOC 2**: Type II
- **ISO 27001**: Implemented
- **GDPR**: Data protection measures

## Troubleshooting

### Common Issues
1. **Deployment Failures**: Check CodeDeploy logs
2. **Health Check Failures**: Verify application endpoints
3. **Performance Issues**: Monitor CloudWatch metrics
4. **Security Issues**: Review IAM policies and security groups

### Support Contacts
- **AWS Support**: Enterprise level
- **GitHub Support**: Standard
- **Internal Team**: DevOps team

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024-01-01 | Initial deployment |
| 1.1.0 | 2024-01-15 | Added Lambda support |
| 1.2.0 | 2024-02-01 | Added EC2 support |
| 1.3.0 | 2024-02-15 | Added monitoring |
| 1.4.0 | 2024-03-01 | Added security scanning |

## Notes

- All ARNs and IDs are placeholders and should be replaced with actual values
- Environment-specific values should be configured per environment
- Regular security reviews and updates are recommended
- Cost monitoring and optimization should be performed monthly
