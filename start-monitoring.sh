#!/bin/bash

# Vision Assistant - Monitoring Startup Script
# This script starts all monitoring services and provides access information

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Vision Assistant Monitoring Stack${NC}"
echo "==========================================="

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running. Please start Docker Desktop first.${NC}"
        exit 1
    fi
}

# Function to wait for service to be healthy
wait_for_service() {
    local service_name=$1
    local max_attempts=30
    local attempt=1

    echo -e "${YELLOW}⏳ Waiting for ${service_name} to be healthy...${NC}"

    while [ $attempt -le $max_attempts ]; do
        if docker ps --filter "name=${service_name}" --filter "health=healthy" | grep -q "${service_name}"; then
            echo -e "${GREEN}✅ ${service_name} is healthy${NC}"
            return 0
        fi

        echo -e "${YELLOW}   Attempt ${attempt}/${max_attempts} - ${service_name} not ready yet...${NC}"
        sleep 2
        ((attempt++))
    done

    echo -e "${RED}❌ ${service_name} failed to become healthy${NC}"
    return 1
}

# Main startup function
start_monitoring() {
    echo -e "${BLUE}📊 Starting monitoring services...${NC}"

    # Start monitoring services
    docker-compose up -d prometheus grafana node-exporter cadvisor

    echo ""
    echo -e "${YELLOW}🔍 Checking service health...${NC}"

    # Wait for services to be healthy
    wait_for_service "vision-assistant-prometheus"
    wait_for_service "vision-assistant-grafana"

    echo ""
    echo -e "${GREEN}🎉 Monitoring stack started successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Access Information:${NC}"
    echo "========================"
    echo -e "${GREEN}📊 Prometheus:${NC} http://localhost:9090"
    echo -e "${GREEN}📈 Grafana:${NC} http://localhost:3030"
    echo -e "${GREEN}   Username:${NC} admin"
    echo -e "${GREEN}   Password:${NC} vision2024!"
    echo -e "${GREEN}📊 Node Exporter:${NC} http://localhost:9100"
    echo -e "${GREEN}📊 cAdvisor:${NC} http://localhost:8080"
    echo ""
    echo -e "${BLUE}🔗 Service Metrics Endpoints:${NC}"
    echo "=============================="
    echo -e "${GREEN}API Gateway Metrics:${NC} http://localhost:3000/metrics"
    echo -e "${GREEN}AI Service Metrics:${NC} http://localhost:8000/metrics"
    echo -e "${GREEN}Realtime Service Metrics:${NC} http://localhost:3001/metrics"
    echo ""
    echo -e "${YELLOW}💡 Tips:${NC}"
    echo "========"
    echo "• Import dashboard from: monitoring/grafana/dashboards/vision-assistant-dashboard.json"
    echo "• Check service logs: docker logs [service-name]"
    echo "• Stop monitoring: docker-compose down"
    echo ""
    echo -e "${GREEN}🎯 Ready to monitor your Vision Assistant application!${NC}"
}

# Function to stop monitoring
stop_monitoring() {
    echo -e "${YELLOW}🛑 Stopping monitoring services...${NC}"
    docker-compose down prometheus grafana node-exporter cadvisor
    echo -e "${GREEN}✅ Monitoring services stopped${NC}"
}

# Function to show status
show_status() {
    echo -e "${BLUE}📊 Monitoring Services Status${NC}"
    echo "=============================="
    docker ps --filter "name=vision-assistant-prometheus" --filter "name=vision-assistant-grafana" --filter "name=vision-assistant-node-exporter" --filter "name=vision-assistant-cadvisor" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Function to show logs
show_logs() {
    local service=$1
    if [ -z "$service" ]; then
        echo -e "${YELLOW}Usage: $0 logs [prometheus|grafana|node-exporter|cadvisor]${NC}"
        exit 1
    fi
    docker logs -f "vision-assistant-${service}"
}

# Main script logic
case "${1:-start}" in
    "start")
        check_docker
        start_monitoring
        ;;
    "stop")
        stop_monitoring
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs "$2"
        ;;
    "restart")
        stop_monitoring
        sleep 2
        check_docker
        start_monitoring
        ;;
    *)
        echo -e "${BLUE}Vision Assistant Monitoring Script${NC}"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start     Start monitoring services (default)"
        echo "  stop      Stop monitoring services"
        echo "  status    Show monitoring services status"
        echo "  restart   Restart monitoring services"
        echo "  logs [service] Show logs for specific service"
        echo ""
        echo "Services: prometheus, grafana, node-exporter, cadvisor"
        exit 1
        ;;
esac
