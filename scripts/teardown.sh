#!/bin/bash

# Teardown script for Podinfo deployment system
# This script safely destroys all AWS resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="terraform"
ENVIRONMENT=${1:-dev}
CONFIRM=${2:-false}

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Confirmation prompt
confirm_teardown() {
    if [ "$CONFIRM" != "true" ]; then
        log_warn "This will destroy ALL resources in the $ENVIRONMENT environment!"
        log_warn "This action cannot be undone!"
        echo
        read -p "Are you sure you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Teardown cancelled."
            exit 0
        fi
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    log_info "Prerequisites check passed."
}

# Stop running deployments
stop_deployments() {
    log_info "Stopping running deployments..."
    
    # Stop Lambda deployments
    aws codedeploy list-deployments \
        --application-name podinfo-lambda-deploy \
        --deployment-group-name podinfo-lambda-group \
        --query 'deployments[?status==`InProgress`].deploymentId' \
        --output text | while read -r deployment_id; do
        if [ -n "$deployment_id" ]; then
            log_info "Stopping Lambda deployment: $deployment_id"
            aws codedeploy stop-deployment --deployment-id "$deployment_id" || true
        fi
    done
    
    # Stop EC2 deployments
    aws codedeploy list-deployments \
        --application-name podinfo-ec2-deploy \
        --deployment-group-name podinfo-ec2-group \
        --query 'deployments[?status==`InProgress`].deploymentId' \
        --output text | while read -r deployment_id; do
        if [ -n "$deployment_id" ]; then
            log_info "Stopping EC2 deployment: $deployment_id"
            aws codedeploy stop-deployment --deployment-id "$deployment_id" || true
        fi
    done
    
    log_info "Deployments stopped."
}

# Scale down Auto Scaling Groups
scale_down_asg() {
    log_info "Scaling down Auto Scaling Groups..."
    
    # Set ASG desired capacity to 0
    aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name podinfo-asg \
        --min-size 0 \
        --max-size 0 \
        --desired-capacity 0 || true
    
    # Wait for instances to terminate
    log_info "Waiting for instances to terminate..."
    aws autoscaling wait instance-in-service \
        --auto-scaling-group-name podinfo-asg \
        --no-instances-in-service || true
    
    log_info "Auto Scaling Groups scaled down."
}

# Empty S3 buckets
empty_s3_buckets() {
    log_info "Emptying S3 buckets..."
    
    # List all S3 buckets with podinfo prefix
    aws s3api list-buckets \
        --query 'Buckets[?contains(Name, `podinfo`)].Name' \
        --output text | while read -r bucket; do
        if [ -n "$bucket" ]; then
            log_info "Emptying bucket: $bucket"
            aws s3 rm "s3://$bucket" --recursive || true
        fi
    done
    
    log_info "S3 buckets emptied."
}

# Delete ECR images
delete_ecr_images() {
    log_info "Deleting ECR images..."
    
    # List ECR repositories
    aws ecr describe-repositories \
        --query 'repositories[?contains(repositoryName, `podinfo`)].repositoryName' \
        --output text | while read -r repository; do
        if [ -n "$repository" ]; then
            log_info "Deleting images in repository: $repository"
            
            # List all images
            aws ecr list-images \
                --repository-name "$repository" \
                --query 'imageIds[*]' \
                --output json | jq -r '.[] | @base64' | while read -r image; do
                if [ -n "$image" ]; then
                    image_data=$(echo "$image" | base64 -d)
                    image_digest=$(echo "$image_data" | jq -r '.imageDigest')
                    image_tag=$(echo "$image_data" | jq -r '.imageTag // empty')
                    
                    if [ -n "$image_tag" ]; then
                        aws ecr batch-delete-image \
                            --repository-name "$repository" \
                            --image-ids imageDigest="$image_digest",imageTag="$image_tag" || true
                    else
                        aws ecr batch-delete-image \
                            --repository-name "$repository" \
                            --image-ids imageDigest="$image_digest" || true
                    fi
                fi
            done
        fi
    done
    
    log_info "ECR images deleted."
}

# Destroy Terraform infrastructure
destroy_terraform() {
    log_info "Destroying Terraform infrastructure..."
    
    cd "$TERRAFORM_DIR" || exit 1
    
    # Initialize Terraform
    terraform init -upgrade
    
    # Plan destruction
    log_info "Planning infrastructure destruction..."
    terraform plan -destroy -var="environment=$ENVIRONMENT" -out=destroy.tfplan
    
    # Apply destruction
    log_info "Destroying infrastructure..."
    terraform apply -auto-approve destroy.tfplan
    
    # Clean up state files
    rm -f destroy.tfplan
    rm -f terraform.tfstate*
    rm -rf .terraform/
    
    cd ..
    log_info "Terraform infrastructure destroyed."
}

# Clean up remaining resources
cleanup_remaining() {
    log_info "Cleaning up remaining resources..."
    
    # Delete CloudWatch Log Groups
    aws logs describe-log-groups \
        --query 'logGroups[?contains(logGroupName, `podinfo`)].logGroupName' \
        --output text | while read -r log_group; do
        if [ -n "$log_group" ]; then
            log_info "Deleting log group: $log_group"
            aws logs delete-log-group --log-group-name "$log_group" || true
        fi
    done
    
    # Delete CloudWatch Alarms
    aws cloudwatch describe-alarms \
        --query 'MetricAlarms[?contains(AlarmName, `podinfo`)].AlarmName' \
        --output text | while read -r alarm; do
        if [ -n "$alarm" ]; then
            log_info "Deleting alarm: $alarm"
            aws cloudwatch delete-alarms --alarm-names "$alarm" || true
        fi
    done
    
    # Delete SNS Topics
    aws sns list-topics \
        --query 'Topics[?contains(TopicArn, `podinfo`)].TopicArn' \
        --output text | while read -r topic; do
        if [ -n "$topic" ]; then
            log_info "Deleting SNS topic: $topic"
            aws sns delete-topic --topic-arn "$topic" || true
        fi
    done
    
    log_info "Remaining resources cleaned up."
}

# Verify teardown
verify_teardown() {
    log_info "Verifying teardown..."
    
    # Check for remaining resources
    local remaining_resources=0
    
    # Check ECR repositories
    if aws ecr describe-repositories \
        --query 'repositories[?contains(repositoryName, `podinfo`)]' \
        --output text | grep -q .; then
        log_warn "ECR repositories still exist"
        ((remaining_resources++))
    fi
    
    # Check Lambda functions
    if aws lambda list-functions \
        --query 'Functions[?contains(FunctionName, `podinfo`)]' \
        --output text | grep -q .; then
        log_warn "Lambda functions still exist"
        ((remaining_resources++))
    fi
    
    # Check Auto Scaling Groups
    if aws autoscaling describe-auto-scaling-groups \
        --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `podinfo`)]' \
        --output text | grep -q .; then
        log_warn "Auto Scaling Groups still exist"
        ((remaining_resources++))
    fi
    
    if [ $remaining_resources -eq 0 ]; then
        log_info "✓ Teardown completed successfully. No remaining resources found."
    else
        log_warn "⚠ Teardown completed with $remaining_resources remaining resources."
        log_warn "Please check the AWS console for any remaining resources."
    fi
}

# Main teardown function
main() {
    log_info "Starting teardown for $ENVIRONMENT environment..."
    
    # Confirmation
    confirm_teardown
    
    # Prerequisites
    check_prerequisites
    
    # Stop deployments
    stop_deployments
    
    # Scale down ASG
    scale_down_asg
    
    # Empty S3 buckets
    empty_s3_buckets
    
    # Delete ECR images
    delete_ecr_images
    
    # Destroy Terraform
    destroy_terraform
    
    # Cleanup remaining
    cleanup_remaining
    
    # Verify teardown
    verify_teardown
    
    log_info "🎉 Teardown completed successfully!"
    log_info "All resources in the $ENVIRONMENT environment have been destroyed."
}

# Run main function
main "$@"
