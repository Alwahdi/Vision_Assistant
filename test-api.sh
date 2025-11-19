#!/bin/bash

# Simple API Gateway Test

echo "🔍 Testing API Gateway..."

cd services/api-gateway

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Start API Gateway
echo "🚀 Starting API Gateway..."
npm run dev &
API_PID=$!
echo "API Gateway started (PID: $API_PID)"

# Wait for startup
sleep 5

# Test health endpoint
echo "🏥 Testing health endpoint..."
if curl -f --max-time 5 http://localhost:3000/health >/dev/null 2>&1; then
    echo "✅ API Gateway is healthy!"
else
    echo "❌ API Gateway health check failed"
fi

# Wait for user input
echo "Press Enter to stop..."
read

# Stop API Gateway
echo "🛑 Stopping API Gateway..."
kill $API_PID 2>/dev/null || true

echo "✅ Done"
