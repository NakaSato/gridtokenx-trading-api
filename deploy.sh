#!/bin/bash

#
# Energy Trading API Kubernetes Deployment Script
#
# This script automates the deployment of the Energy Trading API to Kubernetes,
# including Docker image building, pushing to registry, and Kubernetes deployment.
#
# Usage: ./deploy.sh [command] [options]
# Commands:
#   build    - Build and push Docker image only
#   deploy   - Build, push, and deploy to Kubernetes (default)
#   status   - Check deployment status
#   cleanup  - Remove deployment from Kubernetes
#   help     - Show this help message
#
# Environment Variables:
#   REGISTRY      - Container registry URL (optional)
#   IMAGE_TAG     - Docker image tag (default: latest)
#   NAMESPACE     - Kubernetes namespace (default: energy-trading)
#

set -euo pipefail

# Configuration
readonly NAMESPACE="${NAMESPACE:-energy-trading}"
readonly IMAGE_NAME="energy-trading-api"
readonly IMAGE_TAG="${IMAGE_TAG:-latest}"
readonly REGISTRY="${REGISTRY:-}"
readonly KUBECTL_TIMEOUT="300s"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print header
print_header() {
    echo -e "${BLUE}🚀 Energy Trading API Kubernetes Deployment${NC}"
    echo "============================================="
    echo "Namespace: $NAMESPACE"
    echo "Image:     $IMAGE_NAME:$IMAGE_TAG"
    if [[ -n "$REGISTRY" ]]; then
        echo "Registry:  $REGISTRY"
    fi
    echo ""
}

# Show help message
show_help() {
    cat << EOF
Usage: $0 [command] [options]

This script automates the deployment of the Energy Trading API to Kubernetes.

Commands:
  build    - Build and push Docker image only
  deploy   - Build, push, and deploy to Kubernetes (default)
  status   - Check deployment status and service information
  cleanup  - Remove deployment from Kubernetes
  help     - Show this help message

Environment Variables:
  REGISTRY      Container registry URL (optional)
                Example: REGISTRY=your-registry.com/ $0 deploy

  IMAGE_TAG     Docker image tag (default: latest)
                Example: IMAGE_TAG=v1.2.3 $0 deploy

  NAMESPACE     Kubernetes namespace (default: energy-trading)
                Example: NAMESPACE=production $0 deploy

Examples:
  $0                                    # Deploy with default settings
  $0 build                             # Build and push image only
  $0 status                            # Check deployment status
  REGISTRY=myregistry.com/ $0 deploy   # Deploy with custom registry

Prerequisites:
  - Docker installed and running
  - kubectl configured for your cluster
  - Kubernetes manifests in k8s/ directory
  - Docker registry access (if using REGISTRY)

EOF
}

# Check if required tools are installed
check_requirements() {
    local missing_tools=()

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        log_error "Please start Docker and try again"
        exit 1
    fi

    log_info "All required tools are available"
}

# Check if Kubernetes manifests exist
check_manifests() {
    local required_manifests=(
        "k8s/namespace.yaml"
        "k8s/deployment.yaml"
        "k8s/service.yaml"
    )

    local missing_manifests=()

    for manifest in "${required_manifests[@]}"; do
        if [[ ! -f "$manifest" ]]; then
            missing_manifests+=("$manifest")
        fi
    done

    if [[ ${#missing_manifests[@]} -gt 0 ]]; then
        log_error "Missing Kubernetes manifests: ${missing_manifests[*]}"
        log_error "Please ensure all required manifests are present in the k8s/ directory"
        exit 1
    fi

    log_info "All required Kubernetes manifests found"
}

# Function to build and push Docker image
build_and_push_image() {
    log_info "Building Docker image..."

    # Check if Dockerfile exists
    if [[ ! -f Dockerfile ]]; then
        log_error "Dockerfile not found in current directory"
        exit 1
    fi

    # Build the Docker image
    if docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi

    # Push to registry if specified
    if [[ -n "$REGISTRY" ]]; then
        local full_image_name="${REGISTRY}${IMAGE_NAME}:${IMAGE_TAG}"

        log_info "Tagging image for registry..."
        docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "$full_image_name"

        log_info "Pushing image to registry: $full_image_name"
        if docker push "$full_image_name"; then
            log_success "Image pushed to registry successfully"

            # Update deployment manifest to use registry image
            if [[ -f k8s/deployment.yaml ]]; then
                # Create backup
                cp k8s/deployment.yaml "k8s/deployment.yaml.bak"

                # Update image reference
                sed -i.tmp "s|image: ${IMAGE_NAME}:.*|image: ${full_image_name}|g" k8s/deployment.yaml
                rm -f k8s/deployment.yaml.tmp

                log_info "Updated deployment.yaml to use registry image"
            fi
        else
            log_error "Failed to push image to registry"
            exit 1
        fi
    else
        log_info "No registry specified, using local image"
    fi
}

# Function to deploy to Kubernetes
deploy_to_k8s() {
    log_info "Deploying to Kubernetes..."

    # Create namespace
    log_info "Creating namespace..."
    if kubectl apply -f k8s/namespace.yaml; then
        log_success "Namespace configuration applied"
    else
        log_warning "Failed to apply namespace configuration"
    fi

    # Apply core manifests
    local manifests=("deployment.yaml" "service.yaml")

    for manifest in "${manifests[@]}"; do
        if [[ -f "k8s/$manifest" ]]; then
            log_info "Applying $manifest..."
            if kubectl apply -f "k8s/$manifest"; then
                log_success "$manifest applied successfully"
            else
                log_error "Failed to apply $manifest"
                exit 1
            fi
        else
            log_warning "$manifest not found, skipping"
        fi
    done

    # Apply optional manifests
    local optional_manifests=("pdb.yaml" "hpa.yaml" "configmap.yaml" "secret.yaml")

    for manifest in "${optional_manifests[@]}"; do
        if [[ -f "k8s/$manifest" ]]; then
            log_info "Applying optional $manifest..."
            if kubectl apply -f "k8s/$manifest"; then
                log_success "Optional $manifest applied"
            else
                log_warning "Failed to apply optional $manifest"
            fi
        fi
    done

    # Apply ingress if ingress controller is available
    if [[ -f k8s/ingress.yaml ]]; then
        if kubectl get ingressclass nginx &> /dev/null; then
            log_info "NGINX ingress controller detected, applying ingress..."
            if kubectl apply -f k8s/ingress.yaml; then
                log_success "Ingress configuration applied"
            else
                log_warning "Failed to apply ingress configuration"
            fi
        else
            log_warning "No NGINX ingress controller found, skipping ingress deployment"
            log_info "To enable ingress, install an ingress controller first"
        fi
    fi

    log_success "Kubernetes deployment completed"
}

# Function to check deployment status
check_deployment() {
    log_info "Checking deployment status..."

    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' not found"
        return 1
    fi

    # Wait for deployment to be ready
    log_info "Waiting for deployment to be ready (timeout: $KUBECTL_TIMEOUT)..."
    if kubectl wait --for=condition=available --timeout="$KUBECTL_TIMEOUT" \
                    deployment/energy-trading-api -n "$NAMESPACE"; then
        log_success "Deployment is ready!"
    else
        log_error "Deployment failed to become ready within timeout"

        # Show deployment status for debugging
        echo ""
        log_info "Deployment status:"
        kubectl describe deployment energy-trading-api -n "$NAMESPACE" || true

        echo ""
        log_info "Pod status:"
        kubectl get pods -n "$NAMESPACE" -l app=energy-trading-api || true

        return 1
    fi

    # Show deployment information
    echo ""
    log_info "Deployment information:"
    kubectl get deployment energy-trading-api -n "$NAMESPACE" -o wide

    echo ""
    log_info "Pod information:"
    kubectl get pods -n "$NAMESPACE" -l app=energy-trading-api -o wide

    echo ""
    log_info "Service information:"
    kubectl get svc -n "$NAMESPACE"
}

# Function to get service URL and access information
get_service_url() {
    log_info "Getting service access information..."

    if ! kubectl get svc energy-trading-api-service -n "$NAMESPACE" &> /dev/null; then
        log_warning "Service 'energy-trading-api-service' not found in namespace '$NAMESPACE'"
        return 1
    fi

    local service_type
    service_type=$(kubectl get svc energy-trading-api-service -n "$NAMESPACE" \
                   -o jsonpath='{.spec.type}')

    echo ""
    echo "🌐 Service Access Information:"
    echo "=============================="

    case "$service_type" in
        "LoadBalancer")
            local external_ip
            external_ip=$(kubectl get svc energy-trading-api-service -n "$NAMESPACE" \
                         -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

            if [[ -n "$external_ip" && "$external_ip" != "null" ]]; then
                echo "✅ Service URL: http://$external_ip"
                echo "   Service Type: LoadBalancer"
            else
                log_warning "LoadBalancer external IP is pending..."
                echo "   Run 'kubectl get svc -n $NAMESPACE' to check status"
            fi
            ;;
        "NodePort")
            local node_port node_ip
            node_port=$(kubectl get svc energy-trading-api-service -n "$NAMESPACE" \
                       -o jsonpath='{.spec.ports[0].nodePort}')
            node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "")

            if [[ -z "$node_ip" ]]; then
                node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
            fi

            echo "✅ Service URL: http://$node_ip:$node_port"
            echo "   Service Type: NodePort"
            ;;
        "ClusterIP")
            local cluster_ip port
            cluster_ip=$(kubectl get svc energy-trading-api-service -n "$NAMESPACE" \
                        -o jsonpath='{.spec.clusterIP}')
            port=$(kubectl get svc energy-trading-api-service -n "$NAMESPACE" \
                  -o jsonpath='{.spec.ports[0].port}')

            echo "🔒 Service Type: ClusterIP (internal only)"
            echo "   Cluster IP: $cluster_ip:$port"
            echo "   To access externally, use port forwarding:"
            echo "   kubectl port-forward svc/energy-trading-api-service 8080:$port -n $NAMESPACE"
            echo "   Then access: http://localhost:8080"
            ;;
        *)
            log_warning "Unknown service type: $service_type"
            ;;
    esac

    # Check for ingress
    if kubectl get ingress -n "$NAMESPACE" &> /dev/null; then
        echo ""
        echo "🌍 Ingress Information:"
        kubectl get ingress -n "$NAMESPACE" -o wide
    fi

    echo ""
    echo "📊 Additional Commands:"
    echo "  View logs:    kubectl logs -f deployment/energy-trading-api -n $NAMESPACE"
    echo "  Scale app:    kubectl scale deployment energy-trading-api --replicas=3 -n $NAMESPACE"
    echo "  Port forward: kubectl port-forward svc/energy-trading-api-service 8080:80 -n $NAMESPACE"
    echo ""
}

# Function to clean up deployment
cleanup() {
    log_info "Cleaning up deployment from namespace '$NAMESPACE'..."

    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace '$NAMESPACE' not found, nothing to clean up"
        return 0
    fi

    # Delete all resources in the k8s directory
    if [[ -d k8s ]]; then
        log_info "Removing Kubernetes resources..."

        # Delete in reverse order to avoid dependency issues
        local manifests=(
            "k8s/ingress.yaml"
            "k8s/hpa.yaml"
            "k8s/pdb.yaml"
            "k8s/service.yaml"
            "k8s/deployment.yaml"
            "k8s/configmap.yaml"
            "k8s/secret.yaml"
        )

        for manifest in "${manifests[@]}"; do
            if [[ -f "$manifest" ]]; then
                log_info "Deleting $manifest..."
                kubectl delete -f "$manifest" --ignore-not-found=true
            fi
        done

        # Ask before deleting namespace
        echo ""
        read -p "Do you want to delete the namespace '$NAMESPACE'? (y/N): " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
            log_success "Namespace '$NAMESPACE' deleted"
        else
            log_info "Namespace '$NAMESPACE' preserved"
        fi
    else
        log_warning "k8s directory not found"
    fi

    log_success "Cleanup completed"
}

# Main function
main() {
    local command="${1:-deploy}"

    case "$command" in
        "build")
            print_header
            check_requirements
            build_and_push_image
            ;;
        "deploy")
            print_header
            check_requirements
            check_manifests
            build_and_push_image
            deploy_to_k8s
            check_deployment
            get_service_url
            ;;
        "status")
            print_header
            check_requirements
            check_deployment
            get_service_url
            ;;
        "cleanup")
            print_header
            check_requirements
            cleanup
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "Invalid command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
