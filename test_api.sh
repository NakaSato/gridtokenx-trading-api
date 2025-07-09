#!/bin/bash

# Energy Trading API Test Script

BASE_URL="http://localhost:3000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧪 Energy Trading API Test Suite${NC}"
echo "====================================="

# Function to test an endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_status=$4
    
    echo -n "Testing $method $endpoint... "
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "%{http_code}" -X GET "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "%{http_code}" -X POST "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    status_code="${response: -3}"
    response_body="${response%???}"
    
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ PASS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL (Status: $status_code)${NC}"
        echo "Response: $response_body"
        return 1
    fi
}

# Check if API server is running
echo "Checking if API server is running..."
if ! curl -s "$BASE_URL/health" > /dev/null; then
    echo -e "${RED}❌ API server is not running!${NC}"
    echo "Please start the server with: cargo run"
    exit 1
fi

echo -e "${GREEN}✅ API server is running!${NC}"
echo

# Run tests
echo "Running API tests..."
echo

# Health check
test_endpoint "GET" "/health" "" "200"

# Blockchain endpoints
test_endpoint "GET" "/api/blockchain/info" "" "200"
test_endpoint "GET" "/api/blockchain/blocks" "" "200"
test_endpoint "GET" "/api/blockchain/transactions/pending" "" "200"

# Token system endpoints
test_endpoint "POST" "/api/tokens/accounts" '{"address": "test_user"}' "200"
test_endpoint "GET" "/api/tokens/balance/test_user" "" "200"

# Energy trading endpoints
test_endpoint "POST" "/api/energy/prosumers" '{"address": "alice_test", "name": "Alice Test"}' "200"
test_endpoint "GET" "/api/energy/prosumers" "" "200"
test_endpoint "GET" "/api/energy/prosumers/alice_test" "" "200"

test_endpoint "POST" "/api/energy/generation" '{"address": "alice_test", "amount": 50.0}' "200"
test_endpoint "POST" "/api/energy/consumption" '{"address": "alice_test", "amount": 25.0}' "200"

test_endpoint "POST" "/api/energy/orders" '{"trader_address": "alice_test", "order_type": "sell", "energy_amount": 10.0, "price_per_kwh": 0.15}' "200"
test_endpoint "GET" "/api/energy/orders/sell" "" "200"
test_endpoint "GET" "/api/energy/orders/buy" "" "200"
test_endpoint "GET" "/api/energy/trades" "" "200"
test_endpoint "GET" "/api/energy/statistics" "" "200"

# Governance endpoints
test_endpoint "GET" "/api/governance/proposals" "" "200"
test_endpoint "POST" "/api/governance/proposals" '{"title": "Test Proposal", "description": "Test description", "proposer": "test_user", "voting_duration_hours": 24}' "200"

# Mining test
test_endpoint "POST" "/api/blockchain/mine" '{"miner_address": "test_miner"}' "200"

echo
echo -e "${GREEN}✅ All tests completed!${NC}"
echo "Check the output above for any failed tests."
