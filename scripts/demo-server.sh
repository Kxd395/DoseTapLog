#!/bin/bash

echo "🚀 Starting DoseTrack Server Demo"
echo "=================================="
echo ""

cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/server

echo "Starting server in background..."
npm start > /tmp/dosetrack-server.log 2>&1 &
SERVER_PID=$!

echo "Server PID: $SERVER_PID"
echo "Waiting 3 seconds for startup..."
sleep 3

echo ""
echo "Testing endpoints..."
echo ""

# Test 1: Health check
echo "1️⃣  Health Check:"
curl -s http://localhost:3000/health | python3 -m json.tool || echo "Failed"

echo ""
echo ""

# Test 2: No auth
echo "2️⃣  API without auth (should fail with 401):"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/aggregates/7days)
if [ "$HTTP_CODE" = "401" ]; then
    echo "✅ Auth gate working - got 401 as expected"
else
    echo "❌ Expected 401, got $HTTP_CODE"
fi

echo ""

# Test 3: With auth
echo "3️⃣  API with auth key:"
curl -s -H "x-api-key: test-api-key-local-dev-only" \
     http://localhost:3000/api/aggregates/7days | python3 -m json.tool || echo "Response received"

echo ""
echo ""
echo "=================================="
echo "✅ Demo complete!"
echo ""
echo "Server is running on PID: $SERVER_PID"
echo "Server logs: /tmp/dosetrack-server.log"
echo ""
echo "To stop the server:"
echo "   kill $SERVER_PID"
echo ""
echo "Or to kill all node processes:"
echo "   pkill -f 'node index.js'"
echo ""
