#!/bin/bash
# Bootstrap Terraform Backend (S3 + DynamoDB)
# This script creates the S3 bucket and DynamoDB table for Terraform state management
# Run this ONCE before running terraform init

set -e

REGION="${AWS_REGION:-us-west-2}"
BUCKET_NAME="podinfo-terraform-state"
DYNAMODB_TABLE="podinfo-terraform-locks"
KMS_ALIAS="alias/podinfo-terraform-state"

echo "========================================="
echo "Bootstrapping Terraform Backend"
echo "========================================="
echo "Region: $REGION"
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "KMS Alias: $KMS_ALIAS"
echo ""

# Create KMS Key for state encryption
echo "Creating KMS key for state encryption..."
KMS_KEY_ID=$(aws kms create-key \
  --description "Terraform state encryption key for Podinfo" \
  --region "$REGION" \
  --query 'KeyMetadata.KeyId' \
  --output text 2>/dev/null || echo "")

if [ -z "$KMS_KEY_ID" ]; then
  echo "KMS key might already exist or creation failed"
  KMS_KEY_ID=$(aws kms describe-key --key-id "$KMS_ALIAS" --region "$REGION" --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "")
fi

if [ -n "$KMS_KEY_ID" ]; then
  echo "KMS Key ID: $KMS_KEY_ID"
  
  # Create alias if it doesn't exist
  aws kms create-alias \
    --alias-name "$KMS_ALIAS" \
    --target-key-id "$KMS_KEY_ID" \
    --region "$REGION" 2>/dev/null || echo "KMS alias might already exist"
  
  # Enable key rotation
  aws kms enable-key-rotation \
    --key-id "$KMS_KEY_ID" \
    --region "$REGION" 2>/dev/null || echo "Key rotation might already be enabled"
fi

# Create S3 bucket for Terraform state
echo ""
echo "Creating S3 bucket for Terraform state..."
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
  echo "S3 bucket already exists: $BUCKET_NAME"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" \
    --no-cli-pager
  echo "S3 bucket created: $BUCKET_NAME"
fi

# Enable versioning
echo "Enabling S3 versioning..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled \
  --region "$REGION"
echo "S3 versioning enabled"

# Enable encryption
echo "Enabling S3 encryption..."
if [ -n "$KMS_KEY_ID" ]; then
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "aws:kms",
          "KMSMasterKeyID": "'"$KMS_KEY_ID"'"
        },
        "BucketKeyEnabled": true
      }]
    }' \
    --region "$REGION"
else
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }' \
    --region "$REGION"
fi
echo "S3 encryption enabled"

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region "$REGION"
echo "Public access blocked"

# Enable bucket logging
echo "Enabling access logging..."
LOG_BUCKET="${BUCKET_NAME}-logs"
aws s3api create-bucket \
  --bucket "$LOG_BUCKET" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" \
  --no-cli-pager 2>/dev/null || echo "Log bucket might already exist"

aws s3api put-bucket-logging \
  --bucket "$BUCKET_NAME" \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "'"$LOG_BUCKET"'",
      "TargetPrefix": "terraform-state-logs/"
    }
  }' \
  --region "$REGION" 2>/dev/null || echo "Logging might already be enabled"

# Create DynamoDB table for state locking
echo ""
echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --table-name "$DYNAMODB_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION" \
  --no-cli-pager 2>/dev/null && echo "DynamoDB table created: $DYNAMODB_TABLE" || echo "DynamoDB table might already exist"

# Enable point-in-time recovery
echo "Enabling point-in-time recovery..."
aws dynamodb update-continuous-backups \
  --table-name "$DYNAMODB_TABLE" \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
  --region "$REGION" \
  --no-cli-pager 2>/dev/null || echo "PITR might already be enabled"

echo ""
echo "========================================="
echo "Terraform backend bootstrapped successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. cd infra"
echo "  2. terraform init"
echo "  3. terraform plan"
echo "  4. terraform apply"
echo ""

