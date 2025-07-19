#!/bin/bash

# Rancher Deployment Platform Setup Script
# This script sets up the development environment and deploys the platform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists docker; then
        missing_tools+=("docker")
    fi
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists helm; then
        missing_tools+=("helm")
    fi
    
    if ! command_exists terraform; then
        missing_tools+=("terraform")
    fi
    
    if ! command_exists node; then
        missing_tools+=("node")
    fi
    
    if ! command_exists npm; then
        missing_tools+=("npm")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and run this script again."
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

# Setup environment
setup_environment() {
    log_info "Setting up environment..."
    
    # Copy environment file if it doesn't exist
    if [ ! -f .env ]; then
        cp .env.example .env
        log_success "Created .env file from .env.example"
        log_warning "Please update .env file with your configuration"
    else
        log_info ".env file already exists"
    fi
    
    # Create necessary directories
    mkdir -p logs
    mkdir -p data
    mkdir -p backups
    
    log_success "Environment setup completed"
}

# Install dependencies
install_dependencies() {
    log_info "Installing Node.js dependencies..."
    npm install
    log_success "Node.js dependencies installed"
}

# Initialize Terraform
init_terraform() {
    log_info "Initializing Terraform..."
    
    cd terraform
    
    # Check if backend is configured
    if [ ! -f terraform.tf ]; then
        log_warning "Terraform backend not configured. Using local state."
    fi
    
    terraform init
    terraform validate
    
    cd ..
    
    log_success "Terraform initialized and validated"
}

# Validate Helm charts
validate_helm() {
    log_info "Validating Helm charts..."
    
    helm lint helm-charts/rancher-app/
    
    log_success "Helm charts validated"
}

# Build Docker images
build_images() {
    log_info "Building Docker images..."
    
    docker build -t rancher-platform:latest .
    
    log_success "Docker images built"
}

# Start development environment
start_dev_environment() {
    log_info "Starting development environment..."
    
    docker-compose up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 30
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        log_success "Development environment started"
        log_info "Services are available at:"
        log_info "  - Application: http://localhost:8080"
        log_info "  - Grafana: http://localhost:3000 (admin/admin123)"
        log_info "  - Prometheus: http://localhost:9090"
        log_info "  - Jaeger: http://localhost:16686"
        log_info "  - Kibana: http://localhost:5601"
        log_info "  - MinIO: http://localhost:9001 (minioadmin/minioadmin123)"
    else
        log_error "Some services failed to start"
        docker-compose logs
        exit 1
    fi
}

# Run tests
run_tests() {
    log_info "Running tests..."
    
    if npm test; then
        log_success "All tests passed"
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Deploy to Kubernetes (development)
deploy_to_kubernetes() {
    log_info "Deploying to Kubernetes..."
    
    # Check if kubectl is configured
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "kubectl is not configured or cluster is not accessible"
        log_info "Please configure kubectl to connect to your Kubernetes cluster"
        return 1
    fi
    
    # Create namespace if it doesn't exist
    kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy using Helm
    helm upgrade --install rancher-app ./helm-charts/rancher-app \
        --namespace staging \
        --set environment=staging \
        --set image.tag=latest \
        --wait --timeout=10m
    
    log_success "Application deployed to Kubernetes"
    
    # Get service URL
    local service_url=$(kubectl get service rancher-app -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    if [ "$service_url" != "pending" ] && [ "$service_url" != "" ]; then
        log_info "Application is available at: http://$service_url"
    else
        log_info "Use 'kubectl port-forward service/rancher-app -n staging 8080:80' to access the application"
    fi
}

# Clean up resources
cleanup() {
    log_info "Cleaning up resources..."
    
    docker-compose down -v
    docker system prune -f
    
    log_success "Cleanup completed"
}

# Show help
show_help() {
    echo "Rancher Deployment Platform Setup Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup       - Complete setup (default)"
    echo "  check       - Check prerequisites only"
    echo "  install     - Install dependencies only"
    echo "  build       - Build Docker images only"
    echo "  start       - Start development environment"
    echo "  stop        - Stop development environment"
    echo "  test        - Run tests"
    echo "  deploy      - Deploy to Kubernetes"
    echo "  cleanup     - Clean up resources"
    echo "  help        - Show this help message"
    echo ""
}

# Main function
main() {
    local command=${1:-setup}
    
    case $command in
        setup)
            check_prerequisites
            setup_environment
            install_dependencies
            init_terraform
            validate_helm
            build_images
            log_success "Setup completed successfully!"
            log_info "Run '$0 start' to start the development environment"
            ;;
        check)
            check_prerequisites
            ;;
        install)
            install_dependencies
            ;;
        build)
            build_images
            ;;
        start)
            start_dev_environment
            ;;
        stop)
            log_info "Stopping development environment..."
            docker-compose down
            log_success "Development environment stopped"
            ;;
        test)
            run_tests
            ;;
        deploy)
            deploy_to_kubernetes
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
