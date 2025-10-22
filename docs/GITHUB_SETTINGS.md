# Required GitHub Repository Settings

This document outlines the required GitHub repository settings for the Podinfo deployment system to function according to requirements.

## Branch Protection Rules

### Main Branch Protection

Navigate to: **Settings → Branches → Branch protection rules → Add rule**

**Branch name pattern**: `main`

#### Required Settings:

**Require a pull request before merging**
- Require approvals: **1**
- Dismiss stale pull request approvals when new commits are pushed
- Require review from Code Owners (optional)

**Require status checks to pass before merging**
- Require branches to be up to date before merging
- **Required status checks**:
  - `build-and-sign` (from build.yml workflow)
  - `deploy-dev` (from deploy.yml workflow)

**Require conversation resolution before merging**

**Require signed commits** (recommended)

**Require linear history** (recommended)

**Include administrators** (enforce rules for admins too)

**Do NOT check**:
- Allow force pushes
- Allow deletions

---

## GitHub Environments

### Production Environment

Navigate to: **Settings → Environments → New environment**

**Environment name**: `production`

#### Required Protection Rules:

**Required reviewers**
- Add at least **1 reviewer**
- Reviewers must approve before the `promote-to-prod` job can run

**Wait timer** (optional)
- 0 minutes (no wait) OR
- 5 minutes (cooling period after dev deployment)

**Deployment branches**
- Selected branches only: `main`

#### Environment Secrets (if different from repo):
- Can override repository secrets for production-specific values
- Not required if using same AWS account/resources

---

## Repository Secrets

Navigate to: **Settings → Secrets and variables → Actions → New repository secret**

### Required Secrets:

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `AWS_ACCOUNT_ID` | AWS Account ID | `123456789012` |
| `AWS_REGION` | AWS Region | `us-west-2` |
| `AWS_ROLE_ARN` | GitHub Actions IAM Role ARN | `arn:aws:iam::123456789012:role/podinfo-github-actions-role` |
| `ECR_REPOSITORY_LAMBDA` | Lambda ECR Repository URL | `123456789012.dkr.ecr.us-west-2.amazonaws.com/podinfo-podinfo-lambda` |
| `ECR_REPOSITORY_EC2` | EC2 ECR Repository URL | `123456789012.dkr.ecr.us-west-2.amazonaws.com/podinfo-podinfo` |
| `EC2_AMI_ID` | AMI ID for EC2 instances | `ami-0c55b159cbfafe1f0` (Amazon Linux 2023) |
| `EC2_SECURITY_GROUP_ID` | Security Group ID for EC2 | `sg-xxxxxxxxxxxxxxxxx` |
| `ENABLE_CODEDEPLOY` | Enable CodeDeploy deployments | `true` |

### How to Get Secret Values:

```bash
# Get AWS Account ID
aws sts get-caller-identity --query Account --output text

# Get AWS Region (from your Terraform vars)
echo "us-west-2"

# Get EC2 AMI ID (Amazon Linux 2023 in us-west-2)
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*x86_64" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text

# Get Security Group ID (from Terraform output or AWS Console)
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=podinfo-*" \
  --query 'SecurityGroups[0].GroupId' \
  --output text

# Get IAM Role ARN (after Terraform apply)
cd infra
terraform output github_actions_role_arn

# Get ECR Repository URLs (after Terraform apply)
terraform output ecr_repository_urls
```

---

## Workflow Permissions

Navigate to: **Settings → Actions → General → Workflow permissions**

**Select**: `Read and write permissions`
- Allows workflows to:
  - Push images to GitHub Packages (if used)
  - Create releases
  - Update deployment statuses

**Check**: `Allow GitHub Actions to create and approve pull requests`
- Enables automation workflows

---

## Security Settings

Navigate to: **Settings → Code security and analysis**

### Recommended Settings:

**Dependency graph**: Enabled
**Dependabot alerts**: Enabled
**Dependabot security updates**: Enabled

**Code scanning**:
- GitHub Advanced Security (if available)
- CodeQL analysis

**Secret scanning**: Enabled
- Prevents committing AWS keys, tokens, etc.

---

## Webhook Settings (Optional)

Navigate to: **Settings → Webhooks → Add webhook**

For deployment notifications to Slack/Teams:

- **Payload URL**: `https://hooks.slack.com/services/...`
- **Content type**: `application/json`
- **Events**: 
  - Deployment status
  - Workflow runs
  - Pushes

---

## Verification Checklist

After configuring all settings, verify:

- [ ] Push to `main` requires PR approval
- [ ] Build workflow runs automatically on PR
- [ ] Merging to `main` triggers build → deploy-dev
- [ ] `promote-to-prod` job waits for manual approval
- [ ] Reviewers receive notification for production deployments
- [ ] Failed deployments are blocked from merging
- [ ] Secrets are accessible to workflows (test with a dummy workflow)

---

## Testing the Setup

### 1. Test Branch Protection

```bash
# Try to push directly to main (should fail)
git checkout main
echo "test" >> test.txt
git add test.txt
git commit -m "Test direct push"
git push origin main
# Expected: Error - branch protection prevents direct pushes
```

### 2. Test PR Workflow

```bash
# Create feature branch
git checkout -b test-branch
echo "feature" >> feature.txt
git add feature.txt
git commit -m "Add feature"
git push origin test-branch

# Create PR via GitHub UI
# Verify: Build workflow runs automatically
```

### 3. Test Production Approval

```bash
# Merge PR to main
# Verify: deploy-dev runs automatically
# Verify: promote-to-prod job shows "Waiting for approval"
# Approve via GitHub UI
# Verify: promote-to-prod runs after approval
```

---

## Troubleshooting

### Issue: "Required status check is not enabled"
**Solution**: The status check name must exactly match the job name in the workflow file.

### Issue: "Pull request reviews not required"
**Solution**: Ensure you've added the rule to the `main` branch specifically, not a pattern.

### Issue: "Workflows can't access secrets"
**Solution**: Check that workflow has `permissions: { id-token: write, contents: read }` and secrets are set at repository level.

### Issue: "Environment protection rules not working"
**Solution**: Ensure the workflow job uses `environment: production` and not just a variable.

---

## Additional Resources

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches)
- [GitHub Environments Documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

