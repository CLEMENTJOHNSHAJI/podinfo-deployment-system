#!/bin/bash
# Debug script for GitHub Actions deployment

echo "=== DEPLOYMENT DEBUG INFORMATION ==="
echo "Timestamp: $(date -u)"
echo "AWS Region: $AWS_REGION"
echo "Caller Identity:"
aws sts get-caller-identity
echo "==============================="

# Check if Auto Scaling Group exists
echo "Checking Auto Scaling Groups..."
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `podinfo`)].AutoScalingGroupName' --output text)
echo "Auto Scaling Group Name: $ASG_NAME"

if [ -z "$ASG_NAME" ]; then
    echo "ERROR: No Auto Scaling Group found with 'podinfo' in the name"
    aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[].AutoScalingGroupName' --output table
    exit 1
fi

# Check if Launch Template creation succeeded
if [ -z "$NEW_LAUNCH_TEMPLATE_ID" ]; then
    echo "ERROR: Launch Template ID is empty"
    exit 1
fi

echo "Launch Template ID: $NEW_LAUNCH_TEMPLATE_ID"

# Verify the launch template exists and get its details
echo "Verifying Launch Template..."
aws ec2 describe-launch-templates --launch-template-ids $NEW_LAUNCH_TEMPLATE_ID --output json

echo "==============================="
