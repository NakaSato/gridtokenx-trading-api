#!/bin/bash

#
# Comprehensive Test Suite for Energy Trading API
#
# This script runs all available tests for the Energy Trading API including:
# - Unit tests
# - Integration tests
# - API endpoint tests
# - Database tests
# - Performance tests (basic)
#
# Usage: ./run_tests.sh [options]
# Options:
#   -h, --help          Show this help message
#   -u, --unit          Run unit tests only
#   -i, --integration   Run integration tests only
#   -a, --api           Run API tests only
#   -p, --performance   Run performance tests
#   -v, --verbose       Enable verbose output
#   --coverage          Generate code coverage report
#   --no-cleanup        Don't cleanup test artifacts
#

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$SCRIPT_DIR"
readonly API_BASE_URL="http://localhost:3000"
readonly TEST_TIMEOUT=60
readonly PERFORMANCE_DURATION=30
readonly PERFORMANCE_THREADS=4

# Test options
RUN_UNIT=true
RUN_INTEGRATION=true
RUN_API=true
RUN_PERFORMANCE=false
VERBOSE=false
GENERATE_COVERAGE=false
CLEANUP=true

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Server management
SERVER_PID=""
SERVER_LOG="test_server.log"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Print header
print_header() {
    echo -e "${BOLD}${BLUE}🧪 Energy Trading API Test Suite${NC}"
    echo "========================================="
    echo "Project: $(basename "$PROJECT_ROOT")"
    echo "Tests: $([ "$RUN_UNIT" == "true" ] && echo -n "Unit ")$([ "$RUN_INTEGRATION" == "true" ] && echo -n "Integration ")$([ "$RUN_API" == "true" ] && echo -n "API ")$([ "$RUN_PERFORMANCE" == "true" ] && echo -n "Performance ")"
    echo "Coverage: $GENERATE_COVERAGE"
    echo "Verbose: $VERBOSE"
    echo ""
}

# Show help message
show_help() {
    cat << EOF
Usage: $0 [options]

Comprehensive test suite for the Energy Trading API project.

Options:
  -h, --help          Show this help message
  -u, --unit          Run unit tests only
  -i, --integration   Run integration tests only
  -a, --api           Run API tests only
  -p, --performance   Run performance tests
  -v, --verbose       Enable verbose output
  --coverage          Generate code coverage report
  --no-cleanup        Don't cleanup test artifacts

Examples:
  $0                      # Run all tests except performance
  $0 --unit              # Run unit tests only
  $0 --api --verbose     # Run API tests with verbose output
  $0 --performance       # Run all tests including performance
  $0 --coverage          # Run tests with code coverage

EOF
}

# Parse command line arguments
parse_arguments() {
    # If any specific test type is requested, disable others by default
    local specific_test_requested=false
    
    for arg in "$@"; do
        case $arg in
            -u|--unit|-i|--integration|-a|--api)
                specific_test_requested=true
                break
                ;;
        esac
    done
    
    if [[ "$specific_test_requested" == "true" ]]; then
        RUN_UNIT=false
        RUN_INTEGRATION=false
        RUN_API=false
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--unit)
                RUN_UNIT=true
                shift
                ;;
            -i|--integration)
                RUN_INTEGRATION=true
                shift
                ;;
            -a|--api)
                RUN_API=true
                shift
                ;;
            -p|--performance)
                RUN_PERFORMANCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --coverage)
                GENERATE_COVERAGE=true
                shift
                ;;
            --no-cleanup)
                CLEANUP=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use '$0 --help' for usage information."
                exit 1
                ;;
        esac
    done
}

# Cleanup function
cleanup() {
    if [[ "$CLEANUP" == "true" ]]; then
        log_verbose "Running cleanup..."
        
        # Stop server if running
        if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
            log_verbose "Stopping test server..."
            kill "$SERVER_PID" 2>/dev/null || true
            wait "$SERVER_PID" 2>/dev/null || true
        fi
        
        # Clean up log files
        [[ -f "$SERVER_LOG" ]] && rm -f "$SERVER_LOG"
        [[ -f "test_results.xml" ]] && rm -f "test_results.xml"
        [[ -f "coverage.json" ]] && rm -f "coverage.json"
    fi
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Check prerequisites
check_prerequisites() {
    log_info "Checking test prerequisites..."
    
    local required_tools=("cargo" "curl")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check for optional tools
    if command -v jq &> /dev/null; then
        log_verbose "jq is available for JSON processing"
    else
        log_verbose "jq not available - JSON output will be raw"
    fi
    
    if [[ "$RUN_PERFORMANCE" == "true" ]] && ! command -v wrk &> /dev/null; then
        log_error "wrk is required for performance tests but not installed"
        log_info "Install with: brew install wrk (macOS) or apt install wrk (Ubuntu)"
        exit 1
    fi
    
    if [[ "$GENERATE_COVERAGE" == "true" ]] && ! command -v cargo-tarpaulin &> /dev/null; then
        log_error "cargo-tarpaulin is required for coverage but not installed"
        log_info "Install with: cargo install cargo-tarpaulin"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Run unit tests
run_unit_tests() {
    if [[ "$RUN_UNIT" != "true" ]]; then
        log_skip "Unit tests (not requested)"
        return 0
    fi
    
    log_info "Running unit tests..."
    
    local cargo_args=""
    if [[ "$VERBOSE" == "true" ]]; then
        cargo_args="--verbose"
    fi
    
    if [[ "$GENERATE_COVERAGE" == "true" ]]; then
        log_verbose "Running unit tests with coverage..."
        if cargo tarpaulin --out xml --output-dir . $cargo_args --skip-clean; then
            log_success "Unit tests with coverage passed"
        else
            log_error "Unit tests with coverage failed"
            return 1
        fi
    else
        log_verbose "Running cargo test..."
        if cargo test $cargo_args --lib; then
            log_success "Unit tests passed"
        else
            log_error "Unit tests failed"
            return 1
        fi
    fi
}

# Start test server
start_test_server() {
    log_info "Starting test server..."
    
    # Check if server is already running
    if curl -s --max-time 2 "$API_BASE_URL/health" > /dev/null 2>&1; then
        log_verbose "Server already running, using existing instance"
        return 0
    fi
    
    # Start server in background
    log_verbose "Starting new server instance..."
    cargo run > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    
    log_verbose "Server started with PID: $SERVER_PID"
    
    # Wait for server to be ready
    local retries=15
    local count=0
    
    while [[ $count -lt $retries ]]; do
        if curl -s --max-time 2 "$API_BASE_URL/health" > /dev/null 2>&1; then
            log_success "Test server is ready"
            return 0
        fi
        
        # Check if server process is still running
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            log_error "Server process died unexpectedly"
            log_error "Server logs:"
            cat "$SERVER_LOG"
            return 1
        fi
        
        ((count++))
        log_verbose "Waiting for server... (attempt $count/$retries)"
        sleep 2
    done
    
    log_error "Server failed to start within timeout"
    return 1
}

# Run integration tests
run_integration_tests() {
    if [[ "$RUN_INTEGRATION" != "true" ]]; then
        log_skip "Integration tests (not requested)"
        return 0
    fi
    
    log_info "Running integration tests..."
    
    # Start server for integration tests
    if ! start_test_server; then
        log_error "Failed to start server for integration tests"
        return 1
    fi
    
    local cargo_args=""
    if [[ "$VERBOSE" == "true" ]]; then
        cargo_args="--verbose"
    fi
    
    # Run integration tests
    log_verbose "Running cargo test for integration tests..."
    if cargo test $cargo_args --test '*' 2>/dev/null || cargo test $cargo_args; then
        log_success "Integration tests passed"
    else
        log_error "Integration tests failed"
        return 1
    fi
}

# API test helper function
api_test() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local expected_status="${4:-200}"
    local description="$5"
    
    log_verbose "Testing: $description"
    
    local response
    local status_code
    
    if [[ -n "$data" ]]; then
        response=$(curl -s -w "\n%{http_code}" --max-time "$TEST_TIMEOUT" \
                   -X "$method" "$API_BASE_URL$endpoint" \
                   -H "Content-Type: application/json" \
                   -d "$data" 2>/dev/null || echo -e "\n000")
    else
        response=$(curl -s -w "\n%{http_code}" --max-time "$TEST_TIMEOUT" \
                   -X "$method" "$API_BASE_URL$endpoint" 2>/dev/null || echo -e "\n000")
    fi
    
    status_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | head -n -1)
    
    if [[ "$status_code" == "$expected_status" ]]; then
        log_success "$description"
        return 0
    else
        log_error "$description (Expected: $expected_status, Got: $status_code)"
        if [[ "$VERBOSE" == "true" && -n "$response_body" ]]; then
            echo "Response: $response_body"
        fi
        return 1
    fi
}

# Run API tests
run_api_tests() {
    if [[ "$RUN_API" != "true" ]]; then
        log_skip "API tests (not requested)"
        return 0
    fi
    
    log_info "Running API tests..."
    
    # Start server for API tests
    if ! start_test_server; then
        log_error "Failed to start server for API tests"
        return 1
    fi
    
    # Basic API tests
    api_test "GET" "/health" "" "200" "Health endpoint"
    api_test "GET" "/api/energy/prosumers" "" "200" "Get prosumers"
    api_test "GET" "/api/energy/orders/buy" "" "200" "Get buy orders"
    api_test "GET" "/api/energy/orders/sell" "" "200" "Get sell orders"
    
    # Test creating a prosumer
    local prosumer_data='{"address": "test_user", "name": "Test User"}'
    api_test "POST" "/api/energy/prosumers" "$prosumer_data" "201" "Create prosumer"
    
    # Test creating orders
    local buy_order='{"trader_address": "test_user", "order_type": "buy", "energy_amount": 100.0, "price_per_kwh": 0.15}'
    api_test "POST" "/api/energy/orders" "$buy_order" "201" "Create buy order"
    
    local sell_order='{"trader_address": "test_user", "order_type": "sell", "energy_amount": 50.0, "price_per_kwh": 0.20}'
    api_test "POST" "/api/energy/orders" "$sell_order" "201" "Create sell order"
    
    # Test error conditions
    api_test "POST" "/api/energy/orders" '{"invalid": "data"}' "400" "Invalid order data"
    api_test "GET" "/api/nonexistent" "" "404" "Non-existent endpoint"
    
    log_success "API tests completed"
}

# Run performance tests
run_performance_tests() {
    if [[ "$RUN_PERFORMANCE" != "true" ]]; then
        log_skip "Performance tests (not requested)"
        return 0
    fi
    
    log_info "Running performance tests..."
    
    # Start server for performance tests
    if ! start_test_server; then
        log_error "Failed to start server for performance tests"
        return 1
    fi
    
    log_info "Running $PERFORMANCE_DURATION second load test with $PERFORMANCE_THREADS threads..."
    
    # Performance test with wrk
    if command -v wrk &> /dev/null; then
        log_verbose "Running wrk load test..."
        
        local wrk_output
        wrk_output=$(wrk -t"$PERFORMANCE_THREADS" -c"$PERFORMANCE_THREADS" -d"${PERFORMANCE_DURATION}s" \
                         --latency "$API_BASE_URL/health" 2>/dev/null || echo "wrk failed")
        
        if [[ "$wrk_output" != "wrk failed" ]]; then
            log_success "Performance test completed"
            
            if [[ "$VERBOSE" == "true" ]]; then
                echo "$wrk_output"
            else
                # Extract key metrics
                local rps
                rps=$(echo "$wrk_output" | grep "Requests/sec:" | awk '{print $2}')
                if [[ -n "$rps" ]]; then
                    log_info "Performance: $rps requests/sec"
                fi
            fi
        else
            log_error "Performance test failed"
            return 1
        fi
    else
        log_error "wrk not available for performance testing"
        return 1
    fi
}

# Print test summary
print_summary() {
    echo ""
    echo "=============================================="
    echo -e "${BOLD}🎯 Test Summary${NC}"
    echo "=============================================="
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "Tests skipped: $TESTS_SKIPPED"
    echo "Total tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}🎉 All tests PASSED!${NC}"
        if [[ "$GENERATE_COVERAGE" == "true" && -f "cobertura.xml" ]]; then
            echo ""
            echo "📊 Coverage report generated: cobertura.xml"
        fi
        echo ""
        echo "✨ Your Energy Trading API is working correctly!"
        return 0
    else
        echo -e "${RED}${BOLD}❌ Some tests FAILED${NC}"
        echo ""
        echo "Please fix the failing tests before deployment."
        return 1
    fi
}

# Main function
main() {
    print_header
    parse_arguments "$@"
    
    # Change to project directory
    cd "$PROJECT_ROOT"
    
    # Check prerequisites
    check_prerequisites
    
    # Run test suites
    run_unit_tests
    run_integration_tests
    run_api_tests
    run_performance_tests
    
    # Print summary and exit with appropriate code
    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
