# CodeDeploy Configuration Files

This directory contains AWS CodeDeploy AppSpec files for blue/green deployments.

## Files

- **`appspec-ec2.yml`** - CodeDeploy configuration for EC2 deployments
- **`appspec-lambda.yml`** - CodeDeploy configuration for Lambda deployments

## Current Status

These files are **prepared for future use** but not currently active in the deployment pipeline.

### Why Not Currently Used?

The current implementation uses:
- **Lambda**: Direct function updates with version publishing
- **EC2**: Launch template updates with Auto Scaling Group rollout

This approach works without requiring the CodeDeploy CLI, which makes the pipeline more portable and resilient.

## How to Enable Full CodeDeploy (Optional)

If you want to enable full AWS CodeDeploy blue/green deployments:

### 1. Prerequisites
- CodeDeploy applications and deployment groups must be created via Terraform
- CodeDeploy CLI must be available in GitHub Actions runner

### 2. For EC2 Deployments

Update `.github/workflows/deploy.yml` to use CodeDeploy:

```yaml
- name: Deploy EC2 with CodeDeploy
  run: |
    aws deploy create-deployment \
      --application-name podinfo-ec2 \
      --deployment-group-name podinfo-ec2-group \
      --deployment-config-name CodeDeployDefault.OneAtATime \
      --s3-location bucket=my-codedeploy-bucket,key=appspec-ec2.yml,bundleType=yaml
```

### 3. For Lambda Deployments

Update `.github/workflows/deploy.yml` to use CodeDeploy:

```yaml
- name: Deploy Lambda with CodeDeploy
  run: |
    aws deploy create-deployment \
      --application-name podinfo-lambda \
      --deployment-group-name podinfo-lambda-group \
      --deployment-config-name CodeDeployDefault.LambdaCanary10Percent5Minutes \
      --s3-location bucket=my-codedeploy-bucket,key=appspec-lambda.yml,bundleType=yaml
```

## Benefits of Using CodeDeploy

When enabled, CodeDeploy provides:

1. **Automated traffic shifting** - Gradual rollout with canary deployments
2. **Automatic rollback** - CloudWatch alarm-triggered rollbacks
3. **Deployment history** - Track and audit all deployments
4. **Centralized control** - Manage deployments via AWS Console

## Current Deployment Flow (Without CodeDeploy)

### Lambda:
1. Build and sign container image
2. Push to ECR
3. Update Lambda function code
4. Publish new version
5. Run smoke tests

### EC2:
1. Build and sign container image
2. Push to ECR
3. Create new launch template with updated image
4. Update Auto Scaling Group
5. ASG performs rolling update
6. Run smoke tests

Both approaches support zero-downtime deployments and can be enhanced with CodeDeploy in the future.

