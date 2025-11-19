#!/bin/bash

# Vision Assistant - Enterprise Infrastructure Deployment
# This script deploys the complete enterprise-grade infrastructure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
ENVIRONMENT="${ENVIRONMENT:-production}"
CLUSTER_NAME="${CLUSTER_NAME:-vision-assistant-cluster}"
REGION="${REGION:-us-east-1}"
DOMAIN="${DOMAIN:-vision-assistant.com}"

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

# Prerequisites check
check_prerequisites() {
    log_header "Checking Prerequisites"

    local missing_tools=()

    # Check required tools
    local tools=("docker" "kubectl" "helm" "terraform" "aws" "git" "kustomize")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure'."
        exit 1
    fi

    # Check if kubectl can access cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster."
        exit 1
    fi

    log_success "All prerequisites met"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log_header "Deploying Infrastructure"

    cd "$PROJECT_ROOT/infrastructure"

    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init -upgrade

    # Validate configuration
    log_info "Validating Terraform configuration..."
    terraform validate

    # Plan infrastructure
    log_info "Planning infrastructure changes..."
    terraform plan -out=tfplan \
        -var="environment=$ENVIRONMENT" \
        -var="cluster_name=$CLUSTER_NAME" \
        -var="region=$REGION" \
        -var="domain=$DOMAIN"

    # Confirm deployment for production
    if [ "$ENVIRONMENT" = "production" ]; then
        log_warning "This will deploy to PRODUCTION environment. Please review the plan above."
        read -p "Do you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Deployment cancelled by user."
            exit 0
        fi
    fi

    # Apply infrastructure
    log_info "Applying infrastructure changes..."
    terraform apply tfplan

    # Wait for infrastructure to be ready
    log_info "Waiting for infrastructure to be ready..."
    sleep 120

    log_success "Infrastructure deployed successfully"
}

# Setup Kubernetes cluster
setup_kubernetes() {
    log_header "Setting Up Kubernetes Cluster"

    # Update kubeconfig
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

    # Install cert-manager
    log_info "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager

    # Install external-secrets
    log_info "Installing external-secrets..."
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    helm install external-secrets external-secrets/external-secrets \
        -n external-secrets-system \
        --create-namespace \
        --wait

    # Install Istio service mesh
    log_info "Installing Istio service mesh..."
    istioctl install --set profile=default -y
    kubectl label namespace default istio-injection=enabled

    # Install ArgoCD
    log_info "Installing ArgoCD..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

    log_success "Kubernetes cluster setup complete"
}

# Deploy base infrastructure
deploy_base_infrastructure() {
    log_header "Deploying Base Infrastructure"

    cd "$PROJECT_ROOT/infrastructure"

    # Deploy base configuration
    log_info "Deploying base configuration..."
    kubectl apply -k base/

    # Wait for base resources
    log_info "Waiting for base resources to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment --all -n vision-assistant-system || true

    log_success "Base infrastructure deployed"
}

# Deploy monitoring stack
deploy_monitoring() {
    log_header "Deploying Monitoring Stack"

    # Install kube-prometheus-stack
    log_info "Installing Prometheus stack..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --values "$PROJECT_ROOT/infrastructure/monitoring/values.yaml" \
        --wait

    # Install Loki for logging
    log_info "Installing Loki stack..."
    helm repo add grafana https://grafana.github.io/helm-charts

    helm upgrade --install loki grafana/loki-stack \
        --namespace monitoring \
        --set grafana.enabled=false \
        --set prometheus.enabled=false \
        --set promtail.enabled=true \
        --wait

    # Install Jaeger for tracing
    log_info "Installing Jaeger..."
    kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

    kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.42.0/jaeger-operator.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/jaeger-operator -n observability

    log_success "Monitoring stack deployed"
}

# Setup GitOps with ArgoCD
setup_gitops() {
    log_header "Setting Up GitOps with ArgoCD"

    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    # Login to ArgoCD
    argocd login argocd."$DOMAIN" --username admin --password "$ARGOCD_PASSWORD" --grpc-web

    # Create applications
    log_info "Creating ArgoCD applications..."

    # Base infrastructure
    argocd app create vision-assistant-base \
        --repo https://github.com/your-org/vision-assistant \
        --path infrastructure/base \
        --dest-server https://kubernetes.default.svc \
        --dest-namespace vision-assistant-system \
        --sync-policy automated \
        --auto-prune \
        --self-heal

    # Monitoring
    argocd app create vision-assistant-monitoring \
        --repo https://github.com/your-org/vision-assistant \
        --path infrastructure/monitoring \
        --dest-server https://kubernetes.default.svc \
        --dest-namespace monitoring \
        --sync-policy automated \
        --auto-prune \
        --self-heal

    # Sync applications
    argocd app sync vision-assistant-base
    argocd app sync vision-assistant-monitoring

    log_success "GitOps setup complete"
}

# Setup CI/CD pipeline
setup_cicd() {
    log_header "Setting Up CI/CD Pipeline"

    # This would typically be done via GitHub Actions or similar
    log_info "CI/CD pipeline should be configured in .github/workflows/"
    log_info "Make sure to set up the following secrets in GitHub:"
    log_info "- AWS_ACCESS_KEY_ID"
    log_info "- AWS_SECRET_ACCESS_KEY"
    log_info "- ARGOCD_SERVER"
    log_info "- ARGOCD_USERNAME"
    log_info "- ARGOCD_PASSWORD"
    log_info "- DOCKERHUB_USERNAME"
    log_info "- DOCKERHUB_TOKEN"

    log_success "CI/CD setup instructions provided"
}

# Run post-deployment checks
post_deployment_checks() {
    log_header "Running Post-Deployment Checks"

    # Check cluster health
    log_info "Checking cluster health..."
    kubectl get nodes
    kubectl get pods -A

    # Check ArgoCD
    log_info "Checking ArgoCD status..."
    kubectl get pods -n argocd

    # Check monitoring
    log_info "Checking monitoring stack..."
    kubectl get pods -n monitoring

    # Generate deployment report
    {
        echo "Vision Assistant Infrastructure Deployment Report"
        echo "=================================================="
        echo "Environment: $ENVIRONMENT"
        echo "Cluster: $CLUSTER_NAME"
        echo "Region: $REGION"
        echo "Domain: $DOMAIN"
        echo "Timestamp: $(date)"
        echo ""
        echo "Infrastructure Status:"
        kubectl get nodes --no-headers | wc -l
        echo "Namespaces:"
        kubectl get namespaces | grep vision-assistant | wc -l
        echo "Pods:"
        kubectl get pods -A --no-headers | grep -E "(Running|Completed)" | wc -l
        echo ""
        echo "Access URLs:"
        echo "ArgoCD: https://argocd.$DOMAIN"
        echo "Grafana: https://grafana.$DOMAIN"
        echo "Prometheus: https://prometheus.$DOMAIN"
        echo "Jaeger: https://jaeger.$DOMAIN"
    } > "$PROJECT_ROOT/deployment-report.txt"

    log_success "Post-deployment checks complete"
    log_info "Deployment report saved to deployment-report.txt"
}

# Show access information
show_access_info() {
    log_header "Infrastructure Access Information"

    echo ""
    echo "🌐 Access URLs:"
    echo "==============="
    echo "ArgoCD Dashboard: https://argocd.$DOMAIN"
    echo "Grafana Dashboard: https://grafana.$DOMAIN"
    echo "Prometheus: https://prometheus.$DOMAIN"
    echo "Jaeger Tracing: https://jaeger.$DOMAIN"
    echo "Kibana Logs: https://kibana.$DOMAIN"
    echo ""
    echo "🔐 Default Credentials:"
    echo "======================"
    echo "ArgoCD Admin: admin / $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
    echo "Grafana Admin: admin / prom-operator"
    echo ""
    echo "📊 Monitoring:"
    echo "=============="
    echo "Health Check: kubectl get pods -A"
    echo "Logs: kubectl logs -f deployment/<service> -n <namespace>"
    echo "Metrics: kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
    echo ""
    echo "🚀 Next Steps:"
    echo "=============="
    echo "1. Deploy your applications using ArgoCD"
    echo "2. Configure DNS for your domain"
    echo "3. Set up SSL certificates with cert-manager"
    echo "4. Configure external secrets"
    echo "5. Deploy application services"
}

# Main deployment flow
main() {
    log_header "Vision Assistant Enterprise Infrastructure Deployment"
    log_info "Environment: $ENVIRONMENT"
    log_info "Cluster: $CLUSTER_NAME"
    log_info "Region: $REGION"
    log_info "Domain: $DOMAIN"

    check_prerequisites
    deploy_infrastructure
    setup_kubernetes
    deploy_base_infrastructure
    deploy_monitoring
    setup_gitops
    setup_cicd
    post_deployment_checks
    show_access_info

    log_header "🎉 Infrastructure Deployment Complete!"
    log_success "Your enterprise-grade infrastructure is ready!"
    log_info "Next: Deploy your application services using ArgoCD"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -e, --environment ENV    Environment (development, staging, production)"
            echo "  -c, --cluster NAME        EKS cluster name"
            echo "  -r, --region REGION       AWS region"
            echo "  -d, --domain DOMAIN       Domain name"
            echo "  --dry-run                 Show what would be done"
            echo "  -h, --help                Show this help"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate environment
case $ENVIRONMENT in
    development|staging|production)
        ;;
    *)
        log_error "Invalid environment: $ENVIRONMENT. Must be development, staging, or production."
        exit 1
        ;;
esac

# Run deployment
if [ "${DRY_RUN:-false}" = true ]; then
    log_info "DRY RUN MODE - Showing what would be deployed"
    log_info "Infrastructure components that would be deployed:"
    log_info "- AWS EKS Cluster"
    log_info "- VPC and Networking"
    log_info "- RDS PostgreSQL"
    log_info "- ElastiCache Redis"
    log_info "- S3 Storage"
    log_info "- Load Balancers"
    log_info "- Kubernetes base configuration"
    log_info "- Istio service mesh"
    log_info "- ArgoCD GitOps"
    log_info "- Monitoring stack (Prometheus, Grafana, Jaeger)"
    log_info "- Security policies and network policies"
else
    main
fi
