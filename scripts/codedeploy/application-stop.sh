#!/bin/bash
set -e

echo "Stopping existing podinfo application..."

# Stop and remove existing container
if docker ps -a | grep -q podinfo; then
    docker stop podinfo || true
    docker rm podinfo || true
    echo "✅ Stopped existing podinfo container"
else
    echo "ℹ️  No existing podinfo container found"
fi

exit 0

