#!/bin/bash

set -e

ARTIFACT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="docker-compose.yml"
NGINX_LOG_FILE="nginx-logs"

echo "Starting deployment script..."
echo

# ----------------------------------------
# 1. Validate prerequisites
# ----------------------------------------

echo "Checking prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is not installed."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "Error: Docker Compose is not available."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Warning: curl is not installed. Health checks may fail."
fi

# Check if required ports are already in use
check_port() {
    PORT=$1
    if ss -tuln 2>/dev/null | grep -q ":$PORT "; then
        echo "Error: Port $PORT is already in use."
        exit 1
    fi
}

echo "Checking ports 80, 3000, 5000..."
check_port 80
check_port 3000
check_port 5000

echo "Prerequisite checks passed."
echo

# ----------------------------------------
# 2. CD into deployment artifact directory
# ----------------------------------------

echo "Changing into deployment directory..."
cd "$ARTIFACT_DIR"

# Validate docker compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: $COMPOSE_FILE not found in $ARTIFACT_DIR"
    exit 1
fi

echo "Found $COMPOSE_FILE"
echo

# ----------------------------------------
# 3. Build and deploy with compose
# ----------------------------------------

echo "Building and deploying containers..."
docker compose up --build -d
echo "Deployment complete."
echo

# ----------------------------------------
# 4. Health checks
# ----------------------------------------

echo "Running health checks..."

if command -v curl >/dev/null 2>&1; then
    echo "Checking frontend via Nginx at http://localhost..."
    curl -I http://localhost || true

    echo
    echo "Checking transactions service at http://localhost:3000..."
    curl -I http://localhost:3000 || true

    echo
    echo "Checking backend at http://localhost:5000..."
    curl -I http://localhost:5000 || true
fi

echo
echo "Listing Docker images..."
docker images
echo

echo "Showing running containers..."
docker ps
echo

# ----------------------------------------
# 5. Collect nginx container ID
# ----------------------------------------

NGINX_CONTAINER_ID=$(docker ps --filter "ancestor=nginx:alpine" --format "{{.ID}}" | head -n 1)

if [ -z "$NGINX_CONTAINER_ID" ]; then
    echo "Error: Could not find running container based on nginx:alpine"
    exit 1
fi

echo "Nginx container ID: $NGINX_CONTAINER_ID"
echo

# ----------------------------------------
# 6. Validate page renders
# ----------------------------------------

echo "Validating page render from http://localhost..."

PAGE_CONTENT=$(curl -s http://localhost || true)

if echo "$PAGE_CONTENT" | grep -qi "<html"; then
    echo "Page appears to render successfully."
else
    echo "Warning: Page did not appear to render valid HTML."
fi

echo

# ----------------------------------------
# 7. Ensure jq is installed
# ----------------------------------------

echo "Checking for jq..."

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is not installed. Installing jq..."

    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y jq
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y jq
    elif command -v apk >/dev/null 2>&1; then
        sudo apk add jq
    else
        echo "Error: Could not install jq automatically."
        exit 1
    fi
fi

echo "jq is available."
echo

# ----------------------------------------
# 8. Inspect nginx:alpine image and save output
# ----------------------------------------

echo "Inspecting nginx:alpine image..."
docker image inspect nginx:alpine > "$NGINX_LOG_FILE"

echo "Docker inspect output saved to $NGINX_LOG_FILE"
echo

# ----------------------------------------
# 9. Extract required fields from nginx-logs
# ----------------------------------------

echo "Extracting required values from $NGINX_LOG_FILE..."
echo

echo "RepoTags:"
jq '.[0].RepoTags' "$NGINX_LOG_FILE"
echo

echo "Created:"
jq -r '.[0].Created' "$NGINX_LOG_FILE"
echo

echo "Os:"
jq -r '.[0].Os' "$NGINX_LOG_FILE"
echo

echo "Config:"
jq '.[0].Config' "$NGINX_LOG_FILE"
echo

echo "ExposedPorts:"
jq '.[0].Config.ExposedPorts' "$NGINX_LOG_FILE"
echo

echo "Script completed successfully."