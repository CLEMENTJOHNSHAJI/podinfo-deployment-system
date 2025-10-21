#!/bin/bash
# Teardown Terraform Backend (S3 + DynamoDB)
# WARNING: This will destroy the Terraform state storage!
# Only run this after all environments have been destroyed

set -e

REGION="${AWS_REGION:-us-west-2}"
BUCKET_NAME="podinfo-terraform-state"
LOG_BUCKET="${BUCKET_NAME}-logs"
DYNAMODB_TABLE="podinfo-terraform-locks"
KMS_ALIAS="alias/podinfo-terraform-state"

echo "========================================="
echo "Terraform Backend Teardown"
echo "========================================="
echo "⚠️  WARNING: This will destroy Terraform state storage!"
echo "⚠️  Make sure all environments are destroyed first!"
echo ""
echo "Resources to be deleted:"
echo "  - S3 Bucket: $BUCKET_NAME"
echo "  - S3 Log Bucket: $LOG_BUCKET"
echo "  - DynamoDB Table: $DYNAMODB_TABLE"
echo "  - KMS Key: $KMS_ALIAS"
echo ""
read -p "Are you ABSOLUTELY SURE? Type 'DELETE' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
  echo "Teardown cancelled."
  exit 0
fi

echo ""
echo "Starting backend teardown..."

# Delete S3 bucket contents
echo ""
echo "Deleting S3 bucket contents..."
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
  aws s3 rm "s3://$BUCKET_NAME" --recursive --region "$REGION" || echo "⚠️  Could not delete bucket contents"
  
  # Delete all versions
  echo "Deleting all object versions..."
  aws s3api list-object-versions \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --query 'Versions[].{Key:Key,VersionId:VersionId}' \
    --output json | \
  jq -r '.[] | "--key \(.Key) --version-id \(.VersionId)"' | \
  while read -r args; do
    aws s3api delete-object --bucket "$BUCKET_NAME" $args --region "$REGION" 2>/dev/null || true
  done
  
  # Delete delete markers
  echo "Deleting delete markers..."
  aws s3api list-object-versions \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
    --output json | \
  jq -r '.[] | "--key \(.Key) --version-id \(.VersionId)"' | \
  while read -r args; do
    aws s3api delete-object --bucket "$BUCKET_NAME" $args --region "$REGION" 2>/dev/null || true
  done
  
  # Delete bucket
  echo "Deleting S3 bucket..."
  aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$REGION" || echo "⚠️  Could not delete bucket"
  echo "✅ S3 bucket deleted"
else
  echo "⚠️  S3 bucket not found"
fi

# Delete log bucket
echo ""
echo "Deleting S3 log bucket..."
if aws s3 ls "s3://$LOG_BUCKET" 2>/dev/null; then
  aws s3 rm "s3://$LOG_BUCKET" --recursive --region "$REGION" || true
  aws s3api delete-bucket --bucket "$LOG_BUCKET" --region "$REGION" || echo "⚠️  Could not delete log bucket"
  echo "✅ S3 log bucket deleted"
else
  echo "⚠️  S3 log bucket not found"
fi

# Delete DynamoDB table
echo ""
echo "Deleting DynamoDB table..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" >/dev/null 2>&1; then
  aws dynamodb delete-table --table-name "$DYNAMODB_TABLE" --region "$REGION"
  echo "✅ DynamoDB table deleted"
else
  echo "⚠️  DynamoDB table not found"
fi

# Schedule KMS key deletion
echo ""
echo "Scheduling KMS key deletion..."
KMS_KEY_ID=$(aws kms describe-key --key-id "$KMS_ALIAS" --region "$REGION" --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "")
if [ -n "$KMS_KEY_ID" ]; then
  # Delete alias first
  aws kms delete-alias --alias-name "$KMS_ALIAS" --region "$REGION" 2>/dev/null || echo "⚠️  Alias might not exist"
  
  # Schedule key deletion (minimum 7 days)
  aws kms schedule-key-deletion \
    --key-id "$KMS_KEY_ID" \
    --pending-window-in-days 7 \
    --region "$REGION"
  echo "✅ KMS key scheduled for deletion (7 days)"
else
  echo "⚠️  KMS key not found"
fi

echo ""
echo "========================================="
echo "✅ Backend teardown completed!"
echo "========================================="
echo ""
echo "Note: KMS key will be deleted in 7 days"
echo "You can cancel the deletion with:"
echo "  aws kms cancel-key-deletion --key-id $KMS_KEY_ID --region $REGION"
echo ""

