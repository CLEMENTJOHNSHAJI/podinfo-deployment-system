#!/bin/bash

# User data script for EC2 instances
# This script sets up Docker, CloudWatch agent, and the Podinfo application

set -e

# Variables
ECR_REPOSITORY_URL="${ecr_repository_url}"
APP_PORT="${app_port}"
HEALTH_CHECK_PATH="${health_check_path}"
ENVIRONMENT="${environment}"

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "metrics": {
    "namespace": "Podinfo/EC2",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "diskio": {
        "measurement": ["io_time"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/podinfo-ec2",
            "log_stream_name": "{instance_id}/messages"
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "/aws/podinfo-ec2",
            "log_stream_name": "{instance_id}/secure"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Login to ECR
aws ecr get-login-password --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region) | \
  docker login --username AWS --password-stdin $ECR_REPOSITORY_URL

# Create application directory
mkdir -p /opt/podinfo
cd /opt/podinfo

# Create Docker Compose file
cat > docker-compose.yml << EOF
version: '3.8'
services:
  podinfo:
    image: $ECR_REPOSITORY_URL:latest
    container_name: podinfo
    ports:
      - "$APP_PORT:8080"
    environment:
      - ENVIRONMENT=$ENVIRONMENT
      - LOG_LEVEL=info
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080$HEALTH_CHECK_PATH"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped
    logging:
      driver: awslogs
      options:
        awslogs-group: /aws/podinfo-ec2
        awslogs-region: $(curl -s http://169.254.169.254/latest/meta-data/placement/region)
        awslogs-stream-prefix: podinfo
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.podinfo.rule=Host(\`podinfo.local\`)"
      - "traefik.http.services.podinfo.loadbalancer.server.port=8080"
EOF

# Create systemd service for Docker Compose
cat > /etc/systemd/system/podinfo.service << EOF
[Unit]
Description=Podinfo Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/podinfo
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Enable and start the service
systemctl daemon-reload
systemctl enable podinfo.service

# Create health check script
cat > /opt/podinfo/health_check.sh << 'EOF'
#!/bin/bash
HEALTH_URL="http://localhost:8080/healthz"
RESPONSE=$(curl -s -o /dev/null -w "%%{http_code}" $HEALTH_URL)
if [ $RESPONSE -eq 200 ]; then
    echo "Health check passed"
    exit 0
else
    echo "Health check failed with status: $RESPONSE"
    exit 1
fi
EOF

chmod +x /opt/podinfo/health_check.sh

# Create CodeDeploy hooks directory
mkdir -p /opt/codedeploy-agent/hooks

# Create deployment script
cat > /opt/podinfo/deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting deployment..."

# Pull latest image
docker-compose pull

# Stop current containers
docker-compose down

# Start new containers
docker-compose up -d

# Wait for health check
sleep 30

# Verify deployment
/opt/podinfo/health_check.sh

echo "Deployment completed successfully"
EOF

chmod +x /opt/podinfo/deploy.sh

# Create rollback script
cat > /opt/podinfo/rollback.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting rollback..."

# Stop current containers
docker-compose down

# Start previous containers (if any)
docker-compose up -d

echo "Rollback completed"
EOF

chmod +x /opt/podinfo/rollback.sh

# Start the application
systemctl start podinfo.service

# Log completion
echo "User data script completed at $(date)" >> /var/log/user-data.log
