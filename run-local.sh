#!/bin/bash

# Vision Assistant - Local Development Runner (No Docker)
# Run services directly on the host machine for development

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
    echo -e "${PURPLE}================================${0m" >&2
    echo -e "${PURPLE}$1${NC}" >&2
    echo -e "${PURPLE}================================${NC}" >&2
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"

    local missing_tools=()

    # Check Node.js
    if ! command -v node &> /dev/null; then
        missing_tools+=("node")
    else
        local node_version=$(node --version | sed 's/v//')
        if [[ "$(printf '%s\n' "$node_version" "18.0.0" | sort -V | head -n1)" != "18.0.0" ]]; then
            log_warning "Node.js version $node_version detected. Recommended: 18+"
        else
            log_success "Node.js $node_version"
        fi
    fi

    # Check npm
    if ! command -v npm &> /dev/null; then
        missing_tools+=("npm")
    else
        log_success "npm available"
    fi

    # Check Python
    if ! command -v python3 &> /dev/null; then
        missing_tools+=("python3")
    else
        local python_version=$(python3 --version | sed 's/Python //')
        if [[ "$(printf '%s\n' "$python_version" "3.11.0" | sort -V | head -n1)" != "3.11.0" ]]; then
            log_warning "Python version $python_version detected. Recommended: 3.11+"
        else
            log_success "Python $python_version"
        fi
    fi

    # Check pip
    if ! command -v pip3 &> /dev/null; then
        missing_tools+=("pip3")
    else
        log_success "pip3 available"
    fi

    # Check PostgreSQL (optional)
    if ! command -v psql &> /dev/null; then
        log_warning "PostgreSQL client not found. Database tests will be skipped."
    else
        log_success "PostgreSQL client available"
    fi

    # Check Redis (optional)
    if ! command -v redis-cli &> /dev/null; then
        log_warning "Redis client not found. Redis tests will be skipped."
    else
        log_success "Redis client available"
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi

    log_success "All prerequisites met"
}

# Setup environment
setup_environment() {
    log_header "Setting Up Environment"

    # Create .env file if it doesn't exist
    if [ ! -f ".env" ]; then
        log_info "Creating .env file from template..."
        cp env.example .env
        log_success ".env file created"
    else
        log_info ".env file already exists"
    fi

    # Create necessary directories
    mkdir -p logs uploads temp cache models
    log_success "Directories created"
}

# Install API Gateway dependencies
install_api_gateway() {
    log_header "Installing API Gateway Dependencies"

    cd "$PROJECT_ROOT/services/api-gateway"

    if [ ! -d "node_modules" ]; then
        log_info "Installing Node.js dependencies..."
        npm install
        log_success "API Gateway dependencies installed"
    else
        log_info "API Gateway dependencies already installed"
    fi
}

# Install AI Service dependencies
install_ai_service() {
    log_header "Installing AI Service Dependencies"

    cd "$PROJECT_ROOT/services/ai-service"

    if [ ! -d "venv" ]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv venv
        source venv/bin/activate
        log_info "Installing Python dependencies..."
        pip install -r requirements.txt
        log_success "AI Service dependencies installed"
    else
        log_info "AI Service virtual environment already exists"
        source venv/bin/activate
    fi
}

# Install Realtime Service dependencies
install_realtime_service() {
    log_header "Installing Realtime Service Dependencies"

    cd "$PROJECT_ROOT/services/realtime-service"

    if [ ! -d "node_modules" ]; then
        log_info "Installing Node.js dependencies..."
        npm install
        log_success "Realtime Service dependencies installed"
    else
        log_info "Realtime Service dependencies already installed"
    fi
}

# Start API Gateway
start_api_gateway() {
    log_info "Starting API Gateway on port 3000..."
    cd "$PROJECT_ROOT/services/api-gateway"

    # Start in background
    npm run dev &
    API_GATEWAY_PID=$!
    echo $API_GATEWAY_PID > "$PROJECT_ROOT/.api_gateway_pid"

    # Wait a moment for startup
    sleep 3

    # Test if it's running
    if curl -f --max-time 5 http://localhost:3000/health >/dev/null 2>&1; then
        log_success "API Gateway started successfully (PID: $API_GATEWAY_PID)"
    else
        log_warning "API Gateway started but health check failed (PID: $API_GATEWAY_PID)"
    fi
}

# Start AI Service
start_ai_service() {
    log_info "Starting AI Service on port 8000..."
    cd "$PROJECT_ROOT/services/ai-service"

    # Activate virtual environment
    source venv/bin/activate

    # Start in background
    python main.py &
    AI_SERVICE_PID=$!
    echo $AI_SERVICE_PID > "$PROJECT_ROOT/.ai_service_pid"

    # Wait a moment for startup
    sleep 5

    # Test if it's running
    if curl -f --max-time 5 http://localhost:8000/health >/dev/null 2>&1; then
        log_success "AI Service started successfully (PID: $AI_SERVICE_PID)"
    else
        log_warning "AI Service started but health check failed (PID: $AI_SERVICE_PID)"
    fi
}

# Start Realtime Service
start_realtime_service() {
    log_info "Starting Realtime Service on port 3001..."
    cd "$PROJECT_ROOT/services/realtime-service"

    # Start in background
    npm run dev &
    REALTIME_SERVICE_PID=$!
    echo $REALTIME_SERVICE_PID > "$PROJECT_ROOT/.realtime_service_pid"

    # Wait a moment for startup
    sleep 3

    # Test if it's running
    if curl -f --max-time 5 http://localhost:3001/health >/dev/null 2>&1; then
        log_success "Realtime Service started successfully (PID: $REALTIME_SERVICE_PID)"
    else
        log_warning "Realtime Service started but health check failed (PID: $REALTIME_SERVICE_PID)"
    fi
}

# Test services
test_services() {
    log_header "Testing Services"

    local services=("API Gateway:http://localhost:3000/health" "AI Service:http://localhost:8000/health" "Realtime Service:http://localhost:3001/health")
    local failed_services=()

    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name service_url <<< "$service_info"
        log_info "Testing $service_name..."

        if curl -f --max-time 10 "$service_url" >/dev/null 2>&1; then
            log_success "$service_name is responding"
        else
            log_error "$service_name is not responding"
            failed_services+=("$service_name")
        fi
    done

    if [ ${#failed_services[@]} -eq 0 ]; then
        log_success "All services are healthy! ✅"
        return 0
    else
        log_warning "Some services failed: ${failed_services[*]}"
        return 1
    fi
}

# Stop services
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

# Show service information
show_info() {
    log_header "Service Information"

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
    echo "📊 Monitoring:"
    echo "=============="
    echo "API Gateway:    http://localhost:3000/metrics"
    echo ""
    echo "🛠️  Development:"
    echo "==============="
    echo "Stop all:       ./run-local.sh stop"
    echo "Restart:        ./run-local.sh restart"
    echo "Test:           ./run-local.sh test"
    echo ""
    echo "⚠️  Press Ctrl+C to stop all services"
    echo ""
}

# Cleanup function
cleanup() {
    echo ""
    log_info "Shutting down services..."
    stop_services
    log_success "All services stopped"
    exit 0
}

# Set trap for cleanup
trap cleanup SIGINT SIGTERM

# Main function
main() {
    case "${1:-start}" in
        "start")
            log_header "Vision Assistant - Local Development"

            check_prerequisites
            setup_environment

            # Install dependencies
            install_api_gateway
            install_ai_service
            install_realtime_service

            # Start services
            start_api_gateway
            start_ai_service
            start_realtime_service

            # Test services
            if test_services; then
                show_info
                log_header "🎉 All Services Running Successfully!"
                log_success "Vision Assistant is ready for development!"

                # Wait for services
                wait
            else
                log_error "Some services failed to start properly"
                log_info "Check the logs above for details"
                stop_services
                exit 1
            fi
            ;;
        "stop")
            stop_services
            log_success "All services stopped"
            ;;
        "test")
            test_services
            ;;
        "restart")
            stop_services
            sleep 2
            main start
            ;;
        "install")
            check_prerequisites
            install_api_gateway
            install_ai_service
            install_realtime_service
            log_success "All dependencies installed"
            ;;
        *)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  start     Start all services (default)"
            echo "  stop      Stop all services"
            echo "  test      Test all services"
            echo "  restart   Restart all services"
            echo "  install   Install all dependencies"
            echo ""
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
