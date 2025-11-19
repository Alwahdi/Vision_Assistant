#!/bin/bash

# Vision Assistant - Local Development Deployment Script
# This script sets up and runs the complete local development environment

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

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"

    local missing_tools=()

    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    else
        # Check if Docker is running
        if ! docker info &> /dev/null; then
            log_error "Docker is not running. Please start Docker Desktop."
            exit 1
        fi
        log_success "Docker is running"
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_tools+=("docker-compose")
    else
        log_success "Docker Compose is available"
    fi

    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        log_warning "No internet connection detected. Docker pulls may fail."
        log_info "Continuing anyway..."
    else
        log_success "Internet connection available"
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi

    log_success "All prerequisites met"
}

# Setup environment configuration
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

    # Set proper permissions
    chmod +x "$0"
    log_success "Script permissions set"
}

# Clean up existing containers and volumes
cleanup() {
    log_header "Cleaning Up"

    log_info "Stopping and removing existing containers..."
    docker-compose down --remove-orphans --volumes 2>/dev/null || true

    log_info "Removing unused Docker images..."
    docker image prune -f >/dev/null 2>&1 || true

    log_info "Cleaning up dangling resources..."
    docker system prune -f >/dev/null 2>&1 || true

    log_success "Cleanup completed"
}

# Build Docker images with retry logic
build_services() {
    log_header "Building Services"

    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        log_info "Building Docker images... (attempt $((retry_count + 1))/$max_retries)"

        if docker-compose build --parallel; then
            log_success "Services built successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log_warning "Build failed, retrying in 10 seconds..."
                sleep 10
                # Clean up failed builds
                docker system prune -f >/dev/null 2>&1 || true
            else
                log_error "Failed to build services after $max_retries attempts"
                log_info "Checking Docker status..."
                docker info
                return 1
            fi
        fi
    done
}

# Start services
start_services() {
    log_header "Starting Services"

    log_info "Starting all services..."
    docker-compose up -d

    log_info "Waiting for services to be healthy..."

    # Wait for database
    log_info "Waiting for PostgreSQL..."
    timeout=60
    counter=0
    while [ $counter -lt $timeout ]; do
        if docker-compose exec -T postgres pg_isready -U vision_user -d vision_assistant >/dev/null 2>&1; then
            log_success "PostgreSQL is ready"
            break
        fi
        counter=$((counter + 1))
        sleep 1
    done

    if [ $counter -eq $timeout ]; then
        log_error "PostgreSQL failed to start within $timeout seconds"
        return 1
    fi

    # Wait for Redis
    log_info "Waiting for Redis..."
    counter=0
    while [ $counter -lt 30 ]; do
        if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
            log_success "Redis is ready"
            break
        fi
        counter=$((counter + 1))
        sleep 1
    done

    if [ $counter -eq 30 ]; then
        log_error "Redis failed to start within 30 seconds"
        return 1
    fi

    log_success "All services started successfully"
}

# Run database migrations
run_migrations() {
    log_header "Running Database Setup"

    log_info "Running database initialization..."

    # The database is already initialized via docker-compose init script
    # But let's verify the setup
    sleep 5

    # Test database connection
    if docker-compose exec -T postgres psql -U vision_user -d vision_assistant -c "SELECT COUNT(*) FROM users;" >/dev/null 2>&1; then
        log_success "Database setup verified"
    else
        log_error "Database setup failed"
        return 1
    fi
}

# Test services
test_services() {
    log_header "Testing Services"

    local services=("postgres" "redis" "api-gateway" "ai-service" "realtime-service")
    local failed_services=()

    for service in "${services[@]}"; do
        log_info "Testing $service..."

        case $service in
            "postgres")
                if docker-compose exec -T postgres pg_isready -U vision_user -d vision_assistant >/dev/null 2>&1; then
                    log_success "$service is healthy"
                else
                    log_error "$service is not healthy"
                    failed_services+=("$service")
                fi
                ;;
            "redis")
                if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
                    log_success "$service is healthy"
                else
                    log_error "$service is not healthy"
                    failed_services+=("$service")
                fi
                ;;
            "api-gateway")
                if curl -f --max-time 10 http://localhost:3000/health >/dev/null 2>&1; then
                    log_success "$service is healthy"
                else
                    log_error "$service is not healthy (might still be starting)"
                    failed_services+=("$service")
                fi
                ;;
            "ai-service")
                if curl -f --max-time 10 http://localhost:8000/health >/dev/null 2>&1; then
                    log_success "$service is healthy"
                else
                    log_error "$service is not healthy (might still be starting)"
                    failed_services+=("$service")
                fi
                ;;
            "realtime-service")
                if curl -f --max-time 10 http://localhost:3001/health >/dev/null 2>&1; then
                    log_success "$service is healthy"
                else
                    log_error "$service is not healthy (might still be starting)"
                    failed_services+=("$service")
                fi
                ;;
        esac
    done

    if [ ${#failed_services[@]} -eq 0 ]; then
        log_success "All services are healthy!"
    else
        log_warning "Some services may still be starting: ${failed_services[*]}"
        log_info "They should be available shortly. You can check logs with: docker-compose logs -f"
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
    echo "Real-time:      http://localhost:3001"
    echo "PostgreSQL:     localhost:5432"
    echo "Redis:          localhost:6379"
    echo ""
    echo "🩺 Health Checks:"
    echo "================="
    echo "API Gateway:    http://localhost:3000/health"
    echo "AI Service:     http://localhost:8000/health"
    echo "Real-time:      http://localhost:3001/health"
    echo ""
    echo "📊 Monitoring:"
    echo "=============="
    echo "View logs:      docker-compose logs -f [service]"
    echo "Stop all:       docker-compose down"
    echo "Restart:        docker-compose restart"
    echo ""
    echo "🛠️  Development:"
    echo "==============="
    echo "Frontend:       cd frontend && npm start"
    echo "API Gateway:    cd services/api-gateway && npm run dev"
    echo "AI Service:     cd services/ai-service && python main.py"
    echo ""
}

# Stop services
stop_services() {
    log_header "Stopping Services"

    log_info "Stopping all services..."
    docker-compose down --remove-orphans

    log_success "Services stopped"
}

# Show logs
show_logs() {
    local service="${1:-}"
    if [ -n "$service" ]; then
        log_info "Showing logs for $service..."
        docker-compose logs -f "$service"
    else
        log_info "Showing logs for all services..."
        docker-compose logs -f
    fi
}

# Show status
show_status() {
    log_header "Service Status"

    docker-compose ps
    echo ""
    echo "📊 Resource Usage:"
    echo "=================="
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

# Clean everything
clean_all() {
    log_header "Cleaning Everything"

    log_warning "This will remove all containers, volumes, and images!"
    read -p "Are you sure? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Cleaning all Docker resources..."
        docker-compose down --remove-orphans --volumes
        docker system prune -f --volumes
        docker image prune -f --all
        rm -rf logs/* uploads/* temp/* cache/* 2>/dev/null || true
        log_success "Everything cleaned"
    else
        log_info "Clean cancelled"
    fi
}

# Main functions
start() {
    check_prerequisites
    setup_environment
    cleanup
    build_services
    start_services
    run_migrations
    test_services
    show_info

    log_header "🎉 Local Environment Ready!"
    log_success "Vision Assistant is running locally!"
    log_info "Use 'docker-compose logs -f' to monitor services"
}

restart() {
    log_info "Restarting services..."
    docker-compose restart
    sleep 5
    test_services
    log_success "Services restarted"
}

# Main script logic
main() {
    case "${1:-start}" in
        "start")
            start
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart
            ;;
        "logs")
            show_logs "${2:-}"
            ;;
        "status")
            show_status
            ;;
        "clean")
            clean_all
            ;;
        "test")
            test_services
            ;;
        "build")
            build_services
            ;;
        *)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  start     Start all services (default)"
            echo "  stop      Stop all services"
            echo "  restart   Restart all services"
            echo "  logs      Show logs (optionally specify service)"
            echo "  status    Show service status"
            echo "  clean     Clean all Docker resources"
            echo "  test      Test all services"
            echo "  build     Build all services"
            echo ""
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"