#!/bin/bash
set -e

echo "Preparing for podinfo installation..."

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed"
fi

# Install CloudWatch agent if not present
if ! command -v /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl &> /dev/null; then
    echo "Installing CloudWatch agent..."
    yum install -y amazon-cloudwatch-agent
    echo "✅ CloudWatch agent installed"
else
    echo "✅ CloudWatch agent already installed"
fi

# Ensure deployment directory exists
mkdir -p /opt/podinfo
chown -R ec2-user:ec2-user /opt/podinfo

exit 0

