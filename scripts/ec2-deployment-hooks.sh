#!/bin/bash

# EC2 CodeDeploy deployment hooks for Podinfo application
# These scripts are used by AWS CodeDeploy for blue/green deployments

set -e

# Common variables
APP_NAME="podinfo"
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-latest}"
ECR_REGISTRY="${ECR_REGISTRY:-}"
PORT=8080

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# BeforeInstall hook
before_install() {
    log "BeforeInstall: Preparing system for deployment"
    
    # Update system packages
    yum update -y
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        yum install -y docker
        systemctl start docker
        systemctl enable docker
    fi
    
    # Install CloudWatch agent if not present
    if ! command -v amazon-cloudwatch-agent-ctl &> /dev/null; then
        log "Installing CloudWatch agent..."
        yum install -y amazon-cloudwatch-agent
    fi
    
    # Login to ECR
    if [ -n "$ECR_REGISTRY" ]; then
        log "Logging into ECR..."
        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
            docker login --username AWS --password-stdin $ECR_REGISTRY
    fi
}

# AfterInstall hook
after_install() {
    log "AfterInstall: Setting up application environment"
    
    # Create application directory
    mkdir -p /opt/$APP_NAME
    chown ec2-user:ec2-user /opt/$APP_NAME
    
    # Start CloudWatch agent
    log "Starting CloudWatch agent..."
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config -m ec2 -c ssm:AmazonCloudWatch-linux -s
}

# ApplicationStart hook
application_start() {
    log "ApplicationStart: Starting $APP_NAME application"
    
    # Stop existing container if running
    if docker ps -q -f name=$APP_NAME | grep -q .; then
        log "Stopping existing $APP_NAME container..."
        docker stop $APP_NAME || true
        docker rm $APP_NAME || true
    fi
    
    # Pull the new image
    if [ -n "$ECR_REGISTRY" ]; then
        log "Pulling new image: $ECR_REGISTRY/$APP_NAME:$DOCKER_IMAGE_TAG"
        docker pull $ECR_REGISTRY/$APP_NAME:$DOCKER_IMAGE_TAG
    fi
    
    # Run the new container
    log "Starting new $APP_NAME container..."
    docker run -d \
        --name $APP_NAME \
        --restart unless-stopped \
        -p $PORT:8080 \
        -e ENVIRONMENT=${ENVIRONMENT:-dev} \
        -e LOG_LEVEL=${LOG_LEVEL:-INFO} \
        $ECR_REGISTRY/$APP_NAME:$DOCKER_IMAGE_TAG
    
    # Wait for application to be ready
    log "Waiting for application to be ready..."
    for i in {1..30}; do
        if curl -f http://localhost:$PORT/healthz >/dev/null 2>&1; then
            log "Application is ready!"
            break
        fi
        log "Waiting for application... (attempt $i/30)"
        sleep 10
    done
    
    # Verify application is running
    if ! curl -f http://localhost:$PORT/healthz >/dev/null 2>&1; then
        log "ERROR: Application failed to start properly"
        exit 1
    fi
}

# ApplicationStop hook
application_stop() {
    log "ApplicationStop: Stopping $APP_NAME application"
    
    # Stop the container
    if docker ps -q -f name=$APP_NAME | grep -q .; then
        log "Stopping $APP_NAME container..."
        docker stop $APP_NAME || true
        docker rm $APP_NAME || true
    fi
}

# ValidateService hook
validate_service() {
    log "ValidateService: Validating $APP_NAME service"
    
    # Check if container is running
    if ! docker ps -q -f name=$APP_NAME | grep -q .; then
        log "ERROR: Container is not running"
        exit 1
    fi
    
    # Check health endpoint
    if ! curl -f http://localhost:$PORT/healthz >/dev/null 2>&1; then
        log "ERROR: Health check failed"
        exit 1
    fi
    
    # Check info endpoint
    if ! curl -f http://localhost:$PORT/info >/dev/null 2>&1; then
        log "ERROR: Info endpoint check failed"
        exit 1
    fi
    
    log "Service validation successful"
}

# Main execution
case "$1" in
    "before_install")
        before_install
        ;;
    "after_install")
        after_install
        ;;
    "application_start")
        application_start
        ;;
    "application_stop")
        application_stop
        ;;
    "validate_service")
        validate_service
        ;;
    *)
        echo "Usage: $0 {before_install|after_install|application_start|application_stop|validate_service}"
        exit 1
        ;;
esac
