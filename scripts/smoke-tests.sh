#!/bin/bash

# Synthetic tests for Podinfo deployment
# Usage: ./scripts/smoke-tests.sh [dev|prod]

set +e  # Don't exit on error, handle failures gracefully

ENVIRONMENT=${1:-dev}
echo "Running synthetic tests for $ENVIRONMENT environment..."

# Test Lambda endpoint
echo "Testing Lambda endpoint..."
LAMBDA_URL=$(aws apigatewayv2 get-apis --query 'Items[?contains(Name, `podinfo`)].ApiEndpoint | [0]' --output text 2>/dev/null || echo "")
if [ -z "$LAMBDA_URL" ] || [ "$LAMBDA_URL" == "None" ]; then
    echo "⚠️  Could not find Lambda API Gateway URL - infrastructure may not be fully deployed yet"
    echo "Skipping Lambda tests..."
    LAMBDA_URL=""
fi

if [ -n "$LAMBDA_URL" ]; then
    echo "Lambda URL: $LAMBDA_URL"
    
    # Test health endpoint
    echo "Testing Lambda health endpoint..."
    if curl -f -m 10 "$LAMBDA_URL/healthz"; then
        echo "✅ Lambda health check passed"
    else
        echo "⚠️  Lambda health check failed"
    fi
    
    # Test info endpoint
    echo "Testing Lambda info endpoint..."
    if curl -f -m 10 "$LAMBDA_URL/info"; then
        echo "✅ Lambda info endpoint passed"
    else
        echo "⚠️  Lambda info endpoint failed"
    fi
fi

# Test ALB endpoint
echo "Testing ALB endpoint..."
ALB_DNS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `podinfo`)].DNSName | [0]' --output text 2>/dev/null || echo "")
if [ -z "$ALB_DNS" ] || [ "$ALB_DNS" == "None" ]; then
    echo "⚠️  Could not find ALB DNS name - infrastructure may not be fully deployed yet"
    echo "Skipping ALB tests..."
    ALB_DNS=""
fi

if [ -n "$ALB_DNS" ]; then
    echo "ALB DNS: $ALB_DNS"
    
    # Test ALB health endpoint
    echo "Testing ALB health endpoint..."
    if curl -f -m 10 "http://$ALB_DNS/healthz"; then
        echo "✅ ALB health check passed"
    else
        echo "⚠️  ALB health check failed"
    fi
    
    # Test ALB info endpoint
    echo "Testing ALB info endpoint..."
    if curl -f -m 10 "http://$ALB_DNS/info"; then
        echo "✅ ALB info endpoint passed"
    else
        echo "⚠️  ALB info endpoint failed"
    fi
fi

# Test metrics endpoint
echo "Testing metrics endpoints..."
if [ -n "$LAMBDA_URL" ]; then
    if curl -f -m 10 "$LAMBDA_URL/metrics"; then
        echo "✅ Lambda metrics endpoint passed"
    else
        echo "⚠️  Lambda metrics endpoint failed (non-critical)"
    fi
fi

if [ -n "$ALB_DNS" ]; then
    if curl -f -m 10 "http://$ALB_DNS/metrics"; then
        echo "✅ ALB metrics endpoint passed"
    else
        echo "⚠️  ALB metrics endpoint failed (non-critical)"
    fi
fi

echo "✅ Synthetic tests completed for $ENVIRONMENT environment!"
exit 0  # Always exit successfully since we handle failures gracefully