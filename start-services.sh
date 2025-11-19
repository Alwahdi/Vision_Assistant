#!/bin/bash

# Vision Assistant - Start Services Locally
# This script starts all services without Docker for testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"

    local missing_tools=()

    # Check required tools
    local tools=("node" "python3" "npm" "pip3")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi

    log_success "All prerequisites met"
}

# Setup environment
setup_environment() {
    log_info "Setting up environment..."

    # Copy environment file if .env doesn't exist
    if [ ! -f ".env" ] && [ -f "environment.local" ]; then
        cp environment.local .env
        log_success "Created .env file from environment.local"
    fi

    # Create logs directory
    mkdir -p logs

    # Create uploads directory
    mkdir -p uploads

    log_success "Environment setup complete"
}

# Install dependencies for a service
install_dependencies() {
    local service_name=$1
    local service_path=$2

    log_info "Installing dependencies for $service_name..."

    cd "$service_path"

    if [ -f "package.json" ]; then
        # Node.js service
        if [ ! -d "node_modules" ]; then
            npm install
            log_success "Installed Node.js dependencies for $service_name"
        else
            log_info "Node.js dependencies already installed for $service_name"
        fi
    elif [ -f "requirements.txt" ]; then
        # Python service
        if [ ! -d "venv" ]; then
            python3 -m venv venv
            source venv/bin/activate
            pip install -r requirements.txt
            log_success "Installed Python dependencies for $service_name"
        else
            log_info "Python dependencies already installed for $service_name"
        fi
    else
        log_warning "No dependency file found for $service_name"
    fi

    cd "$SCRIPT_DIR"
}

# Start API Gateway
start_api_gateway() {
    log_info "Starting API Gateway..."

    install_dependencies "API Gateway" "services/api-gateway"

    cd services/api-gateway

    # Start in background
    nohup npm run dev > ../../logs/api-gateway.log 2>&1 &
    echo $! > ../../logs/api-gateway.pid

    cd "$SCRIPT_DIR"

    # Wait a bit and check if it's running
    sleep 3
    if kill -0 $(cat logs/api-gateway.pid) 2>/dev/null; then
        log_success "API Gateway started (PID: $(cat logs/api-gateway.pid))"
    else
        log_error "API Gateway failed to start"
        cat logs/api-gateway.log
        return 1
    fi
}

# Start AI Service
start_ai_service() {
    log_info "Starting AI Service..."

    install_dependencies "AI Service" "services/ai-service"

    cd services/ai-service

    # Start in background
    nohup python main.py > ../../logs/ai-service.log 2>&1 &
    echo $! > ../../logs/ai-service.pid

    cd "$SCRIPT_DIR"

    # Wait a bit and check if it's running
    sleep 5
    if kill -0 $(cat logs/ai-service.pid) 2>/dev/null; then
        log_success "AI Service started (PID: $(cat logs/ai-service.pid))"
    else
        log_error "AI Service failed to start"
        cat logs/ai-service.log
        return 1
    fi
}

# Start Real-time Service
start_realtime_service() {
    log_info "Starting Real-time Service..."

    install_dependencies "Real-time Service" "services/realtime-service"

    cd services/realtime-service

    # Start in background
    nohup npm run dev > ../../logs/realtime-service.log 2>&1 &
    echo $! > ../../logs/realtime-service.pid

    cd "$SCRIPT_DIR"

    # Wait a bit and check if it's running
    sleep 3
    if kill -0 $(cat logs/realtime-service.pid) 2>/dev/null; then
        log_success "Real-time Service started (PID: $(cat logs/realtime-service.pid))"
    else
        log_error "Real-time Service failed to start"
        cat logs/realtime-service.log
        return 1
    fi
}

# Test services
test_services() {
    log_header "Testing Services"

    local failed_tests=0

    # Test API Gateway
    if curl -f --max-time 5 http://localhost:3000/health &> /dev/null; then
        log_success "API Gateway health check passed"
    else
        log_error "API Gateway health check failed"
        ((failed_tests++))
    fi

    # Test AI Service
    if curl -f --max-time 5 http://localhost:8000/health &> /dev/null; then
        log_success "AI Service health check passed"
    else
        log_error "AI Service health check failed"
        ((failed_tests++))
    fi

    # Test Real-time Service
    if curl -f --max-time 5 http://localhost:3001/health &> /dev/null; then
        log_success "Real-time Service health check passed"
    else
        log_error "Real-time Service health check failed"
        ((failed_tests++))
    fi

    if [ $failed_tests -eq 0 ]; then
        log_success "All services are healthy!"
    else
        log_warning "$failed_tests service(s) failed health checks"
    fi

    return $failed_tests
}

# Show status
show_status() {
    log_header "Service Status"

    echo ""
    echo "Process Status:"
    echo "==============="

    # API Gateway
    if [ -f "logs/api-gateway.pid" ] && kill -0 $(cat logs/api-gateway.pid) 2>/dev/null; then
        echo -e "✅ API Gateway (PID: $(cat logs/api-gateway.pid))"
    else
        echo -e "❌ API Gateway (not running)"
    fi

    # AI Service
    if [ -f "logs/ai-service.pid" ] && kill -0 $(cat logs/ai-service.pid) 2>/dev/null; then
        echo -e "✅ AI Service (PID: $(cat logs/ai-service.pid))"
    else
        echo -e "❌ AI Service (not running)"
    fi

    # Real-time Service
    if [ -f "logs/realtime-service.pid" ] && kill -0 $(cat logs/realtime-service.pid) 2>/dev/null; then
        echo -e "✅ Real-time Service (PID: $(cat logs/realtime-service.pid))"
    else
        echo -e "❌ Real-time Service (not running)"
    fi

    echo ""
    echo "Service URLs:"
    echo "============="
    echo "📱 API Gateway: http://localhost:3000"
    echo "🤖 AI Service: http://localhost:8000"
    echo "⚡ Real-time Service: http://localhost:3001"

    echo ""
    echo "Health Checks:"
    echo "=============="

    # Test each service
    test_services > /dev/null 2>&1
}

# Stop services
stop_services() {
    log_header "Stopping Services"

    # Stop API Gateway
    if [ -f "logs/api-gateway.pid" ] && kill -0 $(cat logs/api-gateway.pid) 2>/dev/null; then
        kill $(cat logs/api-gateway.pid)
        log_success "API Gateway stopped"
    fi

    # Stop AI Service
    if [ -f "logs/ai-service.pid" ] && kill -0 $(cat logs/ai-service.pid) 2>/dev/null; then
        kill $(cat logs/ai-service.pid)
        log_success "AI Service stopped"
    fi

    # Stop Real-time Service
    if [ -f "logs/realtime-service.pid" ] && kill -0 $(cat logs/realtime-service.pid) 2>/dev/null; then
        kill $(cat logs/realtime-service.pid)
        log_success "Real-time Service stopped"
    fi

    # Clean up PID files
    rm -f logs/*.pid

    log_success "All services stopped"
}

# Clean up
cleanup() {
    log_info "Cleaning up..."

    # Stop services
    stop_services

    # Remove logs
    rm -rf logs/*.log logs/*.pid

    # Remove node_modules (optional)
    # rm -rf services/*/node_modules

    log_success "Cleanup complete"
}

# Main function
main() {
    case "${1:-start}" in
        start)
            check_prerequisites
            setup_environment
            start_api_gateway
            start_ai_service
            start_realtime_service
            sleep 2
            test_services
            show_status
            ;;
        stop)
            stop_services
            ;;
        restart)
            stop_services
            sleep 1
            main start
            ;;
        status)
            show_status
            ;;
        test)
            test_services
            ;;
        clean)
            cleanup
            ;;
        logs)
            if [ -n "${2:-}" ]; then
                tail -f "logs/${2}.log"
            else
                echo "Usage: $0 logs <service-name>"
                echo "Service names: api-gateway, ai-service, realtime-service"
            fi
            ;;
        *)
            echo "Usage: $0 [start|stop|restart|status|test|clean|logs]"
            echo ""
            echo "Commands:"
            echo "  start   - Start all services"
            echo "  stop    - Stop all services"
            echo "  restart - Restart all services"
            echo "  status  - Show service status"
            echo "  test    - Test service health"
            echo "  clean   - Clean up logs and processes"
            echo "  logs    - Show service logs (requires service name)"
            exit 1
            ;;
    esac
}

# Trap for cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
