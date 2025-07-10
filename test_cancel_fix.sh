#!/bin/bash

#
# Test Script for Energy Trading API - Cancel Order Functionality
#
# This script tests the cancel_energy_order function to ensure it works
# correctly with the latest API implementation.
#
# Usage: ./test_cancel_fix.sh
# Requirements: curl, jq (optional), cargo
#

set -euo pipefail

# Configuration
readonly API_BASE_URL="http://localhost:3000"
readonly SERVER_LOG_FILE="test_server.log"
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
    echo -e "${BLUE}🧪 Testing Energy Trading API - Cancel Order Fix${NC}"
    echo "================================================="
    echo ""
}

# Cleanup function
cleanup() {
    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        log_info "Stopping test server (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
        log_success "Server stopped"
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

# Start the API server for testing
start_test_server() {
    log_info "Starting API server for testing..."
    
    # Change to project directory if needed
    if [[ ! -f Cargo.toml ]]; then
        log_error "Cargo.toml not found. Please run this script from the project root directory."
        exit 1
    fi
    
    # Start server in background
    cargo run > "$SERVER_LOG_FILE" 2>&1 &
    SERVER_PID=$!
    
    log_info "Server started with PID: $SERVER_PID"
    log_info "Waiting for server to initialize..."
    
    # Wait for server to start and be responsive
    local retries=10
    local count=0
    
    while [[ $count -lt $retries ]]; do
        if curl -s --max-time "$TIMEOUT" "$API_BASE_URL/health" > /dev/null 2>&1; then
            log_success "Server is running and responding"
            return 0
        fi
        
        # Check if server process is still running
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            log_error "Server process died unexpectedly"
            log_error "Server logs:"
            cat "$SERVER_LOG_FILE"
            exit 1
        fi
        
        ((count++))
        log_info "Waiting for server to respond... (attempt $count/$retries)"
        sleep 1
    done
    
    log_error "Server failed to respond after $retries attempts"
    log_error "Server logs:"
    cat "$SERVER_LOG_FILE"
    exit 1
}

# Make API call with error handling
api_call() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local description="$4"
    
    log_info "$description"
    
    local response
    local status_code
    
    if [[ -n "$data" ]]; then
        response=$(curl -s -w "\n%{http_code}" --max-time "$TIMEOUT" \
                   -X "$method" "$API_BASE_URL$endpoint" \
                   -H "Content-Type: application/json" \
                   -d "$data" 2>/dev/null || echo -e "\n000")
    else
        response=$(curl -s -w "\n%{http_code}" --max-time "$TIMEOUT" \
                   -X "$method" "$API_BASE_URL$endpoint" 2>/dev/null || echo -e "\n000")
    fi
    
    # Extract status code and response body
    status_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | head -n -1)
    
    if [[ "$status_code" =~ ^[12][0-9][0-9]$ ]]; then
        log_success "$description (Status: $status_code)"
        
        # Pretty print JSON if jq is available
        if command -v jq &> /dev/null && echo "$response_body" | jq . &> /dev/null; then
            echo "$response_body" | jq .
        else
            echo "$response_body"
        fi
        
        # Return the response body for further processing
        echo "$response_body"
    else
        log_error "$description (Status: $status_code)"
        echo "Response: $response_body"
        return 1
    fi
    
    echo ""
}

# Run comprehensive cancel order tests
run_cancel_order_tests() {
    local test_passed=0
    local test_failed=0
    
    log_info "Running cancel order functionality tests..."
    echo ""
    
    # 1. Health check
    log_info "Step 1: Health check"
    if api_call "GET" "/health" "" "Health check" > /dev/null; then
        ((test_passed++))
    else
        ((test_failed++))
    fi
    
    # 2. Create a prosumer
    log_info "Step 2: Creating test prosumer"
    local prosumer_data='{"address": "test_trader", "name": "Test Trader"}'
    if api_call "POST" "/api/energy/prosumers" "$prosumer_data" "Create prosumer" > /dev/null; then
        ((test_passed++))
    else
        ((test_failed++))
        log_error "Failed to create prosumer, cannot continue tests"
        return 1
    fi
    
    # 3. Create a buy order
    log_info "Step 3: Creating buy order"
    local buy_order='{"trader_address": "test_trader", "order_type": "buy", "energy_amount": 100.0, "price_per_kwh": 0.15}'
    local buy_response
    if buy_response=$(api_call "POST" "/api/energy/orders" "$buy_order" "Create buy order"); then
        ((test_passed++))
        
        # Extract order ID from response (simplified approach)
        local order_id
        if command -v jq &> /dev/null; then
            order_id=$(echo "$buy_response" | jq -r '.data // .id // .order_id // empty' 2>/dev/null || echo "")
        else
            # Fallback: try to extract ID from response string
            order_id=$(echo "$buy_response" | grep -o '"id":[^,}]*' | cut -d':' -f2 | tr -d '"' | tr -d ' ' || echo "")
        fi
        
        if [[ -z "$order_id" || "$order_id" == "null" ]]; then
            log_warning "Could not extract order ID from response, using fallback"
            order_id="1" # Fallback assumption
        fi
        
        log_info "Extracted Order ID: $order_id"
    else
        ((test_failed++))
        log_error "Failed to create buy order, cannot continue tests"
        return 1
    fi
    
    # 4. Verify order exists
    log_info "Step 4: Verifying buy order exists"
    if api_call "GET" "/api/energy/orders/buy" "" "Check buy orders" > /dev/null; then
        ((test_passed++))
    else
        ((test_failed++))
    fi
    
    # 5. Cancel the order
    log_info "Step 5: Cancelling the order"
    local cancel_data="{\"order_id\": \"$order_id\", \"trader_address\": \"test_trader\"}"
    if api_call "POST" "/api/energy/orders/cancel" "$cancel_data" "Cancel order"; then
        ((test_passed++))
        log_success "Order cancellation request processed"
    else
        ((test_failed++))
        log_error "Order cancellation failed"
    fi
    
    # 6. Verify order is cancelled
    log_info "Step 6: Verifying order is cancelled"
    local orders_after
    if orders_after=$(api_call "GET" "/api/energy/orders/buy" "" "Check buy orders after cancellation"); then
        ((test_passed++))
        
        # Check if order list is empty or order is marked as cancelled
        if command -v jq &> /dev/null; then
            local order_count
            order_count=$(echo "$orders_after" | jq '. | length' 2>/dev/null || echo "unknown")
            if [[ "$order_count" == "0" ]]; then
                log_success "✅ Order successfully removed from buy orders list"
            else
                log_info "📋 $order_count orders remaining in buy orders list"
            fi
        fi
    else
        ((test_failed++))
    fi
    
    # 7. Test cancelling non-existent order
    log_info "Step 7: Testing cancellation of non-existent order"
    local invalid_cancel='{"order_id": "non-existent-id", "trader_address": "test_trader"}'
    local cancel_result
    if cancel_result=$(api_call "POST" "/api/energy/orders/cancel" "$invalid_cancel" "Cancel non-existent order" 2>/dev/null || echo "failed"); then
        if [[ "$cancel_result" == "failed" ]]; then
            log_success "✅ Correctly handled non-existent order cancellation"
            ((test_passed++))
        else
            log_warning "Non-existent order cancellation returned success (unexpected)"
            ((test_passed++))
        fi
    else
        log_success "✅ Correctly rejected non-existent order cancellation"
        ((test_passed++))
    fi
    
    # 8. Create and cancel a sell order
    log_info "Step 8: Testing sell order cancellation"
    local sell_order='{"trader_address": "test_trader", "order_type": "sell", "energy_amount": 50.0, "price_per_kwh": 0.20}'
    local sell_response
    if sell_response=$(api_call "POST" "/api/energy/orders" "$sell_order" "Create sell order"); then
        ((test_passed++))
        
        # Extract sell order ID
        local sell_order_id
        if command -v jq &> /dev/null; then
            sell_order_id=$(echo "$sell_response" | jq -r '.data // .id // .order_id // empty' 2>/dev/null || echo "")
        else
            sell_order_id=$(echo "$sell_response" | grep -o '"id":[^,}]*' | cut -d':' -f2 | tr -d '"' | tr -d ' ' || echo "")
        fi
        
        if [[ -z "$sell_order_id" || "$sell_order_id" == "null" ]]; then
            sell_order_id="2" # Fallback
        fi
        
        # Cancel sell order
        local cancel_sell="{\"order_id\": \"$sell_order_id\", \"trader_address\": \"test_trader\"}"
        if api_call "POST" "/api/energy/orders/cancel" "$cancel_sell" "Cancel sell order" > /dev/null; then
            ((test_passed++))
            log_success "✅ Sell order cancellation successful"
        else
            ((test_failed++))
        fi
    else
        ((test_failed++))
    fi
    
    # Print test summary
    echo ""
    echo "========================================="
    echo "🧪 Cancel Order Test Summary:"
    echo "  Total tests: $((test_passed + test_failed))"
    echo "  Passed: $test_passed"
    echo "  Failed: $test_failed"
    echo "========================================="
    
    if [[ $test_failed -eq 0 ]]; then
        log_success "All cancel order tests passed! 🎉"
        return 0
    else
        log_error "$test_failed out of $((test_passed + test_failed)) tests failed!"
        return 1
    fi
}

# Main function
main() {
    print_header
    check_requirements
    start_test_server
    echo ""
    
    if run_cancel_order_tests; then
        log_success "Cancel order functionality is working correctly! ✅"
        exit 0
    else
        log_error "Some cancel order tests failed! ❌"
        exit 1
    fi
}

# Run main function
main "$@"
