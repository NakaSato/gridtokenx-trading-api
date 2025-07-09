#!/bin/bash

# Energy Trading API Kubernetes Deployment Script
set -e

# Configuration
NAMESPACE="energy-trading"
IMAGE_NAME="energy-trading-api"
IMAGE_TAG="latest"
REGISTRY="" # Set your container registry here (e.g., your-registry.com/)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Function to build and push Docker image
build_and_push_image() {
    log_info "Building Docker image..."
    
    # Build the Docker image
    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
    
    if [ -n "$REGISTRY" ]; then
        # Tag and push to registry
        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}${IMAGE_NAME}:${IMAGE_TAG}
        log_info "Pushing image to registry..."
        docker push ${REGISTRY}${IMAGE_NAME}:${IMAGE_TAG}
        
        # Update deployment to use registry image
        sed -i.bak "s|image: ${IMAGE_NAME}:latest|image: ${REGISTRY}${IMAGE_NAME}:${IMAGE_TAG}|g" k8s/deployment.yaml
    fi
    
    log_info "Docker image built successfully"
}

# Function to deploy to Kubernetes
deploy_to_k8s() {
    log_info "Deploying to Kubernetes..."
    
    # Create namespace
    kubectl apply -f k8s/namespace.yaml
    
    # Apply all Kubernetes manifests
    kubectl apply -f k8s/deployment.yaml
    kubectl apply -f k8s/service.yaml
    kubectl apply -f k8s/pdb.yaml
    kubectl apply -f k8s/hpa.yaml
    
    # Optional: Apply ingress if you have an ingress controller
    if kubectl get ingressclass nginx &> /dev/null; then
        log_info "Nginx ingress controller detected, applying ingress..."
        kubectl apply -f k8s/ingress.yaml
    else
        log_warn "No nginx ingress controller found, skipping ingress deployment"
    fi
    
    log_info "Deployment completed successfully"
}

# Function to check deployment status
check_deployment() {
    log_info "Checking deployment status..."
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/energy-trading-api -n $NAMESPACE
    
    # Get deployment status
    kubectl get pods -n $NAMESPACE -l app=energy-trading-api
    kubectl get svc -n $NAMESPACE
    
    log_info "Deployment is ready!"
}

# Function to get service URL
get_service_url() {
    log_info "Getting service information..."
    
    # Check if using LoadBalancer or NodePort
    SERVICE_TYPE=$(kubectl get svc energy-trading-api-service -n $NAMESPACE -o jsonpath='{.spec.type}')
    
    if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
        EXTERNAL_IP=$(kubectl get svc energy-trading-api-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [ -n "$EXTERNAL_IP" ]; then
            echo -e "${GREEN}Service is available at: http://$EXTERNAL_IP${NC}"
        else
            log_warn "LoadBalancer external IP is pending..."
        fi
    elif [ "$SERVICE_TYPE" = "NodePort" ]; then
        NODE_PORT=$(kubectl get svc energy-trading-api-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
        echo -e "${GREEN}Service is available at: http://$NODE_IP:$NODE_PORT${NC}"
    else
        log_info "Service is running as ClusterIP. Use port-forwarding to access:"
        echo "kubectl port-forward svc/energy-trading-api-service 8080:80 -n $NAMESPACE"
    fi
}

# Function to clean up deployment
cleanup() {
    log_info "Cleaning up deployment..."
    kubectl delete -f k8s/ --ignore-not-found=true
    log_info "Cleanup completed"
}

# Main script
case "${1:-deploy}" in
    "build")
        build_and_push_image
        ;;
    "deploy")
        build_and_push_image
        deploy_to_k8s
        check_deployment
        get_service_url
        ;;
    "status")
        check_deployment
        get_service_url
        ;;
    "cleanup")
        cleanup
        ;;
    "help")
        echo "Usage: $0 {build|deploy|status|cleanup|help}"
        echo "  build   - Build and push Docker image"
        echo "  deploy  - Build, push, and deploy to Kubernetes (default)"
        echo "  status  - Check deployment status"
        echo "  cleanup - Remove deployment from Kubernetes"
        echo "  help    - Show this help message"
        ;;
    *)
        log_error "Invalid option: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
