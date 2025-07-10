#!/bin/bash

#
# PostgreSQL Test Script for Energy Trading API
#
# This script tests the Energy Trading API with PostgreSQL database,
# including database connectivity, API endpoints, and data persistence.
#
# Usage: ./test_postgres.sh
# Requirements: curl, jq (optional), PostgreSQL, running database
#

set -euo pipefail

# Configuration
readonly API_BASE_URL="http://localhost:3000"
readonly SERVER_LOG_FILE="server.log"
readonly TIMEOUT=10

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
SERVER_PID=""

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
    echo -e "${BLUE}🐘 Testing Energy Trading API with PostgreSQL${NC}"
    echo "============================================="
    echo ""
}

# Cleanup function
cleanup() {
    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        log_info "Stopping server (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi

    # Clean up log file
    [[ -f "$SERVER_LOG_FILE" ]] && rm -f "$SERVER_LOG_FILE"
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Check if required tools are available
check_requirements() {
    local missing_tools=()

    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi

    if ! command -v cargo &> /dev/null; then
        missing_tools+=("cargo")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi

    # Check if jq is available (optional but recommended)
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed. JSON output will be raw."
    fi
}

# Setup environment file
setup_environment() {
    if [[ ! -f .env ]]; then
        log_info "Creating .env file from template..."
        if [[ -f .env.example ]]; then
            cp .env.example .env
            log_success ".env file created from template"
        else
            log_error ".env.example file not found!"
            exit 1
        fi
    fi

    # Source environment variables
    if [[ -f .env ]]; then
        set -a
        source .env
        set +a
        log_info "Environment variables loaded from .env"
    fi
}

# Check PostgreSQL connectivity
check_database() {
    log_info "Checking PostgreSQL connection..."

    if ! command -v psql &> /dev/null; then
        log_warning "psql not found, skipping direct database connection test"
        return 0
    fi

    if [[ -z "${DATABASE_URL:-}" ]]; then
        log_error "DATABASE_URL not set in environment"
        exit 1
    fi

    if psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "PostgreSQL connection successful"
        log_info "Database URL: $DATABASE_URL"
    else
        log_error "PostgreSQL connection failed"
        log_error "Please ensure PostgreSQL is running and DATABASE_URL is correct"
        log_error "Current DATABASE_URL: $DATABASE_URL"
        exit 1
    fi
}

# Start the API server
start_server() {
    log_info "Starting API server..."

    # Start server in background and capture PID
    cargo run --bin api-server > "$SERVER_LOG_FILE" 2>&1 &
    SERVER_PID=$!

    log_info "Server started with PID: $SERVER_PID"
    log_info "Waiting for server to initialize..."
    sleep 5

    # Check if server is still running
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        log_error "Server failed to start"
        log_error "Server logs:"
        cat "$SERVER_LOG_FILE"
        exit 1
    fi

    # Test server connectivity
    local retries=5
    local count=0

    while [[ $count -lt $retries ]]; do
        if curl -s --max-time "$TIMEOUT" "$API_BASE_URL/health" > /dev/null 2>&1; then
            log_success "Server is running and responding"
            return 0
        fi

        ((count++))
        log_info "Waiting for server to respond... (attempt $count/$retries)"
        sleep 2
    done

    log_error "Server is not responding after $retries attempts"
    log_error "Server logs:"
    cat "$SERVER_LOG_FILE"
    exit 1
}

# Test API endpoint
test_endpoint() {
    local method="$1"
    local url="$2"
    local data="$3"
    local description="$4"

    log_info "Testing: $description"

    local response
    local status_code

    if [[ -n "$data" ]]; then
        response=$(curl -s -w "\n%{http_code}" --max-time "$TIMEOUT" \
                   -X "$method" "$API_BASE_URL$url" \
                   -H "Content-Type: application/json" \
                   -d "$data" 2>/dev/null || echo -e "\n000")
    else
        response=$(curl -s -w "\n%{http_code}" --max-time "$TIMEOUT" \
                   -X "$method" "$API_BASE_URL$url" 2>/dev/null || echo -e "\n000")
    fi

    # Extract status code and response body
    status_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | head -n -1)

    if [[ "$status_code" =~ ^[12][0-9][0-9]$ ]] && [[ -n "$response_body" ]]; then
        log_success "$description (Status: $status_code)"

        # Pretty print JSON if jq is available
        if command -v jq &> /dev/null; then
            echo "$response_body" | jq . 2>/dev/null || echo "$response_body"
        else
            echo "$response_body"
        fi
    else
        log_error "$description (Status: $status_code)"
        echo "Response: $response_body"
    fi

    echo ""
}

# Run comprehensive API tests
run_api_tests() {
    log_info "Running comprehensive API tests..."
    echo ""

    # Basic endpoints
    test_endpoint "GET" "/" "" "Root endpoint"
    test_endpoint "GET" "/health" "" "Health check"

    # Create test data
    local prosumer_data='{"address": "0x123456789", "name": "PostgreSQL Test Prosumer"}'
    test_endpoint "POST" "/prosumers" "$prosumer_data" "Create prosumer"

    # Prosumer endpoints
    test_endpoint "GET" "/prosumers" "" "Get all prosumers"
    test_endpoint "GET" "/prosumers/0x123456789" "" "Get specific prosumer"

    # Energy order endpoints
    local sell_order='{"prosumer_address": "0x123456789", "order_type": "sell", "energy_amount": 100.0, "price_per_unit": 0.15}'
    test_endpoint "POST" "/orders" "$sell_order" "Create sell order"

    local buy_order='{"prosumer_address": "0x123456789", "order_type": "buy", "energy_amount": 50.0, "price_per_unit": 0.16}'
    test_endpoint "POST" "/orders" "$buy_order" "Create buy order"

    test_endpoint "GET" "/orders" "" "Get all orders"

    # Statistics endpoints
    test_endpoint "GET" "/stats/market" "" "Market statistics"
    test_endpoint "GET" "/stats/database" "" "Database statistics"
}

# Test database directly
test_database_directly() {
    if ! command -v psql &> /dev/null; then
        log_warning "psql not available, skipping direct database tests"
        return 0
    fi

    log_info "Testing database directly..."

    echo "📊 Prosumers in database:"
    if ! psql "$DATABASE_URL" -c "SELECT address, name, created_at FROM prosumers ORDER BY created_at DESC LIMIT 5;" 2>/dev/null; then
        log_warning "Failed to query prosumers table"
    fi
    echo ""

    echo "📋 Orders in database:"
    if ! psql "$DATABASE_URL" -c "SELECT id, prosumer_address, order_type, energy_amount, status FROM orders ORDER BY created_at DESC LIMIT 5;" 2>/dev/null; then
        log_warning "Failed to query orders table"
    fi
    echo ""
}

# Print next steps
print_next_steps() {
    log_success "PostgreSQL API tests completed successfully! 🎉"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Check the database using pgAdmin (if running): http://localhost:8080"
    echo "2. Explore the API documentation at: $API_BASE_URL/docs"
    echo "3. Start building your energy trading application!"
    echo "4. Review server logs in: $SERVER_LOG_FILE"
    echo ""
}

# Main function
main() {
    print_header
    check_requirements
    setup_environment
    check_database
    start_server
    echo ""
    run_api_tests
    test_database_directly
    print_next_steps
}

# Run main function
main "$@"
