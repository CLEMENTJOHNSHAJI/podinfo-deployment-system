#!/bin/bash
set -e

echo "Starting podinfo application..."

# Start the container
docker run -d \
  --name podinfo \
  --restart unless-stopped \
  -p 8080:8080 \
  -e ENVIRONMENT=${ENVIRONMENT:-production} \
  -e LOG_LEVEL=${LOG_LEVEL:-INFO} \
  -e AWS_REGION=${AWS_REGION:-us-west-2} \
  podinfo:deployed

# Wait for container to be healthy
echo "Waiting for container to start..."
for i in {1..30}; do
    if docker ps | grep -q podinfo; then
        echo "✅ Container started successfully"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Container failed to start"
        docker logs podinfo || true
        exit 1
    fi
    sleep 1
done

# Start CloudWatch agent
echo "Starting CloudWatch agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c ssm:AmazonCloudWatch-linux \
  -s || echo "⚠️  CloudWatch agent start failed (non-critical)"

echo "✅ Application started successfully"
exit 0

