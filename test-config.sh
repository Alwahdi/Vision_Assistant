#!/bin/bash

# Vision Assistant - Configuration Test Script
# Tests the configuration without requiring Docker to be running

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Test file existence
test_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        log_success "✓ $file exists"
        return 0
    else
        log_error "✗ $file missing"
        return 1
    fi
}

# Test directory existence
test_directory_exists() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        log_success "✓ $dir directory exists"
        return 0
    else
        log_error "✗ $dir directory missing"
        return 1
    fi
}

# Test docker-compose configuration
test_docker_compose() {
    log_info "Testing docker-compose.yml..."

    if ! command -v docker-compose >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
        log_warning "Docker/Docker Compose not available for validation"
        return 0
    fi

    # Try to validate docker-compose config
    if command -v docker-compose >/dev/null 2>&1; then
        if docker-compose config -q >/dev/null 2>&1; then
            log_success "✓ docker-compose.yml is valid"
        else
            log_error "✗ docker-compose.yml has errors"
            return 1
        fi
    elif docker compose config -q >/dev/null 2>&1; then
        log_success "✓ docker-compose.yml is valid"
    else
        log_error "✗ docker-compose.yml has errors"
        return 1
    fi
}

# Test service configurations
test_service_config() {
    local service="$1"
    local service_dir="services/$service"

    log_info "Testing $service configuration..."

    # Check service directory
    test_directory_exists "$service_dir" || return 1

    # Check Dockerfile
    test_file_exists "$service_dir/Dockerfile" || return 1

    # Check package.json for Node.js services
    if [[ "$service" == "api-gateway" || "$service" == "realtime-service" ]]; then
        test_file_exists "$service_dir/package.json" || return 1
        test_directory_exists "$service_dir/src" || return 1
    fi

    # Check Python service
    if [[ "$service" == "ai-service" ]]; then
        test_file_exists "$service_dir/requirements.txt" || return 1
        test_file_exists "$service_dir/main.py" || return 1
        test_directory_exists "$service_dir/app" || return 1
    fi

    log_success "✓ $service configuration is complete"
}

# Test environment configuration
test_environment_config() {
    log_info "Testing environment configuration..."

    # Check .env file
    if [[ -f ".env" ]]; then
        log_success "✓ .env file exists"
    elif [[ -f "env.example" ]]; then
        log_warning "⚠ .env file missing, but env.example exists"
    else
        log_error "✗ No environment configuration found"
        return 1
    fi

    # Check for required environment variables
    if [[ -f ".env" ]]; then
        local required_vars=("POSTGRES_PASSWORD" "JWT_SECRET")
        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" .env; then
                log_success "✓ $var is configured"
            else
                log_error "✗ $var is missing from .env"
                return 1
            fi
        done
    fi
}

# Test database schema
test_database_schema() {
    log_info "Testing database schema..."

    test_file_exists "db/init.sql" || return 1

    # Check if SQL file has basic structure
    if grep -q "CREATE TABLE" db/init.sql; then
        log_success "✓ Database schema contains table definitions"
    else
        log_error "✗ Database schema appears incomplete"
        return 1
    fi
}

# Test deployment scripts
test_deployment_scripts() {
    log_info "Testing deployment scripts..."

    test_file_exists "deploy-local.sh" || return 1

    if [[ -x "deploy-local.sh" ]]; then
        log_success "✓ deploy-local.sh is executable"
    else
        log_error "✗ deploy-local.sh is not executable"
        return 1
    fi
}

# Test infrastructure configuration
test_infrastructure() {
    log_info "Testing infrastructure configuration..."

    test_directory_exists "infrastructure/base" || return 1
    test_file_exists "infrastructure/base/kustomization.yml" || return 1
    test_directory_exists "environments" || return 1
    test_directory_exists "environments/development" || return 1
}

# Main test function
main() {
    log_header "🧪 Vision Assistant Configuration Test"

    local errors=0
    local warnings=0

    # Test basic project structure
    log_header "Testing Project Structure"

    test_file_exists "README.md" || ((errors++))
    test_file_exists "docker-compose.yml" || ((errors++))
    test_file_exists ".gitignore" || ((errors++))
    test_directory_exists "services" || ((errors++))

    # Test docker-compose configuration
    log_header "Testing Docker Configuration"
    test_docker_compose || ((errors++))

    # Test service configurations
    log_header "Testing Service Configurations"

    local services=("api-gateway" "ai-service" "realtime-service")
    for service in "${services[@]}"; do
        test_service_config "$service" || ((errors++))
    done

    # Test environment configuration
    log_header "Testing Environment Configuration"
    test_environment_config || ((errors++))

    # Test database
    log_header "Testing Database Configuration"
    test_database_schema || ((errors++))

    # Test deployment
    log_header "Testing Deployment Configuration"
    test_deployment_scripts || ((errors++))

    # Test infrastructure
    log_header "Testing Infrastructure Configuration"
    test_infrastructure || ((warnings++))

    # Summary
    log_header "📊 Test Results Summary"

    if [[ $errors -eq 0 ]]; then
        if [[ $warnings -eq 0 ]]; then
            log_success "🎉 All tests passed! Configuration is ready."
        else
            log_warning "⚠️ Configuration is ready with $warnings warnings."
        fi

        echo ""
        echo "🚀 Next steps:"
        echo "1. Start Docker Desktop"
        echo "2. Run: ./deploy-local.sh start"
        echo "3. Test the APIs:"
        echo "   - API Gateway: curl http://localhost:3000/health"
        echo "   - AI Service: curl http://localhost:8000/health"
        echo "   - Real-time: curl http://localhost:3001/health"

        exit 0
    else
        log_error "❌ $errors errors found. Please fix them before proceeding."
        echo ""
        echo "🔧 Common fixes:"
        echo "- Run: chmod +x deploy-local.sh"
        echo "- Copy env.example to .env and configure"
        echo "- Ensure all required files are created"
        exit 1
    fi
}

# Run main function
main "$@"
