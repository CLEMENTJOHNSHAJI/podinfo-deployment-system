#!/bin/bash

# Synthetic tests for Podinfo deployment
# Usage: ./scripts/synthetic-tests.sh [dev|prod]

set -e

ENVIRONMENT=${1:-dev}
echo "Running synthetic tests for $ENVIRONMENT environment..."

# Test Lambda endpoint
echo "Testing Lambda endpoint..."
LAMBDA_URL=$(aws apigatewayv2 get-apis --query 'Items[?Name==`podinfo-api`].ApiEndpoint' --output text)
if [ -z "$LAMBDA_URL" ]; then
    echo "ERROR: Could not find Lambda API Gateway URL"
    exit 1
fi

echo "Lambda URL: $LAMBDA_URL"

# Test health endpoint
echo "Testing Lambda health endpoint..."
curl -f "$LAMBDA_URL/healthz" || {
    echo "ERROR: Lambda health check failed"
    exit 1
}

# Test info endpoint
echo "Testing Lambda info endpoint..."
curl -f "$LAMBDA_URL/info" || {
    echo "ERROR: Lambda info endpoint failed"
    exit 1
}

# Test ALB endpoint
echo "Testing ALB endpoint..."
ALB_DNS=$(aws elbv2 describe-load-balancers --names podinfo-alb --query 'LoadBalancers[0].DNSName' --output text)
if [ -z "$ALB_DNS" ]; then
    echo "ERROR: Could not find ALB DNS name"
    exit 1
fi

echo "ALB DNS: $ALB_DNS"

# Test ALB health endpoint
echo "Testing ALB health endpoint..."
curl -f "http://$ALB_DNS/healthz" || {
    echo "ERROR: ALB health check failed"
    exit 1
}

# Test ALB info endpoint
echo "Testing ALB info endpoint..."
curl -f "http://$ALB_DNS/info" || {
    echo "ERROR: ALB info endpoint failed"
    exit 1
}

# Test metrics endpoint
echo "Testing metrics endpoints..."
curl -f "$LAMBDA_URL/metrics" || {
    echo "WARNING: Lambda metrics endpoint failed (non-critical)"
}

curl -f "http://$ALB_DNS/metrics" || {
    echo "WARNING: ALB metrics endpoint failed (non-critical)"
}

echo "✅ All synthetic tests passed for $ENVIRONMENT environment!"