#!/bin/bash
set -e

echo "Validating podinfo service..."

# Check if container is running
if ! docker ps | grep -q podinfo; then
    echo "❌ Container is not running"
    exit 1
fi

# Check health endpoint
MAX_RETRIES=30
RETRY_INTERVAL=2

for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf http://localhost:8080/healthz > /dev/null 2>&1; then
        echo "✅ Health check passed"
        
        # Verify the info endpoint
        if curl -sf http://localhost:8080/info > /dev/null 2>&1; then
            echo "✅ Info endpoint accessible"
            
            # Display version info
            echo "Application info:"
            curl -s http://localhost:8080/info | jq . || true
            
            echo "✅ Service validation completed successfully"
            exit 0
        else
            echo "⚠️  Info endpoint not accessible yet (attempt $i/$MAX_RETRIES)"
        fi
    else
        echo "⚠️  Health check failed (attempt $i/$MAX_RETRIES)"
    fi
    
    if [ $i -lt $MAX_RETRIES ]; then
        sleep $RETRY_INTERVAL
    fi
done

echo "❌ Service validation failed after $MAX_RETRIES attempts"
echo "Container logs:"
docker logs podinfo || true

exit 1

