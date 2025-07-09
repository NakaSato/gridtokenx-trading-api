#!/bin/bash

# Test script for the fixed cancel_energy_order function
set -e

echo "Testing Energy Trading API - Cancel Order Fix"
echo "============================================="

# Start the server in the background
echo "Starting API server..."
cd "/Users/chanthawat/Development/untitled folder/energy-trading-api"
cargo run &
SERVER_PID=$!

# Wait for server to start
sleep 3

# Test the API endpoints
echo "Testing API endpoints..."

# 1. Health check
echo "1. Health check..."
curl -s http://localhost:3000/health | jq .

# 2. Create a prosumer
echo "2. Creating prosumer..."
curl -s -X POST http://localhost:3000/api/energy/prosumers \
  -H "Content-Type: application/json" \
  -d '{"address": "test_trader", "name": "Test Trader"}' | jq .

# 3. Create a buy order
echo "3. Creating buy order..."
BUY_ORDER_RESPONSE=$(curl -s -X POST http://localhost:3000/api/energy/orders \
  -H "Content-Type: application/json" \
  -d '{"trader_address": "test_trader", "order_type": "buy", "energy_amount": 100.0, "price_per_kwh": 0.15}')

echo $BUY_ORDER_RESPONSE | jq .

# Extract order ID from response (this is a simplified approach)
ORDER_ID=$(echo $BUY_ORDER_RESPONSE | jq -r '.data' | sed 's/Order placed with ID: //')
echo "Order ID: $ORDER_ID"

# 4. Check buy orders
echo "4. Checking buy orders..."
curl -s http://localhost:3000/api/energy/orders/buy | jq .

# 5. Cancel the order
echo "5. Cancelling the order..."
curl -s -X POST http://localhost:3000/api/energy/orders/cancel \
  -H "Content-Type: application/json" \
  -d "{\"order_id\": \"$ORDER_ID\", \"trader_address\": \"test_trader\"}" | jq .

# 6. Check buy orders again (should be empty)
echo "6. Checking buy orders after cancellation..."
curl -s http://localhost:3000/api/energy/orders/buy | jq .

# 7. Try to cancel non-existent order
echo "7. Testing cancellation of non-existent order..."
curl -s -X POST http://localhost:3000/api/energy/orders/cancel \
  -H "Content-Type: application/json" \
  -d '{"order_id": "non-existent-id", "trader_address": "test_trader"}' | jq .

# Clean up
echo "Cleaning up..."
kill $SERVER_PID

echo "Test completed successfully!"
