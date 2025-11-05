#!/bin/bash
set +e

ENVIRONMENT=${1:-dev}
echo "Running synthetic tests for $ENVIRONMENT environment..."
LAMBDA_STAGE="$ENVIRONMENT"

LAMBDA_URL=$(aws apigatewayv2 get-apis --query 'Items[?contains(Name, `podinfo`)].ApiEndpoint | [0]' --output text 2>/dev/null || echo "")
if [ -z "$LAMBDA_URL" ] || [ "$LAMBDA_URL" == "None" ]; then
    echo "Lambda API Gateway not found; trying Lambda Function URL"
    LAMBDA_FURL=$(aws lambda get-function-url-config --function-name podinfo-lambda --query 'FunctionUrl' --output text 2>/dev/null || echo "")
    if [ -n "$LAMBDA_FURL" ] && [ "$LAMBDA_FURL" != "None" ]; then
        LAMBDA_URL="$LAMBDA_FURL"
        LAMBDA_STAGE=""
    else
        echo "No Lambda Function URL configured - skipping Lambda tests"
        LAMBDA_URL=""
    fi
fi

if [ -n "$LAMBDA_URL" ]; then
    if [ -n "$LAMBDA_STAGE" ]; then
        echo "Testing Lambda via API Gateway: $LAMBDA_URL/$LAMBDA_STAGE"
        curl -f -m 10 "$LAMBDA_URL/$LAMBDA_STAGE/healthz" && echo "Lambda health: PASS" || echo "Lambda health: FAIL"
        curl -f -m 10 "$LAMBDA_URL/$LAMBDA_STAGE/info" && echo "Lambda info: PASS" || echo "Lambda info: FAIL"
        curl -f -m 10 "$LAMBDA_URL/$LAMBDA_STAGE/metrics" && echo "Lambda metrics: PASS" || echo "Lambda metrics: FAIL (non-critical)"
    else
        echo "Testing Lambda via Function URL: $LAMBDA_URL"
        curl -f -m 10 "$LAMBDA_URL/healthz" && echo "Lambda health: PASS" || echo "Lambda health: FAIL"
        curl -f -m 10 "$LAMBDA_URL/info" && echo "Lambda info: PASS" || echo "Lambda info: FAIL"
        curl -f -m 10 "$LAMBDA_URL/metrics" && echo "Lambda metrics: PASS" || echo "Lambda metrics: FAIL (non-critical)"
    fi
fi

ALB_DNS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `podinfo`)].DNSName | [0]' --output text 2>/dev/null || echo "")
if [ -z "$ALB_DNS" ] || [ "$ALB_DNS" == "None" ]; then
    echo "ALB not found - skipping ALB tests"
    ALB_DNS=""
fi

if [ -n "$ALB_DNS" ]; then
    echo "Testing ALB: $ALB_DNS"
    curl -f -m 10 "http://$ALB_DNS/healthz" && echo "ALB health: PASS" || echo "ALB health: FAIL"
    curl -f -m 10 "http://$ALB_DNS/info" && echo "ALB info: PASS" || echo "ALB info: FAIL"
    curl -f -m 10 "http://$ALB_DNS/metrics" && echo "ALB metrics: PASS" || echo "ALB metrics: FAIL (non-critical)"
fi

echo "Synthetic tests completed for $ENVIRONMENT"
exit 0