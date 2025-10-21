# IAM Policy Configuration for GitHub Actions

## Overview
The GitHub Actions workflow uses an IAM role (`podinfo-github-actions-role`) to deploy both Lambda and EC2 applications. This document explains the IAM policy configuration and why we use a broad policy instead of resource-specific restrictions.

## Current IAM Policy (Version 10)

The role uses a single managed policy: `podinfo-github-actions-policy` (v10)

### Key Permissions

#### 1. **ECR Permissions (including Image Scanning)**
```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage",
    "ecr:PutImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload",
    "ecr:DescribeRepositories",
    "ecr:ListImages",
    "ecr:DescribeImages",
    "ecr:PutImageScanningConfiguration",
    "ecr:StartImageScan",
    "ecr:DescribeImageScanFindings"
  ],
  "Resource": "*"
}
```

#### 2. **EC2 Launch Template Permissions**
```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeLaunchTemplates",
    "ec2:DescribeLaunchTemplateVersions",
    "ec2:CreateLaunchTemplate",
    "ec2:CreateLaunchTemplateVersion",
    "ec2:DeleteLaunchTemplate",
    "ec2:ModifyLaunchTemplate",
    "ec2:RunInstances"
  ],
  "Resource": "*"
}
```

#### 3. **Auto Scaling Permissions**
```json
{
  "Effect": "Allow",
  "Action": [
    "autoscaling:DescribeAutoScalingGroups",
    "autoscaling:UpdateAutoScalingGroup",
    "autoscaling:DescribeLaunchConfigurations",
    "autoscaling:DescribeScalingActivities"
  ],
  "Resource": "*"
}
```

#### 4. **API Gateway Permissions (for Smoke Tests)**
```json
{
  "Effect": "Allow",
  "Action": [
    "apigateway:GET",
    "apigatewayv2:GetApis",
    "apigatewayv2:GetApi"
  ],
  "Resource": "*"
}
```

#### 5. **IAM PassRole Permission**
```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::484826611466:role/podinfo-*",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": [
        "ec2.amazonaws.com",
        "autoscaling.amazonaws.com"
      ]
    }
  }
}
```

## Why Not Use Resource-Specific Restrictions?

### The Suggested Policy (Not Recommended)
```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:RunInstances",
    "ec2:DescribeLaunchTemplates",
    "ec2:DescribeLaunchTemplateVersions",
    "autoscaling:UpdateAutoScalingGroup"
  ],
  "Resource": [
    "arn:aws:ec2:<region>:<account-id>:launch-template/lt-035efe33d94fc0aaf",
    "arn:aws:autoscaling:<region>:<account-id>:autoScalingGroup:*:autoScalingGroupName/*"
  ]
}
```

### Problems with Resource-Specific Restrictions

#### 1. **Launch Template IDs Change**
- Each deployment creates a **new Launch Template** with a unique ID (e.g., `lt-035efe33d94fc0aaf`)
- The workflow uses timestamped names: `podinfo-github-actions-<timestamp>`
- Hardcoding a specific Launch Template ID would require:
  - Updating the IAM policy before every deployment
  - Or reusing the same Launch Template (which defeats the purpose of blue/green deployments)

#### 2. **Resource ARN Format Issues**
- Auto Scaling Groups don't work well with wildcard ARNs
- EC2 Launch Templates are ephemeral resources in our deployment strategy

#### 3. **Operational Complexity**
- Dynamic resource IDs require dynamic IAM policy updates
- Adds unnecessary complexity to the CI/CD pipeline
- Increases risk of deployment failures

### Our Solution: Scoped Wildcard Permissions

Instead of restricting by resource ARN, we use:

1. **Account-scoped wildcards**: `Resource: "*"` is limited to our AWS account (484826611466)
2. **Name-based restrictions**: Resources use the `podinfo-*` naming convention
3. **Service-scoped conditions**: `iam:PassRole` is restricted to specific AWS services
4. **Action-level restrictions**: Only the minimum required actions are allowed

### Security Considerations

✅ **Secure Enough Because:**
- All resources are in the same AWS account
- GitHub Actions uses OIDC authentication (no long-lived credentials)
- Role assumption is limited to the specific GitHub repository
- Actions are scoped to EC2, Auto Scaling, and Lambda services
- PassRole is conditioned on the service receiving the role

❌ **NOT Secure If:**
- Multiple teams/projects share the same AWS account
- You need strict multi-tenant isolation
- Compliance requires resource-level restrictions

## Best Practices for Production

For production environments with stricter requirements:

1. **Use separate AWS accounts** for each environment (dev/staging/prod)
2. **Implement resource tagging** and tag-based IAM policies
3. **Use AWS Organizations** with Service Control Policies (SCPs)
4. **Enable CloudTrail** for audit logging
5. **Implement least-privilege access** per team/service

## Monitoring and Auditing

The deployment includes:
- ✅ CloudWatch logging for all deployments
- ✅ AWS CloudTrail for IAM actions
- ✅ CloudWatch alarms for failed deployments
- ✅ Correlation IDs for request tracking

## Troubleshooting

### Common AccessDenied Errors

1. **"You are not authorized to use launch template"**
   - **Cause**: Missing `ec2:RunInstances` permission
   - **Solution**: Ensure IAM policy v8 is the default version

2. **"You are not authorized to perform: iam:PassRole"**
   - **Cause**: Missing PassRole permission
   - **Solution**: Verify the PassRole statement includes the correct condition

3. **"Policy version limit exceeded"**
   - **Cause**: IAM policies are limited to 5 versions
   - **Solution**: Delete old policy versions before creating new ones

## References

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Auto Scaling with Launch Templates](https://docs.aws.amazon.com/autoscaling/ec2/userguide/launch-templates.html)
- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

