#!/bin/bash
# Quick test script for WHOOP OAuth Proxy

echo "🔄 Starting WHOOP OAuth Proxy..."
cd "$(dirname "$0")"
node index.js > server.log 2>&1 &
SERVER_PID=$!

# Wait for server to start
sleep 2

echo "✅ Server running (PID: $SERVER_PID)"
echo ""
echo "📊 Testing /health endpoint..."
curl -s http://localhost:3000/health | jq '.' || curl -s http://localhost:3000/health
echo ""
echo ""
echo "🛑 Stopping server..."
kill $SERVER_PID 2>/dev/null

echo "✅ Test complete!"
