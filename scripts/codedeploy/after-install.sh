#!/bin/bash
set -e

echo "Configuring podinfo application..."

# Read deployment configuration from environment
AWS_REGION=${AWS_REGION:-us-west-2}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}

# Get the image URI from deployment metadata
if [ -f /opt/podinfo/deployment-config.json ]; then
    IMAGE_URI=$(jq -r '.image_uri' /opt/podinfo/deployment-config.json)
    echo "Using image: $IMAGE_URI"
else
    echo "⚠️  No deployment config found, using latest image"
    # Fallback to latest
    IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/podinfo-podinfo:latest"
fi

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Pull the new image
echo "Pulling image: $IMAGE_URI"
docker pull $IMAGE_URI

# Tag for convenience
docker tag $IMAGE_URI podinfo:deployed

echo "✅ Application configured and image pulled"
exit 0

