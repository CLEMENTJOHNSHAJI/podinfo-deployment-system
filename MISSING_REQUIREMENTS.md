# Missing Requirements Checklist

## Critical Missing Items

### 1. ❌ Terraform S3+DynamoDB Backend
**Requirement**: "S3+DynamoDB for TF state"
**Status**: NOT CONFIGURED
**Action Needed**: Add backend configuration to infra/main.tf

### 2. ❌ Teardown Script
**Requirement**: "Teardown: scripted, idempotent, and safe"
**Status**: NOT IMPLEMENTED
**Action Needed**: Create scripts/teardown.sh

### 3. ⚠️ CodeDeploy for Lambda & EC2
**Requirement**: "Blue/green releases with canary shift (~10%/~5m) and automatic rollback via CodeDeploy"
**Status**: TERRAFORM EXISTS BUT NOT ACTIVE (enable_codedeploy=false in terraform.tfvars)
**Action Needed**: Verify CodeDeploy is properly configured and enabled

### 4. ⚠️ Exactly 2 EC2 Instances  
**Requirement**: "Auto Scaling group (exactly 2 instances)"
**Status**: CONFIGURED AS 1 in terraform.tfvars
**Action Needed**: Update asg_min_size, asg_max_size, asg_desired_capacity to 2

### 5. ⚠️ ALB HTTPS
**Requirement**: "ALB (HTTPS)"
**Status**: UNKNOWN - need to verify ALB listener configuration
**Action Needed**: Verify HTTPS listener with ACM certificate

### 6. ❌ Log Redaction for Secrets
**Requirement**: "Leak-proofing: implement log redaction so the secret never appears in CloudWatch"
**Status**: NOT IMPLEMENTED
**Action Needed**: Add log filtering/redaction for secrets

### 7. ⚠️ Correlation ID in Access Logs
**Requirement**: "Include correlation ID in access logs across both targets"
**Status**: PARTIAL - middleware exists in Go code, need to verify logs
**Action Needed**: Verify correlation ID appears in CloudWatch logs

### 8. ⚠️ Human Approval for Prod
**Requirement**: "Human approval required between environments; include a short checklist in the repo"
**Status**: PARTIAL - promote.yml has environment: production, but no checklist
**Action Needed**: Create PROMOTION_CHECKLIST.md

### 9. ⚠️ Branch Protection
**Requirement**: "Branch protection and an 'approval to prod' step are required"
**Status**: CANNOT VERIFY - GitHub repo setting
**Action Needed**: Document branch protection settings

### 10. ⚠️ Digest-Based Deployment Verification
**Requirement**: "Policy gate: deployments must reference a signed image digest"
**Status**: PARTIAL - cosign verify exists but may not fail deployment
**Action Needed**: Ensure unsigned images are rejected

## Implemented Items ✅

1. ✅ OIDC Authentication (GitHub Actions → AWS)
2. ✅ Image Signing (cosign)
3. ✅ SBOM Generation (syft)
4. ✅ ECR with KMS encryption
5. ✅ Secrets Manager with rotation function
6. ✅ CloudWatch Dashboard  
7. ✅ CloudWatch Alarms
8. ✅ Lambda deployment
9. ✅ EC2 deployment with ALB
10. ✅ Correlation ID middleware
11. ✅ Multi-environment (dev/prod)
12. ✅ Scalability implementation (Lambda provisioned concurrency)
13. ✅ Architecture diagram
14. ✅ README.md
15. ✅ ENVIRONMENT.md
16. ✅ Scalability roadmap doc

## Priority Actions (Ordered by Impact)

1. **HIGH**: Add Terraform backend (S3+DynamoDB)
2. **HIGH**: Create teardown script
3. **HIGH**: Fix EC2 ASG to exactly 2 instances
4. **HIGH**: Enable CodeDeploy (set enable_codedeploy=true)
5. **MEDIUM**: Implement log redaction for secrets
6. **MEDIUM**: Add promotion checklist
7. **MEDIUM**: Verify HTTPS on ALB
8. **LOW**: Verify correlation ID in logs
9. **LOW**: Document branch protection
10. **LOW**: Strengthen digest-based deployment gate

