#!/bin/bash
# Teardown Script for Podinfo Deployment System
# This script safely destroys all AWS resources in the correct order
# Idempotent and safe - can be run multiple times

set -e

REGION="${AWS_REGION:-us-west-2}"
ENVIRONMENT="${1:-dev}"

echo "========================================="
echo "Podinfo Deployment Teardown"
echo "========================================="
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo ""
echo "WARNING: This will destroy all resources for the $ENVIRONMENT environment!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Teardown cancelled."
  exit 0
fi

echo ""
echo "Starting teardown process..."
echo ""

# Step 1: Destroy Terraform-managed resources
echo "Step 1: Destroying Terraform resources..."
cd "$(dirname "$0")/../infra" || exit 1

if [ -f "terraform.tfstate" ] || [ -f ".terraform/terraform.tfstate" ]; then
  echo "Running terraform destroy..."
  terraform destroy -auto-approve -var="environment=$ENVIRONMENT" || {
    echo "Terraform destroy encountered errors, continuing with manual cleanup..."
  }
else
  echo "No Terraform state found, skipping terraform destroy"
fi

cd - > /dev/null

# Step 2: Clean up ECR images
echo ""
echo "Step 2: Cleaning up ECR images..."
for REPO in "podinfo-podinfo" "podinfo-podinfo-lambda"; do
  if aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" >/dev/null 2>&1; then
    echo "Deleting images from $REPO..."
    IMAGE_IDS=$(aws ecr list-images --repository-name "$REPO" --region "$REGION" --query 'imageIds[*]' --output json)
    if [ "$IMAGE_IDS" != "[]" ]; then
      aws ecr batch-delete-image \
        --repository-name "$REPO" \
        --image-ids "$IMAGE_IDS" \
        --region "$REGION" >/dev/null 2>&1 || echo "Could not delete images from $REPO"
    fi
    echo "Deleting repository $REPO..."
    aws ecr delete-repository \
      --repository-name "$REPO" \
      --force \
      --region "$REGION" 2>/dev/null || echo "Repository $REPO might already be deleted"
  else
    echo "Repository $REPO not found"
  fi
done

# Step 3: Clean up CodeDeploy resources
echo ""
echo "Step 3: Cleaning up CodeDeploy resources..."
for APP in "podinfo-lambda-deploy" "podinfo-ec2-deploy"; do
  if aws deploy get-application --application-name "$APP" --region "$REGION" >/dev/null 2>&1; then
    echo "Deleting CodeDeploy application $APP..."
    aws deploy delete-application \
      --application-name "$APP" \
      --region "$REGION" 2>/dev/null || echo "Could not delete $APP"
  fi
done

# Step 4: Clean up Lambda functions
echo ""
echo "Step 4: Cleaning up Lambda functions..."
for FUNC in "podinfo-lambda" "podinfo-secret-rotation"; do
  if aws lambda get-function --function-name "$FUNC" --region "$REGION" >/dev/null 2>&1; then
    echo "Deleting Lambda function $FUNC..."
    aws lambda delete-function \
      --function-name "$FUNC" \
      --region "$REGION" 2>/dev/null || echo "Could not delete function $FUNC"
  fi
done

# Step 5: Clean up API Gateway
echo ""
echo "Step 5: Cleaning up API Gateway..."
API_IDS=$(aws apigatewayv2 get-apis --region "$REGION" --query 'Items[?contains(Name, `podinfo`)].ApiId' --output text 2>/dev/null || echo "")
for API_ID in $API_IDS; do
  if [ -n "$API_ID" ]; then
    echo "Deleting API Gateway $API_ID..."
    aws apigatewayv2 delete-api \
      --api-id "$API_ID" \
      --region "$REGION" 2>/dev/null || echo "Could not delete API $API_ID"
  fi
done

# Step 6: Clean up Load Balancers
echo ""
echo "Step 6: Cleaning up Load Balancers..."
ALB_ARNS=$(aws elbv2 describe-load-balancers --region "$REGION" --query 'LoadBalancers[?contains(LoadBalancerName, `podinfo`)].LoadBalancerArn' --output text 2>/dev/null || echo "")
for ALB_ARN in $ALB_ARNS; do
  if [ -n "$ALB_ARN" ]; then
    echo "Deleting Load Balancer $ALB_ARN..."
    aws elbv2 delete-load-balancer \
      --load-balancer-arn "$ALB_ARN" \
      --region "$REGION" 2>/dev/null || echo "Could not delete ALB"
    
    # Wait for ALB deletion
    echo "Waiting for ALB deletion..."
    sleep 10
  fi
done

# Step 7: Clean up Target Groups
echo ""
echo "Step 7: Cleaning up Target Groups..."
TG_ARNS=$(aws elbv2 describe-target-groups --region "$REGION" --query 'TargetGroups[?contains(TargetGroupName, `podinfo`)].TargetGroupArn' --output text 2>/dev/null || echo "")
for TG_ARN in $TG_ARNS; do
  if [ -n "$TG_ARN" ]; then
    echo "Deleting Target Group $TG_ARN..."
    aws elbv2 delete-target-group \
      --target-group-arn "$TG_ARN" \
      --region "$REGION" 2>/dev/null || echo "Could not delete Target Group"
  fi
done

# Step 8: Clean up Auto Scaling Groups
echo ""
echo "Step 8: Cleaning up Auto Scaling Groups..."
ASG_NAMES=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `podinfo`)].AutoScalingGroupName' --output text 2>/dev/null || echo "")
for ASG_NAME in $ASG_NAMES; do
  if [ -n "$ASG_NAME" ]; then
    echo "Deleting Auto Scaling Group $ASG_NAME..."
    aws autoscaling delete-auto-scaling-group \
      --auto-scaling-group-name "$ASG_NAME" \
      --force-delete \
      --region "$REGION" 2>/dev/null || echo "Could not delete ASG $ASG_NAME"
  fi
done

# Step 9: Clean up Launch Templates
echo ""
echo "Step 9: Cleaning up Launch Templates..."
LT_IDS=$(aws ec2 describe-launch-templates --region "$REGION" --query 'LaunchTemplates[?contains(LaunchTemplateName, `podinfo`)].LaunchTemplateId' --output text 2>/dev/null || echo "")
for LT_ID in $LT_IDS; do
  if [ -n "$LT_ID" ]; then
    echo "Deleting Launch Template $LT_ID..."
    aws ec2 delete-launch-template \
      --launch-template-id "$LT_ID" \
      --region "$REGION" 2>/dev/null || echo "Could not delete Launch Template $LT_ID"
  fi
done

# Step 10: Clean up CloudWatch Log Groups
echo ""
echo "Step 10: Cleaning up CloudWatch Log Groups..."
LOG_GROUPS=$(aws logs describe-log-groups --region "$REGION" --query 'logGroups[?contains(logGroupName, `podinfo`) || contains(logGroupName, `/aws/lambda/podinfo`) || contains(logGroupName, `/aws/apigateway/podinfo`)].logGroupName' --output text 2>/dev/null || echo "")
for LOG_GROUP in $LOG_GROUPS; do
  if [ -n "$LOG_GROUP" ]; then
    echo "Deleting Log Group $LOG_GROUP..."
    aws logs delete-log-group \
      --log-group-name "$LOG_GROUP" \
      --region "$REGION" 2>/dev/null || echo "Could not delete Log Group $LOG_GROUP"
  fi
done

# Step 11: Clean up Secrets Manager secrets
echo ""
echo "Step 11: Cleaning up Secrets Manager secrets..."
SECRETS=$(aws secretsmanager list-secrets --region "$REGION" --query 'SecretList[?contains(Name, `podinfo`)].Name' --output text 2>/dev/null || echo "")
for SECRET in $SECRETS; do
  if [ -n "$SECRET" ]; then
    echo "Deleting secret $SECRET (7-day recovery window)..."
    aws secretsmanager delete-secret \
      --secret-id "$SECRET" \
      --recovery-window-in-days 7 \
      --region "$REGION" 2>/dev/null || echo "Could not delete secret $SECRET"
  fi
done

# Step 12: Clean up VPCs
echo ""
echo "Step 12: Cleaning up VPCs..."
VPC_IDS=$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=tag:Name,Values=*podinfo*" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")
for VPC_ID in $VPC_IDS; do
  if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)" ]; then
    echo "Cleaning up VPC $VPC_ID..."
    
    # Delete NAT Gateways
    NAT_GW_IDS=$(aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[?State==`available`].NatGatewayId' --output text 2>/dev/null || echo "")
    for NAT_GW_ID in $NAT_GW_IDS; do
      echo "  Deleting NAT Gateway $NAT_GW_ID..."
      aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GW_ID" --region "$REGION" 2>/dev/null || true
    done
    
    # Wait for NAT Gateway deletion
    if [ -n "$NAT_GW_IDS" ]; then
      echo "  Waiting for NAT Gateway deletion (60s)..."
      sleep 60
    fi
    
    # Delete Internet Gateway
    IGW_IDS=$(aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null || echo "")
    for IGW_ID in $IGW_IDS; do
      echo "  Detaching and deleting Internet Gateway $IGW_ID..."
      aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$REGION" 2>/dev/null || true
      aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$REGION" 2>/dev/null || true
    done
    
    # Delete Subnets
    SUBNET_IDS=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
    for SUBNET_ID in $SUBNET_IDS; do
      echo "  Deleting Subnet $SUBNET_ID..."
      aws ec2 delete-subnet --subnet-id "$SUBNET_ID" --region "$REGION" 2>/dev/null || true
    done
    
    # Delete Security Groups (except default)
    SG_IDS=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
    for SG_ID in $SG_IDS; do
      echo "  Deleting Security Group $SG_ID..."
      aws ec2 delete-security-group --group-id "$SG_ID" --region "$REGION" 2>/dev/null || true
    done
    
    # Delete VPC
    echo "  Deleting VPC $VPC_ID..."
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION" 2>/dev/null || echo "Could not delete VPC $VPC_ID (may have dependencies)"
  fi
done

# Step 13: Release Elastic IPs
echo ""
echo "Step 13: Releasing Elastic IPs..."
EIP_ALLOC_IDS=$(aws ec2 describe-addresses --region "$REGION" --query 'Addresses[?contains(Tags[?Key==`Name`].Value | [0], `podinfo`)].AllocationId' --output text 2>/dev/null || echo "")
for EIP_ALLOC_ID in $EIP_ALLOC_IDS; do
  if [ -n "$EIP_ALLOC_ID" ]; then
    echo "Releasing EIP $EIP_ALLOC_ID..."
    aws ec2 release-address \
      --allocation-id "$EIP_ALLOC_ID" \
      --region "$REGION" 2>/dev/null || echo "Could not release EIP $EIP_ALLOC_ID"
  fi
done

echo ""
echo "========================================="
echo "Teardown completed!"
echo "========================================="
echo ""
echo "Note: Some resources may have a deletion delay (NAT Gateways, Secrets)"
echo "Re-run this script if you encounter dependency errors."
echo ""
echo "To remove the Terraform backend (S3 + DynamoDB):"
echo "  ./scripts/teardown-backend.sh"
echo ""
