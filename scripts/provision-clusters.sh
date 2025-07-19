#!/bin/bash

# Provision Clusters Script for Rancher Deployment Platform
# This script provisions and configures Kubernetes clusters for Rancher

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
CLUSTER_NAME=""
CLUSTER_TYPE="development"
NODE_COUNT=3
NODE_SIZE="t3.medium"
KUBERNETES_VERSION="1.28"
REGION="us-west-2"
CLOUD_PROVIDER="aws"
TERRAFORM_DIR="./terraform"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    -t|--type)
      CLUSTER_TYPE="$2"
      shift 2
      ;;
    --node-count)
      NODE_COUNT="$2"
      shift 2
      ;;
    --node-size)
      NODE_SIZE="$2"
      shift 2
      ;;
    -k|--kubernetes-version)
      KUBERNETES_VERSION="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -c|--cloud-provider)
      CLOUD_PROVIDER="$2"
      shift 2
      ;;
    --terraform-dir)
      TERRAFORM_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -n, --name              Cluster name (required)"
      echo "  -t, --type              Cluster type (development, staging, production) [default: development]"
      echo "      --node-count        Number of worker nodes [default: 3]"
      echo "      --node-size         Node instance size [default: t3.medium]"
      echo "  -k, --kubernetes-version Kubernetes version [default: 1.28]"
      echo "  -r, --region            Cloud region [default: us-west-2]"
      echo "  -c, --cloud-provider    Cloud provider (aws, gcp, azure) [default: aws]"
      echo "      --terraform-dir     Terraform directory [default: ./terraform]"
      echo "  -h, --help              Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$CLUSTER_NAME" ]; then
  log_error "Cluster name is required. Use -n or --name to specify."
  exit 1
fi

# Validate cluster type
if [[ "$CLUSTER_TYPE" != "development" && "$CLUSTER_TYPE" != "staging" && "$CLUSTER_TYPE" != "production" ]]; then
  log_error "Invalid cluster type: $CLUSTER_TYPE. Must be development, staging, or production."
  exit 1
fi

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."
  
  local missing_tools=()
  
  if ! command -v terraform >/dev/null 2>&1; then
    missing_tools+=("terraform")
  fi
  
  if ! command -v kubectl >/dev/null 2>&1; then
    missing_tools+=("kubectl")
  fi
  
  case $CLOUD_PROVIDER in
    "aws")
      if ! command -v aws >/dev/null 2>&1; then
        missing_tools+=("aws")
      fi
      ;;
    "gcp")
      if ! command -v gcloud >/dev/null 2>&1; then
        missing_tools+=("gcloud")
      fi
      ;;
    "azure")
      if ! command -v az >/dev/null 2>&1; then
        missing_tools+=("az")
      fi
      ;;
  esac
  
  if [ ${#missing_tools[@]} -ne 0 ]; then
    log_error "Missing required tools: ${missing_tools[*]}"
    exit 1
  fi
  
  log_success "Prerequisites check passed"
}

# Validate cloud credentials
validate_credentials() {
  log_info "Validating cloud credentials..."
  
  case $CLOUD_PROVIDER in
    "aws")
      if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
      fi
      log_success "AWS credentials validated"
      ;;
    "gcp")
      if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 >/dev/null 2>&1; then
        log_error "GCP credentials not configured. Run 'gcloud auth login' first."
        exit 1
      fi
      log_success "GCP credentials validated"
      ;;
    "azure")
      if ! az account show >/dev/null 2>&1; then
        log_error "Azure credentials not configured. Run 'az login' first."
        exit 1
      fi
      log_success "Azure credentials validated"
      ;;
  esac
}

# Generate Terraform configuration
generate_terraform_config() {
  log_info "Generating Terraform configuration for $CLUSTER_TYPE cluster..."
  
  local tf_vars_file="$TERRAFORM_DIR/terraform.tfvars"
  
  # Create terraform.tfvars based on cluster type
  cat > "$tf_vars_file" <<EOF
# Terraform variables for $CLUSTER_NAME ($CLUSTER_TYPE)
# Generated on $(date)

# Basic Configuration
project_name = "$CLUSTER_NAME"
environment = "$CLUSTER_TYPE"
aws_region = "$REGION"

# EKS Configuration
kubernetes_version = "$KUBERNETES_VERSION"

# Node Group Configuration
node_group_desired_size = $NODE_COUNT
node_group_max_size = $((NODE_COUNT * 2))
node_group_min_size = 1
node_instance_types = ["$NODE_SIZE"]

EOF

  # Add environment-specific configurations
  case $CLUSTER_TYPE in
    "production")
      cat >> "$tf_vars_file" <<EOF
# Production-specific settings
node_capacity_type = "ON_DEMAND"
create_rds = true
rds_instance_class = "db.t3.small"
enable_monitoring = true
enable_cluster_autoscaler = true
enable_aws_load_balancer_controller = true
enable_multi_az = true

EOF
      ;;
    "staging")
      cat >> "$tf_vars_file" <<EOF
# Staging-specific settings
node_capacity_type = "ON_DEMAND"
create_rds = true
rds_instance_class = "db.t3.micro"
enable_monitoring = true
enable_cluster_autoscaler = true
enable_aws_load_balancer_controller = true

EOF
      ;;
    "development")
      cat >> "$tf_vars_file" <<EOF
# Development-specific settings
node_capacity_type = "SPOT"
create_rds = false
enable_monitoring = false
enable_cluster_autoscaler = false
enable_aws_load_balancer_controller = true

EOF
      ;;
  esac
  
  log_success "Terraform configuration generated at $tf_vars_file"
}

# Initialize Terraform
init_terraform() {
  log_info "Initializing Terraform..."
  
  cd "$TERRAFORM_DIR"
  
  # Initialize Terraform
  terraform init
  
  # Validate configuration
  terraform validate
  
  cd - >/dev/null
  
  log_success "Terraform initialized and validated"
}

# Plan Terraform deployment
plan_terraform() {
  log_info "Planning Terraform deployment..."
  
  cd "$TERRAFORM_DIR"
  
  terraform plan -out=tfplan
  
  cd - >/dev/null
  
  log_success "Terraform plan completed. Review the plan before applying."
}

# Apply Terraform configuration
apply_terraform() {
  log_info "Applying Terraform configuration..."
  
  cd "$TERRAFORM_DIR"
  
  if [ -f "tfplan" ]; then
    terraform apply tfplan
  else
    terraform apply -auto-approve
  fi
  
  cd - >/dev/null
  
  log_success "Terraform applied successfully"
}

# Configure kubectl
configure_kubectl() {
  log_info "Configuring kubectl..."
  
  case $CLOUD_PROVIDER in
    "aws")
      aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME-eks-$CLUSTER_TYPE"
      ;;
    "gcp")
      gcloud container clusters get-credentials "$CLUSTER_NAME" --region="$REGION"
      ;;
    "azure")
      az aks get-credentials --resource-group "$CLUSTER_NAME-rg" --name "$CLUSTER_NAME"
      ;;
  esac
  
  # Test connection
  if kubectl cluster-info >/dev/null 2>&1; then
    log_success "kubectl configured successfully"
  else
    log_error "Failed to configure kubectl"
    exit 1
  fi
}

# Install essential cluster components
install_cluster_components() {
  log_info "Installing essential cluster components..."
  
  # Install AWS Load Balancer Controller (for AWS)
  if [ "$CLOUD_PROVIDER" = "aws" ]; then
    log_info "Installing AWS Load Balancer Controller..."
    
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName="$CLUSTER_NAME-eks-$CLUSTER_TYPE" \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller
  fi
  
  # Install NGINX Ingress Controller
  log_info "Installing NGINX Ingress Controller..."
  
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.type=LoadBalancer
  
  # Install cert-manager
  log_info "Installing cert-manager..."
  
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.crds.yaml
  
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version v1.13.1 \
    --set installCRDs=false
  
  # Install metrics-server
  log_info "Installing metrics-server..."
  
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  
  log_success "Essential cluster components installed"
}

# Install monitoring (for production and staging)
install_monitoring() {
  if [ "$CLUSTER_TYPE" = "production" ] || [ "$CLUSTER_TYPE" = "staging" ]; then
    log_info "Installing monitoring stack..."
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --create-namespace \
      --set grafana.adminPassword=admin123 \
      --wait --timeout=10m
    
    log_success "Monitoring stack installed"
  fi
}

# Set up backup (for production)
setup_backup() {
  if [ "$CLUSTER_TYPE" = "production" ]; then
    log_info "Setting up backup solution..."
    
    # Install Velero (backup solution)
    log_info "Velero setup requires manual configuration with cloud storage"
    log_info "Please refer to documentation for Velero installation"
    
    # Create backup namespace
    kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Backup namespace created"
  fi
}

# Verify cluster
verify_cluster() {
  log_info "Verifying cluster deployment..."
  
  # Check cluster info
  kubectl cluster-info
  
  # Check nodes
  kubectl get nodes
  
  # Check system pods
  kubectl get pods --all-namespaces
  
  # Check ingress controller
  kubectl get pods -n ingress-nginx
  
  log_success "Cluster verification completed"
}

# Generate cluster information
generate_cluster_info() {
  log_info "Generating cluster information..."
  
  local info_file="cluster-info-$CLUSTER_NAME.txt"
  
  cat > "$info_file" <<EOF
# Cluster Information
# Generated on $(date)

Cluster Name: $CLUSTER_NAME
Cluster Type: $CLUSTER_TYPE
Cloud Provider: $CLOUD_PROVIDER
Region: $REGION
Kubernetes Version: $KUBERNETES_VERSION
Node Count: $NODE_COUNT
Node Size: $NODE_SIZE

# kubectl Configuration
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME-eks-$CLUSTER_TYPE

# Cluster Access
$(kubectl cluster-info 2>/dev/null || echo "Run kubectl cluster-info after configuring kubectl")

# Nodes
$(kubectl get nodes 2>/dev/null || echo "Configure kubectl to see nodes")

# Ingress Controller LoadBalancer
$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Ingress controller not ready")

# Monitoring (if installed)
$(if [ "$CLUSTER_TYPE" != "development" ]; then echo "Grafana: http://$(kubectl get service -n monitoring prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'use port-forward'):3000"; fi)

EOF
  
  log_success "Cluster information saved to $info_file"
}

# Show post-deployment instructions
show_post_deployment() {
  cat <<EOF

==================================================
Cluster Provisioning Complete!
==================================================

Cluster: $CLUSTER_NAME ($CLUSTER_TYPE)
Cloud Provider: $CLOUD_PROVIDER
Region: $REGION

Next Steps:
1. Verify cluster access: kubectl get nodes
2. Deploy applications: ./scripts/deploy-apps.sh
3. Set up monitoring dashboards
4. Configure backup (production clusters)
5. Import cluster to Rancher (if using Rancher)

Access Information:
- Cluster info saved to: cluster-info-$CLUSTER_NAME.txt
- kubectl context: $CLUSTER_NAME-eks-$CLUSTER_TYPE

Useful Commands:
- View pods: kubectl get pods --all-namespaces
- Port forward Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
- View ingress: kubectl get ingress --all-namespaces

EOF
}

# Main function
main() {
  log_info "Starting cluster provisioning..."
  log_info "Cluster Name: $CLUSTER_NAME"
  log_info "Cluster Type: $CLUSTER_TYPE"
  log_info "Cloud Provider: $CLOUD_PROVIDER"
  log_info "Region: $REGION"
  log_info "Node Count: $NODE_COUNT"
  
  check_prerequisites
  validate_credentials
  generate_terraform_config
  init_terraform
  plan_terraform
  
  # Ask for confirmation before applying
  read -p "Do you want to proceed with cluster creation? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cluster creation cancelled"
    exit 0
  fi
  
  apply_terraform
  configure_kubectl
  install_cluster_components
  install_monitoring
  setup_backup
  verify_cluster
  generate_cluster_info
  show_post_deployment
  
  log_success "Cluster provisioning completed successfully!"
}

# Run main function
main "$@"
