#!/bin/bash

#
# Local Docker Deployment Script for Energy Trading API
#
# This script manages local Docker deployment of the Energy Trading API
# including PostgreSQL database and optional pgAdmin interface.
#
# Usage: ./deploy_local_docker.sh [command] [options]
# Commands:
#   up       - Start all services (default)
#   down     - Stop all services
#   restart  - Restart all services
#   logs     - Show logs for all services
#   build    - Build the API image
#   clean    - Clean up containers, images, and volumes
#   status   - Show status of all services
#   shell    - Open shell in API container
#   test     - Run tests against the Docker deployment
#

set -euo pipefail

# Configuration
readonly COMPOSE_FILE="docker-compose.yml"
readonly API_URL="http://localhost:3000"
readonly PGADMIN_URL="http://localhost:8080"
readonly TIMEOUT=60

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
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

log_verbose() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

# Print header
print_header() {
    echo -e "${BOLD}${BLUE}🐳 Energy Trading API - Local Docker Deployment${NC}"
    echo "=================================================="
    echo ""
}

# Show help message
show_help() {
    cat << EOF
Usage: $0 [command] [options]

Local Docker deployment management for Energy Trading API.

Commands:
  up          Start all services (default)
  down        Stop all services
  restart     Restart all services
  logs        Show logs for all services
  build       Build the API Docker image
  rebuild     Rebuild the API image from scratch
  clean       Clean up containers, images, and volumes
  status      Show status of all services
  shell       Open shell in API container
  test        Run tests against the Docker deployment
  help        Show this help message

Options:
  --with-admin    Include pgAdmin service
  --detach        Run in detached mode (background)
  --verbose       Enable verbose output
  --no-cache      Build without cache (for build/rebuild)

Examples:
  $0                      # Start API and database
  $0 up --with-admin     # Start with pgAdmin included
  $0 logs api            # Show API logs only
  $0 shell               # Open shell in API container
  $0 clean --all         # Complete cleanup
  $0 test               # Test the deployment

Service URLs:
  API:     $API_URL
  pgAdmin: $PGADMIN_URL (with --with-admin)

EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        log_error "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        log_error "Please install Docker Compose or use Docker with compose plugin"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        log_error "Please start Docker and try again"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get docker-compose command
get_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# Build the API image
build_image() {
    local no_cache="${1:-false}"
    local build_args=""
    
    if [[ "$no_cache" == "true" ]]; then
        build_args="--no-cache"
    fi
    
    log_info "Building Energy Trading API Docker image..."
    
    if docker build $build_args -t energy-trading-api:latest .; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Start services
start_services() {
    local with_admin="${1:-false}"
    local detached="${2:-true}"
    
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    local profiles=""
    if [[ "$with_admin" == "true" ]]; then
        profiles="--profile admin"
    fi
    
    local detach_flag=""
    if [[ "$detached" == "true" ]]; then
        detach_flag="-d"
    fi
    
    log_info "Starting Energy Trading API services..."
    
    if $compose_cmd $profiles up $detach_flag --build; then
        log_success "Services started successfully"
        
        if [[ "$detached" == "true" ]]; then
            echo ""
            log_info "Waiting for services to be ready..."
            wait_for_services
            show_service_info "$with_admin"
        fi
    else
        log_error "Failed to start services"
        exit 1
    fi
}

# Stop services
stop_services() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    log_info "Stopping Energy Trading API services..."
    
    if $compose_cmd down; then
        log_success "Services stopped successfully"
    else
        log_error "Failed to stop services"
        exit 1
    fi
}

# Restart services
restart_services() {
    local with_admin="${1:-false}"
    
    log_info "Restarting Energy Trading API services..."
    stop_services
    sleep 2
    start_services "$with_admin" "true"
}

# Show logs
show_logs() {
    local service="${1:-}"
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    if [[ -n "$service" ]]; then
        log_info "Showing logs for service: $service"
        $compose_cmd logs -f "$service"
    else
        log_info "Showing logs for all services"
        $compose_cmd logs -f
    fi
}

# Wait for services to be ready
wait_for_services() {
    local retries=30
    local count=0
    
    log_verbose "Waiting for API to be ready..."
    
    while [[ $count -lt $retries ]]; do
        if curl -s --max-time 2 "$API_URL/health" > /dev/null 2>&1; then
            log_success "API is ready"
            return 0
        fi
        
        ((count++))
        log_verbose "Waiting for API... (attempt $count/$retries)"
        sleep 2
    done
    
    log_error "API failed to become ready within timeout"
    return 1
}

# Show service information
show_service_info() {
    local with_admin="${1:-false}"
    
    echo ""
    echo "========================================="
    log_info "Service Information"
    echo "========================================="
    echo ""
    
    # API Service
    if curl -s --max-time 2 "$API_URL/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ API Service${NC}"
        echo "   URL: $API_URL"
        echo "   Health: $API_URL/health"
        echo "   Status: Running"
    else
        echo -e "${RED}❌ API Service${NC}"
        echo "   URL: $API_URL"
        echo "   Status: Not responding"
    fi
    echo ""
    
    # Database Service
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    if $compose_cmd ps postgres | grep -q "Up"; then
        echo -e "${GREEN}✅ PostgreSQL Database${NC}"
        echo "   Host: localhost"
        echo "   Port: 5432"
        echo "   Database: energy_trading"
        echo "   User: postgres"
        echo "   Status: Running"
    else
        echo -e "${RED}❌ PostgreSQL Database${NC}"
        echo "   Status: Not running"
    fi
    echo ""
    
    # pgAdmin Service (if enabled)
    if [[ "$with_admin" == "true" ]]; then
        if $compose_cmd ps pgadmin | grep -q "Up"; then
            echo -e "${GREEN}✅ pgAdmin${NC}"
            echo "   URL: $PGADMIN_URL"
            echo "   Email: admin@energytrading.com"
            echo "   Password: admin"
            echo "   Status: Running"
        else
            echo -e "${RED}❌ pgAdmin${NC}"
            echo "   Status: Not running"
        fi
        echo ""
    fi
    
    echo "========================================="
    echo -e "${BOLD}🚀 Quick Start Commands:${NC}"
    echo "• Test API:      curl $API_URL/health"
    echo "• View logs:     $0 logs"
    echo "• Open shell:    $0 shell"
    echo "• Run tests:     $0 test"
    echo "• Stop services: $0 down"
    echo ""
}

# Show service status
show_status() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    log_info "Service Status"
    echo ""
    
    $compose_cmd ps
    
    echo ""
    log_info "Docker Images"
    echo ""
    
    docker images | grep -E "(energy-trading|postgres|pgadmin)" || echo "No relevant images found"
}

# Open shell in API container
open_shell() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    log_info "Opening shell in API container..."
    
    if $compose_cmd ps api | grep -q "Up"; then
        $compose_cmd exec api /bin/bash
    else
        log_error "API container is not running"
        log_info "Start services first with: $0 up"
        exit 1
    fi
}

# Clean up Docker resources
cleanup() {
    local clean_all="${1:-false}"
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    log_info "Cleaning up Docker resources..."
    
    # Stop and remove containers
    $compose_cmd down -v --remove-orphans
    
    if [[ "$clean_all" == "true" ]]; then
        log_info "Performing complete cleanup..."
        
        # Remove images
        if docker images -q energy-trading-api &> /dev/null; then
            docker rmi energy-trading-api:latest || true
        fi
        
        # Remove volumes
        docker volume prune -f
        
        # Remove unused networks
        docker network prune -f
        
        log_success "Complete cleanup finished"
    else
        log_success "Basic cleanup finished"
    fi
}

# Test the deployment
test_deployment() {
    log_info "Testing Docker deployment..."
    
    # Check if services are running
    if ! curl -s --max-time 5 "$API_URL/health" > /dev/null; then
        log_error "API is not responding"
        log_info "Try starting services first with: $0 up"
        exit 1
    fi
    
    log_success "API health check passed"
    
    # Test basic endpoints
    local endpoints=(
        "/health"
        "/api/energy/prosumers"
        "/api/energy/orders/buy"
        "/api/energy/orders/sell"
    )
    
    local tests_passed=0
    local tests_total=${#endpoints[@]}
    
    for endpoint in "${endpoints[@]}"; do
        log_verbose "Testing endpoint: $endpoint"
        
        if curl -s --max-time 5 "$API_URL$endpoint" > /dev/null; then
            log_success "✅ $endpoint"
            ((tests_passed++))
        else
            log_error "❌ $endpoint"
        fi
    done
    
    echo ""
    echo "========================================="
    echo "Test Results: $tests_passed/$tests_total endpoints passed"
    echo "========================================="
    
    if [[ $tests_passed -eq $tests_total ]]; then
        log_success "All tests passed! 🎉"
        return 0
    else
        log_error "Some tests failed"
        return 1
    fi
}

# Parse command line arguments
parse_arguments() {
    local command="${1:-up}"
    local with_admin=false
    local detached=true
    local verbose=false
    local no_cache=false
    local clean_all=false
    
    shift || true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-admin)
                with_admin=true
                shift
                ;;
            --detach)
                detached=true
                shift
                ;;
            --no-detach)
                detached=false
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --no-cache)
                no_cache=true
                shift
                ;;
            --all)
                clean_all=true
                shift
                ;;
            *)
                if [[ "$command" == "logs" && -z "${service:-}" ]]; then
                    service="$1"
                    shift
                else
                    log_error "Unknown option: $1"
                    exit 1
                fi
                ;;
        esac
    done
    
    # Execute command
    case "$command" in
        "up"|"start")
            start_services "$with_admin" "$detached"
            ;;
        "down"|"stop")
            stop_services
            ;;
        "restart")
            restart_services "$with_admin"
            ;;
        "logs")
            show_logs "${service:-}"
            ;;
        "build")
            build_image "$no_cache"
            ;;
        "rebuild")
            build_image "true"
            ;;
        "clean"|"cleanup")
            cleanup "$clean_all"
            ;;
        "status")
            show_status
            ;;
        "shell")
            open_shell
            ;;
        "test")
            test_deployment
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Main function
main() {
    print_header
    check_prerequisites
    
    if [[ $# -eq 0 ]]; then
        parse_arguments "up"
    else
        parse_arguments "$@"
    fi
}

# Run main function with all arguments
main "$@"
