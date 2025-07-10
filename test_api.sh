#!/bin/bash

#
# Energy Trading API Test Script
#
# This script runs comprehensive tests against the Energy Trading API
# to verify all endpoints are working correctly.
#
# Usage: ./test_api.sh
# Requirements: curl, running API server on localhost:3000
#

set -euo pipefail

# Configuration
readonly BASE_URL="http://localhost:3000"
readonly TIMEOUT=10

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
    echo -e "${YELLOW}🧪 Energy Trading API Test Suite${NC}"
    echo "====================================="
    echo "Base URL: $BASE_URL"
    echo "Timeout: ${TIMEOUT}s"
    echo ""
}

# Function to test an endpoint
test_endpoint() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local expected_status="$4"
    local description="${5:-$method $endpoint}"

    echo -n "Testing $description... "

    local response
    if [[ "$method" == "GET" ]]; then
        response=$(curl -s -w "%{http_code}" --max-time "$TIMEOUT" \
                   -X GET "$BASE_URL$endpoint" 2>/dev/null || echo "000")
    else
        response=$(curl -s -w "%{http_code}" --max-time "$TIMEOUT" \
                   -X "$method" "$BASE_URL$endpoint" \
                   -H "Content-Type: application/json" \
                   -d "$data" 2>/dev/null || echo "000")
    fi

    local status_code="${response: -3}"
    local response_body="${response%???}"

    if [[ "$status_code" == "$expected_status" ]]; then
        echo -e "${GREEN}✅ PASS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL (Status: $status_code)${NC}"
        if [[ -n "$response_body" ]]; then
            echo "  Response: $response_body"
        fi
        return 1
    fi
}

# Check if required tools are available
check_requirements() {
    local missing_tools=()

    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi
}

# Check if API server is running
check_server() {
    log_info "Checking if API server is running..."

    if ! curl -s --max-time "$TIMEOUT" "$BASE_URL/health" > /dev/null 2>&1; then
        log_error "API server is not running or not accessible!"
        log_error "Please start the server with: cargo run"
        log_error "Make sure it's running on $BASE_URL"
        exit 1
    fi

    log_success "API server is running and accessible!"
}

# Run all API tests
run_tests() {
    local failed_tests=0
    local total_tests=0

    log_info "Running API endpoint tests..."
    echo ""

    # Health check
    test_endpoint "GET" "/health" "" "200" "Health check" || ((failed_tests++))
    ((total_tests++))

    # Blockchain endpoints
    test_endpoint "GET" "/api/blockchain/info" "" "200" "Blockchain info" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "GET" "/api/blockchain/blocks" "" "200" "Blockchain blocks" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "GET" "/api/blockchain/transactions/pending" "" "200" "Pending transactions" || ((failed_tests++))
    ((total_tests++))

    # Token system endpoints
    test_endpoint "POST" "/api/tokens/accounts" '{"address": "test_user"}' "200" "Create token account" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "GET" "/api/tokens/balance/test_user" "" "200" "Get token balance" || ((failed_tests++))
    ((total_tests++))

    # Energy trading endpoints
    test_endpoint "POST" "/api/energy/prosumers" '{"address": "alice_test", "name": "Alice Test"}' "200" "Create prosumer" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "GET" "/api/energy/prosumers" "" "200" "Get all prosumers" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "GET" "/api/energy/prosumers/alice_test" "" "200" "Get specific prosumer" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "POST" "/api/energy/generation" '{"address": "alice_test", "amount": 50.0}' "200" "Record energy generation" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "POST" "/api/energy/consumption" '{"address": "alice_test", "amount": 25.0}' "200" "Record energy consumption" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "POST" "/api/energy/orders" '{"trader_address": "alice_test", "order_type": "sell", "energy_amount": 10.0, "price_per_kwh": 0.15}' "200" "Create sell order" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "GET" "/api/energy/orders/sell" "" "200" "Get sell orders" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "GET" "/api/energy/orders/buy" "" "200" "Get buy orders" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "GET" "/api/energy/trades" "" "200" "Get energy trades" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "GET" "/api/energy/statistics" "" "200" "Get energy statistics" || ((failed_tests++))
    ((total_tests++))

    # Governance endpoints
    test_endpoint "GET" "/api/governance/proposals" "" "200" "Get governance proposals" || ((failed_tests++))
    ((total_tests++))

    test_endpoint "POST" "/api/governance/proposals" '{"title": "Test Proposal", "description": "Test description", "proposer": "test_user", "voting_duration_hours": 24}' "200" "Create governance proposal" || ((failed_tests++))
    ((total_tests++))

    # Mining test
    test_endpoint "POST" "/api/blockchain/mine" '{"miner_address": "test_miner"}' "200" "Mine new block" || ((failed_tests++))
    ((total_tests++))

    # Print summary
    echo ""
    echo "========================================="
    echo "Test Summary:"
    echo "  Total tests: $total_tests"
    echo "  Passed: $((total_tests - failed_tests))"
    echo "  Failed: $failed_tests"
    echo "========================================="

    if [[ $failed_tests -eq 0 ]]; then
        log_success "All tests passed! 🎉"
        return 0
    else
        log_error "$failed_tests out of $total_tests tests failed!"
        return 1
    fi
}

# Main function
main() {
    print_header
    check_requirements
    check_server
    echo ""

    if run_tests; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
