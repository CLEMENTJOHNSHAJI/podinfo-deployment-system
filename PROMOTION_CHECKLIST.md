# Production Promotion Checklist

This checklist must be completed before approving a promotion from `dev` to `prod`.

## Pre-Promotion Verification

### 1. Build & Artifact Quality
- [ ] Build workflow completed successfully
- [ ] Container image is signed with cosign
- [ ] SBOM (Software Bill of Materials) is generated and attached
- [ ] Image digest is immutable and recorded
- [ ] No critical vulnerabilities in Trivy security scan
- [ ] Image size is reasonable (< 500MB recommended)

### 2. Dev Environment Testing
- [ ] Lambda deployment succeeded in dev
- [ ] EC2 deployment succeeded in dev (both instances)
- [ ] Blue/Green deployment completed successfully
- [ ] Health checks passing on both targets (Lambda & ALB)
- [ ] Smoke tests passed (all endpoints responding)
- [ ] Synthetic tests passed (functional verification)

### 3. Observability & Monitoring
- [ ] CloudWatch logs are flowing from both targets
- [ ] Correlation IDs are visible in logs
- [ ] CloudWatch dashboard shows healthy metrics
- [ ] No alarms triggered during dev deployment
- [ ] Metrics show acceptable performance:
  - Lambda duration < 1000ms (p99)
  - ALB response time < 500ms (p99)
  - Error rate < 0.1%

### 4. Security & Secrets
- [ ] Secrets Manager integration working
- [ ] No secrets leaked in CloudWatch logs (verified)
- [ ] IAM roles follow least privilege
- [ ] No security group violations
- [ ] HTTPS working on ALB (if applicable)

### 5. Rollback Readiness
- [ ] Previous prod version is healthy and available
- [ ] Rollback plan documented
- [ ] CloudWatch alarms configured for automatic rollback
- [ ] CodeDeploy deployment groups configured correctly

## Production Deployment Plan

### Deployment Window
- **Scheduled Time**: _________________
- **Duration**: Approximately 30 minutes
- **Backup Window**: _________________

### Key Personnel
- **Deployment Lead**: _________________
- **On-Call Engineer**: _________________
- **Approver**: _________________

### Rollout Strategy
- [ ] Canary deployment: 10% traffic for 5 minutes
- [ ] Monitor metrics during canary phase
- [ ] Full traffic shift if canary is healthy
- [ ] Automatic rollback if alarms trigger

### Communication
- [ ] Stakeholders notified of deployment window
- [ ] Status page updated (if applicable)
- [ ] Slack/Teams channel notified

## During Deployment

### Monitoring Points
1. **Lambda Canary (0-5 min)**
   - Watch Lambda duration, errors, throttles
   - Check API Gateway 5xx rate
   - Verify correlation IDs in logs

2. **EC2 Blue/Green (0-5 min)**
   - Watch ALB target health
   - Monitor target group 5xx rate
   - Check EC2 instance CPU/memory

3. **Full Traffic Shift (5-10 min)**
   - Monitor all metrics in CloudWatch dashboard
   - Watch for alarm triggers
   - Verify health endpoints

### Go/No-Go Decision Points
- **T+2 min**: Are canary metrics healthy?
  - [ ] YES - Continue
  - [ ] NO - Rollback

- **T+5 min**: Are full deployment metrics healthy?
  - [ ] YES - Complete deployment
  - [ ] NO - Rollback

## Post-Deployment Validation

### Immediate Checks (T+10 min)
- [ ] All health endpoints returning 200
- [ ] Smoke tests passing in prod
- [ ] CloudWatch logs flowing correctly
- [ ] No error spikes in metrics
- [ ] Correlation IDs present in prod logs

### Extended Monitoring (T+30 min)
- [ ] Performance metrics within SLO
- [ ] No customer-reported issues
- [ ] Error budget not exceeded
- [ ] Secrets rotation still working

### Documentation
- [ ] Deployment notes recorded
- [ ] Any incidents documented
- [ ] Metrics baseline updated
- [ ] Post-mortem scheduled (if issues occurred)

## Rollback Procedure

If deployment fails or issues are detected:

1. **Immediate Actions**
   - Stop the promotion workflow in GitHub Actions
   - Trigger CodeDeploy rollback for both targets
   - Notify team in communication channel

2. **Verification**
   - Confirm previous version is serving traffic
   - Check health endpoints are green
   - Verify metrics return to baseline

3. **Post-Rollback**
   - Document reason for rollback
   - Create incident ticket
   - Schedule RCA (Root Cause Analysis)
   - Plan remediation for next deployment

## Sign-Off

**Approver Signature**: _________________  
**Date/Time**: _________________  
**Image Digest**: _________________  

**Notes**:

