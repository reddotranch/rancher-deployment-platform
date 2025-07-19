#!/bin/bash

# Deploy Applications Script for Rancher Deployment Platform
# This script deploys applications to Rancher clusters

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
ENVIRONMENT="staging"
NAMESPACE=""
APP_NAME="rancher-app"
IMAGE_TAG="latest"
CHART_PATH="./helm-charts/rancher-app"
DRY_RUN=false
WAIT_TIMEOUT="10m"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -a|--app-name)
      APP_NAME="$2"
      shift 2
      ;;
    -t|--tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    -c|--chart-path)
      CHART_PATH="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --timeout)
      WAIT_TIMEOUT="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -e, --environment    Environment (staging, production) [default: staging]"
      echo "  -n, --namespace      Kubernetes namespace [default: environment name]"
      echo "  -a, --app-name       Application name [default: rancher-app]"
      echo "  -t, --tag            Image tag [default: latest]"
      echo "  -c, --chart-path     Helm chart path [default: ./helm-charts/rancher-app]"
      echo "      --dry-run        Perform a dry run"
      echo "      --timeout        Wait timeout [default: 10m]"
      echo "  -h, --help           Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set default namespace if not provided
if [ -z "$NAMESPACE" ]; then
  NAMESPACE="$ENVIRONMENT"
fi

# Validate environment
if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "development" ]]; then
  log_error "Invalid environment: $ENVIRONMENT. Must be staging, production, or development."
  exit 1
fi

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."
  
  if ! command -v kubectl >/dev/null 2>&1; then
    log_error "kubectl is not installed"
    exit 1
  fi
  
  if ! command -v helm >/dev/null 2>&1; then
    log_error "helm is not installed"
    exit 1
  fi
  
  if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "kubectl is not configured or cluster is not accessible"
    exit 1
  fi
  
  log_success "Prerequisites check passed"
}

# Prepare environment
prepare_environment() {
  log_info "Preparing environment: $ENVIRONMENT"
  
  # Create namespace if it doesn't exist
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  log_success "Namespace '$NAMESPACE' ready"
  
  # Add Helm repositories if needed
  log_info "Adding Helm repositories..."
  helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
  helm repo update
  log_success "Helm repositories updated"
}

# Deploy application
deploy_application() {
  log_info "Deploying $APP_NAME to $ENVIRONMENT environment..."
  
  local helm_args=(
    "upgrade" "--install" "$APP_NAME"
    "$CHART_PATH"
    "--namespace" "$NAMESPACE"
    "--set" "environment=$ENVIRONMENT"
    "--set" "image.tag=$IMAGE_TAG"
    "--wait"
    "--timeout=$WAIT_TIMEOUT"
  )
  
  # Environment-specific configurations
  case $ENVIRONMENT in
    "production")
      helm_args+=(
        "--set" "replicaCount=3"
        "--set" "resources.requests.memory=512Mi"
        "--set" "resources.limits.memory=1Gi"
        "--set" "autoscaling.enabled=true"
        "--set" "autoscaling.maxReplicas=10"
      )
      ;;
    "staging")
      helm_args+=(
        "--set" "replicaCount=2"
        "--set" "resources.requests.memory=256Mi"
        "--set" "resources.limits.memory=512Mi"
      )
      ;;
    "development")
      helm_args+=(
        "--set" "replicaCount=1"
        "--set" "resources.requests.memory=128Mi"
        "--set" "resources.limits.memory=256Mi"
      )
      ;;
  esac
  
  if [ "$DRY_RUN" = true ]; then
    helm_args+=("--dry-run" "--debug")
    log_info "Performing dry run..."
  fi
  
  if helm "${helm_args[@]}"; then
    log_success "$APP_NAME deployed successfully to $ENVIRONMENT!"
  else
    log_error "Failed to deploy $APP_NAME"
    exit 1
  fi
}

# Verify deployment
verify_deployment() {
  if [ "$DRY_RUN" = true ]; then
    log_info "Skipping verification for dry run"
    return
  fi
  
  log_info "Verifying deployment..."
  
  # Check pod status
  if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name="$APP_NAME" -n "$NAMESPACE" --timeout=300s; then
    log_success "Pods are ready"
  else
    log_error "Pods failed to become ready"
    kubectl get pods -n "$NAMESPACE"
    exit 1
  fi
  
  # Check service status
  if kubectl get service "$APP_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    log_success "Service is available"
  else
    log_warning "Service not found"
  fi
  
  # Display deployment info
  log_info "Deployment information:"
  kubectl get pods,svc,ing -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME"
}

# Get application URL
get_application_url() {
  if [ "$DRY_RUN" = true ]; then
    return
  fi
  
  log_info "Getting application URL..."
  
  # Try to get ingress URL
  local ingress_url=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")
  
  if [ -n "$ingress_url" ]; then
    log_success "Application URL: https://$ingress_url"
  else
    # Try to get LoadBalancer URL
    local lb_url=$(kubectl get service "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$lb_url" ] && [ "$lb_url" != "null" ]; then
      log_success "Application URL: http://$lb_url"
    else
      log_info "Use port-forward to access the application:"
      log_info "kubectl port-forward service/$APP_NAME -n $NAMESPACE 8080:80"
    fi
  fi
}

# Deploy monitoring stack
deploy_monitoring() {
  if [ "$ENVIRONMENT" = "production" ] || [ "$ENVIRONMENT" = "staging" ]; then
    log_info "Deploying monitoring stack for $ENVIRONMENT..."
    
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --create-namespace \
      --set grafana.adminPassword=admin123 \
      --wait --timeout=10m
    
    log_success "Monitoring stack deployed"
  fi
}

# Main execution
main() {
  log_info "Starting application deployment..."
  log_info "Environment: $ENVIRONMENT"
  log_info "Namespace: $NAMESPACE"
  log_info "App Name: $APP_NAME"
  log_info "Image Tag: $IMAGE_TAG"
  
  check_prerequisites
  prepare_environment
  deploy_application
  verify_deployment
  get_application_url
  
  if [ "$ENVIRONMENT" != "development" ]; then
    deploy_monitoring
  fi
  
  log_success "Application deployment completed successfully!"
}

# Run main function
main "$@"
