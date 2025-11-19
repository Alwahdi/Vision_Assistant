#!/bin/bash

# Simple Vision Assistant Starter

echo "🚀 Starting Vision Assistant Services..."

# Start API Gateway
echo "Starting API Gateway..."
cd services/api-gateway
npm install
npm run dev &
API_PID=$!
echo "API Gateway started (PID: $API_PID)"

# Wait a bit
sleep 3

# Test API Gateway
if curl -f http://localhost:3000/health >/dev/null 2>&1; then
    echo "✅ API Gateway is running on http://localhost:3000"
else
    echo "❌ API Gateway failed to start"
fi

# Wait for user input to stop
echo "Press Ctrl+C to stop..."
trap "kill $API_PID 2>/dev/null; exit" INT
wait
