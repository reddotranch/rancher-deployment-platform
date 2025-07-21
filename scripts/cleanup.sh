#!/bin/bash

# Cleanup Script for Rancher Deployment Platform
# This script cleans up resources and environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default values
CLEANUP_TYPE="dev"
FORCE=false
TERRAFORM_DIR="./terraform"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --type)
      CLEANUP_TYPE="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --terraform-dir)
      TERRAFORM_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --type              Cleanup type (dev, staging, production, all) [default: dev]"
      echo "  --force             Force cleanup without confirmation"
      echo "  --terraform-dir     Terraform directory [default: ./terraform]"
      echo "  -h, --help          Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Confirmation prompt
confirm_cleanup() {
  if [ "$FORCE" = false ]; then
    log_warning "This will permanently delete resources for: $CLEANUP_TYPE"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_info "Cleanup cancelled"
      exit 0
    fi
  fi
}

# Cleanup development environment
cleanup_dev() {
  log_info "Cleaning up development environment..."
  
  # Stop Docker Compose
  if [ -f "docker-compose.yml" ]; then
    docker-compose down -v --remove-orphans 2>/dev/null || true
    log_success "Docker Compose services stopped"
  fi
  
  # Clean Docker system
  docker system prune -f --volumes 2>/dev/null || true
  log_success "Docker system cleaned"
  
  # Clean local files
  rm -rf logs/*.log 2>/dev/null || true
  rm -rf data/* 2>/dev/null || true
  rm -rf node_modules/.cache 2>/dev/null || true
  rm -rf generated-manifests 2>/dev/null || true
  rm -f cluster-info-*.txt 2>/dev/null || true
  
  log_success "Development environment cleaned"
}

# Cleanup Kubernetes namespaces
cleanup_kubernetes() {
  local namespace=$1
  
  if kubectl get namespace "$namespace" >/dev/null 2>&1; then
    log_info "Cleaning up Kubernetes namespace: $namespace"
    
    # Delete all resources in namespace
    kubectl delete all --all -n "$namespace" --timeout=60s || true
    
    # Delete the namespace
    kubectl delete namespace "$namespace" --timeout=60s || true
    
    log_success "Kubernetes namespace $namespace cleaned"
  else
    log_info "Namespace $namespace does not exist"
  fi
}

# Cleanup Terraform resources
cleanup_terraform() {
  if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    log_info "Destroying Terraform infrastructure..."
    
    cd "$TERRAFORM_DIR"
    terraform destroy -auto-approve
    cd - >/dev/null
    
    log_success "Terraform infrastructure destroyed"
  else
    log_info "No Terraform state found"
  fi
}

# Cleanup specific environment
cleanup_environment() {
  local env=$1
  
  log_info "Cleaning up $env environment..."
  
  # Cleanup Kubernetes resources
  cleanup_kubernetes "$env"
  cleanup_kubernetes "cattle-system"
  cleanup_kubernetes "cert-manager"
  cleanup_kubernetes "ingress-nginx"
  cleanup_kubernetes "monitoring"
  
  # Cleanup Helm releases
  helm list -A | grep -E "(rancher|prometheus|grafana)" | awk '{print $1, $2}' | while read release namespace; do
    if [ -n "$release" ] && [ -n "$namespace" ]; then
      log_info "Uninstalling Helm release: $release in namespace: $namespace"
      helm uninstall "$release" -n "$namespace" || true
    fi
  done
  
  log_success "$env environment cleaned"
}

# Main cleanup function
main() {
  log_info "Starting cleanup process..."
  log_info "Cleanup Type: $CLEANUP_TYPE"
  
  confirm_cleanup
  
  case $CLEANUP_TYPE in
    "dev"|"development")
      cleanup_dev
      ;;
    "staging")
      cleanup_environment "staging"
      ;;
    "production")
      log_warning "Production cleanup requires extra confirmation"
      read -p "Type 'DELETE-PRODUCTION' to confirm: " confirm
      if [ "$confirm" = "DELETE-PRODUCTION" ]; then
        cleanup_environment "production"
      else
        log_error "Production cleanup cancelled - incorrect confirmation"
        exit 1
      fi
      ;;
    "all")
      cleanup_dev
      cleanup_environment "staging"
      cleanup_environment "production"
      cleanup_terraform
      ;;
    *)
      log_error "Invalid cleanup type: $CLEANUP_TYPE"
      exit 1
      ;;
  esac
  
  log_success "Cleanup completed successfully!"
}

# Run main function
main "$@"
