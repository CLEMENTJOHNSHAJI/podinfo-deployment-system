#!/bin/bash

# Synthetic tests for Podinfo deployment
# This script runs comprehensive tests to validate the deployment

set -e

ENVIRONMENT=${1:-dev}
TEST_TIMEOUT=30
MAX_RETRIES=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Test configuration
if [ "$ENVIRONMENT" = "prod" ]; then
    LAMBDA_URL="https://api.podinfo.prod.example.com"
    ALB_URL="https://podinfo.prod.example.com"
else
    LAMBDA_URL="https://api.podinfo.dev.example.com"
    ALB_URL="https://podinfo.dev.example.com"
fi

# Test functions
test_endpoint() {
    local url=$1
    local expected_status=$2
    local description=$3
    
    log_info "Testing $description: $url"
    
    for i in $(seq 1 $MAX_RETRIES); do
        if response=$(curl -s -w "%{http_code}" -o /dev/null "$url" --max-time $TEST_TIMEOUT); then
            if [ "$response" = "$expected_status" ]; then
                log_info "✓ $description passed (HTTP $response)"
                return 0
            else
                log_warn "✗ $description failed with HTTP $response (expected $expected_status)"
            fi
        else
            log_warn "✗ $description failed (attempt $i/$MAX_RETRIES)"
        fi
        
        if [ $i -lt $MAX_RETRIES ]; then
            sleep 5
        fi
    done
    
    log_error "✗ $description failed after $MAX_RETRIES attempts"
    return 1
}

test_health_endpoint() {
    local url=$1
    local description=$2
    
    log_info "Testing health endpoint: $description"
    
    for i in $(seq 1 $MAX_RETRIES); do
        if response=$(curl -s "$url/healthz" --max-time $TEST_TIMEOUT); then
            if echo "$response" | grep -q "healthy"; then
                log_info "✓ $description health check passed"
                return 0
            else
                log_warn "✗ $description health check failed: $response"
            fi
        else
            log_warn "✗ $description health check failed (attempt $i/$MAX_RETRIES)"
        fi
        
        if [ $i -lt $MAX_RETRIES ]; then
            sleep 5
        fi
    done
    
    log_error "✗ $description health check failed after $MAX_RETRIES attempts"
    return 1
}

test_readiness_endpoint() {
    local url=$1
    local description=$2
    
    log_info "Testing readiness endpoint: $description"
    
    for i in $(seq 1 $MAX_RETRIES); do
        if response=$(curl -s "$url/readyz" --max-time $TEST_TIMEOUT); then
            if echo "$response" | grep -q "ready"; then
                log_info "✓ $description readiness check passed"
                return 0
            else
                log_warn "✗ $description readiness check failed: $response"
            fi
        else
            log_warn "✗ $description readiness check failed (attempt $i/$MAX_RETRIES)"
        fi
        
        if [ $i -lt $MAX_RETRIES ]; then
            sleep 5
        fi
    done
    
    log_error "✗ $description readiness check failed after $MAX_RETRIES attempts"
    return 1
}

test_api_endpoints() {
    local url=$1
    local description=$2
    
    log_info "Testing API endpoints: $description"
    
    # Test home endpoint
    test_endpoint "$url" "200" "$description home endpoint" || return 1
    
    # Test version endpoint
    test_endpoint "$url/version" "200" "$description version endpoint" || return 1
    
    # Test info endpoint
    test_endpoint "$url/info" "200" "$description info endpoint" || return 1
    
    # Test data endpoint
    test_endpoint "$url/api/data" "200" "$description data endpoint" || return 1
    
    # Test metrics endpoint
    test_endpoint "$url/metrics" "200" "$description metrics endpoint" || return 1
    
    log_info "✓ All $description API endpoints passed"
    return 0
}

test_performance() {
    local url=$1
    local description=$2
    
    log_info "Testing performance: $description"
    
    # Test response time
    local start_time=$(date +%s%N)
    if curl -s "$url" --max-time $TEST_TIMEOUT > /dev/null; then
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
        
        if [ $duration -lt 1000 ]; then
            log_info "✓ $description response time: ${duration}ms (good)"
        elif [ $duration -lt 3000 ]; then
            log_warn "⚠ $description response time: ${duration}ms (acceptable)"
        else
            log_error "✗ $description response time: ${duration}ms (too slow)"
            return 1
        fi
    else
        log_error "✗ $description performance test failed"
        return 1
    fi
    
    return 0
}

test_load() {
    local url=$1
    local description=$2
    
    log_info "Testing load: $description"
    
    # Simulate load with multiple concurrent requests
    local pids=()
    local success_count=0
    local total_requests=10
    
    for i in $(seq 1 $total_requests); do
        (
            if curl -s "$url" --max-time $TEST_TIMEOUT > /dev/null 2>&1; then
                echo "success"
            else
                echo "failure"
            fi
        ) &
        pids+=($!)
    done
    
    # Wait for all requests to complete
    for pid in "${pids[@]}"; do
        if wait $pid; then
            ((success_count++))
        fi
    done
    
    local success_rate=$(( (success_count * 100) / total_requests ))
    
    if [ $success_rate -ge 90 ]; then
        log_info "✓ $description load test passed (${success_rate}% success rate)"
        return 0
    else
        log_error "✗ $description load test failed (${success_rate}% success rate)"
        return 1
    fi
}

# Main test execution
main() {
    log_info "Starting synthetic tests for $ENVIRONMENT environment"
    log_info "Lambda URL: $LAMBDA_URL"
    log_info "ALB URL: $ALB_URL"
    
    local test_results=()
    
    # Test Lambda endpoints
    log_info "=== Testing Lambda Deployment ==="
    test_health_endpoint "$LAMBDA_URL" "Lambda" && test_results+=("Lambda health: PASS") || test_results+=("Lambda health: FAIL")
    test_readiness_endpoint "$LAMBDA_URL" "Lambda" && test_results+=("Lambda readiness: PASS") || test_results+=("Lambda readiness: FAIL")
    test_api_endpoints "$LAMBDA_URL" "Lambda" && test_results+=("Lambda API: PASS") || test_results+=("Lambda API: FAIL")
    test_performance "$LAMBDA_URL" "Lambda" && test_results+=("Lambda performance: PASS") || test_results+=("Lambda performance: FAIL")
    test_load "$LAMBDA_URL" "Lambda" && test_results+=("Lambda load: PASS") || test_results+=("Lambda load: FAIL")
    
    # Test ALB endpoints
    log_info "=== Testing ALB Deployment ==="
    test_health_endpoint "$ALB_URL" "ALB" && test_results+=("ALB health: PASS") || test_results+=("ALB health: FAIL")
    test_readiness_endpoint "$ALB_URL" "ALB" && test_results+=("ALB readiness: PASS") || test_results+=("ALB readiness: FAIL")
    test_api_endpoints "$ALB_URL" "ALB" && test_results+=("ALB API: PASS") || test_results+=("ALB API: FAIL")
    test_performance "$ALB_URL" "ALB" && test_results+=("ALB performance: PASS") || test_results+=("ALB performance: FAIL")
    test_load "$ALB_URL" "ALB" && test_results+=("ALB load: PASS") || test_results+=("ALB load: FAIL")
    
    # Summary
    log_info "=== Test Results Summary ==="
    local pass_count=0
    local fail_count=0
    
    for result in "${test_results[@]}"; do
        echo "  $result"
        if [[ $result == *"PASS"* ]]; then
            ((pass_count++))
        else
            ((fail_count++))
        fi
    done
    
    log_info "Total tests: $((pass_count + fail_count))"
    log_info "Passed: $pass_count"
    log_info "Failed: $fail_count"
    
    if [ $fail_count -eq 0 ]; then
        log_info "🎉 All tests passed! Deployment is healthy."
        exit 0
    else
        log_error "❌ Some tests failed. Deployment may have issues."
        exit 1
    fi
}

# Run main function
main "$@"
