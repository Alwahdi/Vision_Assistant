#!/bin/bash

# Vision Assistant - Direct Service Runner
# Run services directly without Docker for testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_header() {
    echo -e "${PURPLE}================================${NC}" >&2
    echo -e "${PURPLE}$1${NC}" >&2
    echo -e "${PURPLE}================================${NC}" >&2
}

# Function to run API Gateway
run_api_gateway() {
    log_info "Starting API Gateway on port 3000..."
    cd "$PROJECT_ROOT/services/api-gateway"

    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        log_warning "node_modules not found. Installing dependencies..."
        npm install || {
            log_error "Failed to install dependencies for API Gateway"
            return 1
        }
    fi

    # Start the service
    npm run dev &
    API_GATEWAY_PID=$!
    echo $API_GATEWAY_PID > "$PROJECT_ROOT/.api_gateway_pid"

    log_success "API Gateway started (PID: $API_GATEWAY_PID)"
}

# Function to run AI Service
run_ai_service() {
    log_info "Starting AI Service on port 8000..."
    cd "$PROJECT_ROOT/services/ai-service"

    # Check if virtual environment exists
    if [ ! -d "venv" ]; then
        log_warning "Python virtual environment not found. Creating..."
        python3 -m venv venv || {
            log_error "Failed to create virtual environment"
            return 1
        }
        source venv/bin/activate
        pip install -r requirements.txt || {
            log_error "Failed to install Python dependencies"
            return 1
        }
    else
        source venv/bin/activate
    fi

    # Start the service
    python main.py &
    AI_SERVICE_PID=$!
    echo $AI_SERVICE_PID > "$PROJECT_ROOT/.ai_service_pid"

    log_success "AI Service started (PID: $AI_SERVICE_PID)"
}

# Function to run Realtime Service
run_realtime_service() {
    log_info "Starting Realtime Service on port 3001..."
    cd "$PROJECT_ROOT/services/realtime-service"

    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        log_warning "node_modules not found. Installing dependencies..."
        npm install || {
            log_error "Failed to install dependencies for Realtime Service"
            return 1
        }
    fi

    # Start the service
    npm run dev &
    REALTIME_SERVICE_PID=$!
    echo $REALTIME_SERVICE_PID > "$PROJECT_ROOT/.realtime_service_pid"

    log_success "Realtime Service started (PID: $REALTIME_SERVICE_PID)"
}

# Function to test services
test_services() {
    log_header "Testing Services"

    # Wait a bit for services to start
    sleep 5

    # Test API Gateway
    if curl -f --max-time 5 http://localhost:3000/health >/dev/null 2>&1; then
        log_success "API Gateway is responding"
    else
        log_warning "API Gateway not responding yet"
    fi

    # Test AI Service
    if curl -f --max-time 5 http://localhost:8000/health >/dev/null 2>&1; then
        log_success "AI Service is responding"
    else
        log_warning "AI Service not responding yet"
    fi

    # Test Realtime Service
    if curl -f --max-time 5 http://localhost:3001/health >/dev/null 2>&1; then
        log_success "Realtime Service is responding"
    else
        log_warning "Realtime Service not responding yet"
    fi
}

# Function to stop services
stop_services() {
    log_info "Stopping all services..."

    # Stop API Gateway
    if [ -f "$PROJECT_ROOT/.api_gateway_pid" ]; then
        kill "$(cat "$PROJECT_ROOT/.api_gateway_pid")" 2>/dev/null || true
        rm -f "$PROJECT_ROOT/.api_gateway_pid"
        log_success "API Gateway stopped"
    fi

    # Stop AI Service
    if [ -f "$PROJECT_ROOT/.ai_service_pid" ]; then
        kill "$(cat "$PROJECT_ROOT/.ai_service_pid")" 2>/dev/null || true
        rm -f "$PROJECT_ROOT/.ai_service_pid"
        log_success "AI Service stopped"
    fi

    # Stop Realtime Service
    if [ -f "$PROJECT_ROOT/.realtime_service_pid" ]; then
        kill "$(cat "$PROJECT_ROOT/.realtime_service_pid")" 2>/dev/null || true
        rm -f "$PROJECT_ROOT/.realtime_service_pid"
        log_success "Realtime Service stopped"
    fi
}

# Cleanup function
cleanup() {
    stop_services
    exit 0
}

# Set trap for cleanup
trap cleanup SIGINT SIGTERM

# Main function
main() {
    log_header "Vision Assistant - Direct Service Runner"

    case "${1:-start}" in
        "start")
            log_info "Starting Vision Assistant services..."

            # Start services
            run_api_gateway || log_error "Failed to start API Gateway"
            run_ai_service || log_error "Failed to start AI Service"
            run_realtime_service || log_error "Failed to start Realtime Service"

            # Test services
            test_services

            log_header "Services Started Successfully!"
            echo ""
            echo "🌐 Service URLs:"
            echo "==============="
            echo "API Gateway:    http://localhost:3000"
            echo "AI Service:     http://localhost:8000"
            echo "Realtime:       http://localhost:3001"
            echo ""
            echo "🩺 Health Checks:"
            echo "================="
            echo "API Gateway:    http://localhost:3000/health"
            echo "AI Service:     http://localhost:8000/health"
            echo "Realtime:       http://localhost:3001/health"
            echo ""
            echo "🛠️  Press Ctrl+C to stop all services"
            echo ""

            # Wait for services
            wait
            ;;
        "stop")
            stop_services
            ;;
        "test")
            test_services
            ;;
        "restart")
            stop_services
            sleep 2
            main start
            ;;
        *)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  start     Start all services (default)"
            echo "  stop      Stop all services"
            echo "  test      Test all services"
            echo "  restart   Restart all services"
            echo ""
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
