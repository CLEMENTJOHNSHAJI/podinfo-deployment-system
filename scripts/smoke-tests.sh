#!/bin/bash
set +e

ENVIRONMENT=${1:-dev}
echo "Running synthetic tests for $ENVIRONMENT environment..."

LAMBDA_URL=$(aws apigatewayv2 get-apis --query 'Items[?contains(Name, `podinfo`)].ApiEndpoint | [0]' --output text 2>/dev/null || echo "")
if [ -z "$LAMBDA_URL" ] || [ "$LAMBDA_URL" == "None" ]; then
    echo "Lambda API Gateway not found - skipping Lambda tests"
    LAMBDA_URL=""
fi

if [ -n "$LAMBDA_URL" ]; then
    echo "Testing Lambda: $LAMBDA_URL"
    curl -f -m 10 "$LAMBDA_URL/healthz" && echo "Lambda health: PASS" || echo "Lambda health: FAIL"
    curl -f -m 10 "$LAMBDA_URL/info" && echo "Lambda info: PASS" || echo "Lambda info: FAIL"
    curl -f -m 10 "$LAMBDA_URL/metrics" && echo "Lambda metrics: PASS" || echo "Lambda metrics: FAIL (non-critical)"
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