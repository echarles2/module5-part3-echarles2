#!/bin/bash

set -e

echo "Starting Minikube deployment..."

# 1. Basic checks
if ! command -v minikube >/dev/null 2>&1; then
    echo "Error: minikube is not installed."
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is not installed."
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed."
    exit 1
fi

if [ ! -d "k8s" ]; then
    echo "Error: k8s directory not found."
    exit 1
fi

# 2. Start minikube if needed
if ! minikube status >/dev/null 2>&1; then
    echo "Starting Minikube with Docker driver..."
    minikube start --driver=docker
else
    echo "Minikube is already running."
fi

# 3. Point Docker CLI to Minikube's Docker daemon
echo "Configuring shell to use Minikube Docker daemon..."
eval "$(minikube docker-env)"

# 4. Confirm docker-env worked
if [ -z "$MINIKUBE_ACTIVE_DOCKERD" ]; then
    echo "Error: Docker is not pointing to Minikube."
    exit 1
fi

echo "Docker is pointing to Minikube profile: $MINIKUBE_ACTIVE_DOCKERD"

# 5. Build images inside Minikube
echo "Building backend image..."
docker build -t backend:latest ./backend

echo "Building transactions image..."
docker build -t transactions:latest ./transactions

echo "Building studentportfolio image..."
docker build -t studentportfolio:latest ./studentportfolio

# 6. Verify images inside Minikube Docker
echo "Verifying local images in Minikube Docker..."
docker images | grep "backend"
docker images | grep "transactions"
docker images | grep "studentportfolio"

# 7. Apply manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/mongo-service.yaml
kubectl apply -f k8s/mongo-statefulset.yaml
kubectl apply -f k8s/backend-secret.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/transactions-deployment.yaml
kubectl apply -f k8s/transactions-service.yaml
kubectl apply -f k8s/studentportfolio-deployment.yaml
kubectl apply -f k8s/studentportfolio-service.yaml
kubectl apply -f k8s/nginx-configmap.yaml
kubectl apply -f k8s/nginx-deployment.yaml
kubectl apply -f k8s/nginx-service.yaml
kubectl apply -f k8s/backend-hpa.yaml
kubectl apply -f k8s/transactions-hpa.yaml

# 8. Restart deployments so pods use the freshly built local images
echo "Restarting deployments..."
kubectl rollout restart deployment/backend
kubectl rollout restart deployment/transactions
kubectl rollout restart deployment/studentportfolio
kubectl rollout restart deployment/nginx

# 9. Wait a moment and show resources
echo "Waiting for pods to begin creating..."
sleep 5

echo "Deployments:"
kubectl get deployments

echo
echo "Pods:"
kubectl get pods

echo
echo "Services:"
kubectl get services

echo
echo "Done. Launch the app with:"
echo "minikube service nginx"