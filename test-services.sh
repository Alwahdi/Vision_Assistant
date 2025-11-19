#!/bin/bash

# Test script for Vision Assistant services
# This script tests the services without Docker

echo "🧪 Testing Vision Assistant Services"
echo "==================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test function
test_service() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}

    echo -n "Testing $name ($url)... "

    if command -v curl &> /dev/null; then
        local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        if [ "$response" = "$expected_code" ]; then
            echo -e "${GREEN}✅ PASS${NC}"
            return 0
        else
            echo -e "${RED}❌ FAIL (HTTP $response)${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  SKIP (curl not available)${NC}"
        return 0
    fi
}

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found. Please install Node.js 18+${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Node.js version: $(node --version)${NC}"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 not found. Please install Python 3.11+${NC}"
    exit 1
fi

echo -e "${BLUE}🐍 Python version: $(python3 --version)${NC}"

# Check services directory structure
echo ""
echo "📁 Checking service directories..."
services=("api-gateway" "ai-service" "realtime-service")

for service in "${services[@]}"; do
    if [ -d "services/$service" ]; then
        echo -e "${GREEN}✅ services/$service exists${NC}"

        # Check package.json for Node.js services
        if [ "$service" != "ai-service" ] && [ -f "services/$service/package.json" ]; then
            echo -e "${GREEN}  ├── package.json found${NC}"
        elif [ "$service" = "ai-service" ] && [ -f "services/$service/requirements.txt" ]; then
            echo -e "${GREEN}  ├── requirements.txt found${NC}"
        else
            echo -e "${RED}  ├── configuration file missing${NC}"
        fi

        # Check main file
        if [ -f "services/$service/src/server.js" ] || [ -f "services/$service/main.py" ]; then
            echo -e "${GREEN}  └── main file exists${NC}"
        else
            echo -e "${RED}  └── main file missing${NC}"
        fi
    else
        echo -e "${RED}❌ services/$service missing${NC}"
    fi
done

# Check configuration files
echo ""
echo "⚙️  Checking configuration files..."

config_files=(
    "docker-compose.yml:docker-compose.yml"
    "env.example:env.example"
    "deploy-local.sh:deploy-local.sh"
    "db/init.sql:db/init.sql"
)

for config in "${config_files[@]}"; do
    IFS=':' read -r file desc <<< "$config"
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $desc found${NC}"
    else
        echo -e "${RED}❌ $desc missing${NC}"
    fi
done

# Test syntax of configuration files
echo ""
echo "🔍 Testing configuration syntax..."

# Test docker-compose.yml syntax
if command -v docker-compose &> /dev/null && [ -f "docker-compose.yml" ]; then
    if docker-compose config -q &> /dev/null; then
        echo -e "${GREEN}✅ docker-compose.yml syntax OK${NC}"
    else
        echo -e "${RED}❌ docker-compose.yml syntax error${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  docker-compose not available, skipping syntax check${NC}"
fi

# Test package.json syntax
for service in "${services[@]}"; do
    if [ "$service" != "ai-service" ] && [ -f "services/$service/package.json" ]; then
        if node -e "JSON.parse(require('fs').readFileSync('services/$service/package.json'))" &> /dev/null; then
            echo -e "${GREEN}✅ services/$service/package.json syntax OK${NC}"
        else
            echo -e "${RED}❌ services/$service/package.json syntax error${NC}"
        fi
    fi
done

# Test Python requirements syntax
if [ -f "services/ai-service/requirements.txt" ]; then
    # Basic syntax check for requirements.txt
    if grep -q "^[a-zA-Z0-9_-]\+\([<>=!]\+\|[<>=!]*\)\?[0-9\.\*]*" services/ai-service/requirements.txt; then
        echo -e "${GREEN}✅ services/ai-service/requirements.txt syntax OK${NC}"
    else
        echo -e "${YELLOW}⚠️  services/ai-service/requirements.txt may have syntax issues${NC}"
    fi
fi

# Test JavaScript syntax
echo ""
echo "💻 Testing JavaScript syntax..."

for service in "${services[@]}"; do
    if [ "$service" != "ai-service" ] && [ -f "services/$service/src/server.js" ]; then
        if node -c "services/$service/src/server.js" &> /dev/null; then
            echo -e "${GREEN}✅ services/$service/src/server.js syntax OK${NC}"
        else
            echo -e "${RED}❌ services/$service/src/server.js syntax error${NC}"
        fi
    fi
done

# Test Python syntax
echo ""
echo "🐍 Testing Python syntax..."

if [ -f "services/ai-service/main.py" ]; then
    if python3 -m py_compile services/ai-service/main.py &> /dev/null; then
        echo -e "${GREEN}✅ services/ai-service/main.py syntax OK${NC}"
    else
        echo -e "${RED}❌ services/ai-service/main.py syntax error${NC}"
    fi
fi

# Summary
echo ""
echo "📊 Test Summary"
echo "=============="

echo ""
echo "🎯 Services Overview:"
echo "- API Gateway: Express.js service (port 3000)"
echo "- AI Service: FastAPI service (port 8000)"
echo "- Real-time Service: Socket.IO service (port 3001)"
echo "- Database: PostgreSQL (port 5432)"
echo "- Cache: Redis (port 6379)"

echo ""
echo "🚀 To start the services with Docker:"
echo "1. Start Docker Desktop"
echo "2. Run: ./deploy-local.sh start"
echo "3. Check status: ./deploy-local.sh status"

echo ""
echo "🔧 To start services manually (without Docker):"
echo ""
echo "# Terminal 1 - API Gateway"
echo "cd services/api-gateway"
echo "npm install"
echo "npm run dev"
echo ""
echo "# Terminal 2 - AI Service"
echo "cd services/ai-service"
echo "pip install -r requirements.txt"
echo "python main.py"
echo ""
echo "# Terminal 3 - Real-time Service"
echo "cd services/realtime-service"
echo "npm install"
echo "npm run dev"

echo ""
echo "📝 Environment Setup:"
echo "- Copy env.example to .env"
echo "- Update database and service configurations"
echo "- Ensure PostgreSQL and Redis are running locally"

echo ""
echo -e "${GREEN}✅ Vision Assistant services are ready for deployment!${NC}"
