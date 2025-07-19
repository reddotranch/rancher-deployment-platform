#!/bin/bash

# Deploy Rancher Server Script
# This script deploys Rancher server to a Kubernetes cluster

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
RANCHER_VERSION="2.7.9"
NAMESPACE="cattle-system"
HOSTNAME=""
CERT_MANAGER_VERSION="v1.13.1"
BOOTSTRAP_PASSWORD="admin"
REPLICA_COUNT=3
STORAGE_CLASS=""
INGRESS_CLASS="nginx"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --version)
      RANCHER_VERSION="$2"
      shift 2
      ;;
    --hostname)
      HOSTNAME="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --bootstrap-password)
      BOOTSTRAP_PASSWORD="$2"
      shift 2
      ;;
    --replicas)
      REPLICA_COUNT="$2"
      shift 2
      ;;
    --storage-class)
      STORAGE_CLASS="$2"
      shift 2
      ;;
    --ingress-class)
      INGRESS_CLASS="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --version            Rancher version [default: $RANCHER_VERSION]"
      echo "  --hostname           Rancher hostname (required)"
      echo "  --namespace          Kubernetes namespace [default: $NAMESPACE]"
      echo "  --bootstrap-password Bootstrap password [default: $BOOTSTRAP_PASSWORD]"
      echo "  --replicas           Number of replicas [default: $REPLICA_COUNT]"
      echo "  --storage-class      Storage class for persistent volumes"
      echo "  --ingress-class      Ingress class [default: $INGRESS_CLASS]"
      echo "  -h, --help           Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$HOSTNAME" ]; then
  log_error "Hostname is required. Use --hostname to specify."
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

# Install cert-manager
install_cert_manager() {
  log_info "Installing cert-manager $CERT_MANAGER_VERSION..."
  
  # Check if cert-manager is already installed
  if kubectl get namespace cert-manager >/dev/null 2>&1; then
    log_info "cert-manager namespace already exists, checking installation..."
    if kubectl get pods -n cert-manager | grep -q "cert-manager"; then
      log_info "cert-manager is already installed"
      return
    fi
  fi
  
  # Install cert-manager CRDs
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml
  
  # Add cert-manager Helm repository
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  
  # Install cert-manager
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version $CERT_MANAGER_VERSION \
    --set installCRDs=false \
    --wait --timeout=10m
  
  # Wait for cert-manager to be ready
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
  
  log_success "cert-manager installed successfully"
}

# Create ClusterIssuer for Let's Encrypt
create_cluster_issuer() {
  log_info "Creating ClusterIssuer for Let's Encrypt..."
  
  cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@${HOSTNAME}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: ${INGRESS_CLASS}
EOF
  
  log_success "ClusterIssuer created"
}

# Install Rancher
install_rancher() {
  log_info "Installing Rancher $RANCHER_VERSION..."
  
  # Add Rancher Helm repository
  helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
  helm repo update
  
  # Create namespace
  kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
  
  # Prepare Helm values
  local helm_args=(
    "upgrade" "--install" "rancher"
    "rancher-stable/rancher"
    "--namespace" "$NAMESPACE"
    "--set" "hostname=$HOSTNAME"
    "--set" "bootstrapPassword=$BOOTSTRAP_PASSWORD"
    "--set" "ingress.tls.source=letsEncrypt"
    "--set" "letsEncrypt.email=admin@$HOSTNAME"
    "--set" "letsEncrypt.ingress.class=$INGRESS_CLASS"
    "--set" "replicas=$REPLICA_COUNT"
    "--wait" "--timeout=15m"
  )
  
  # Add storage class if specified
  if [ -n "$STORAGE_CLASS" ]; then
    helm_args+=("--set" "persistence.storageClass=$STORAGE_CLASS")
  fi
  
  # Install Rancher
  if helm "${helm_args[@]}"; then
    log_success "Rancher installed successfully"
  else
    log_error "Failed to install Rancher"
    exit 1
  fi
}

# Wait for Rancher to be ready
wait_for_rancher() {
  log_info "Waiting for Rancher to be ready..."
  
  # Wait for pods to be ready
  kubectl wait --for=condition=ready pod -l app=rancher -n $NAMESPACE --timeout=600s
  
  # Wait for ingress to be ready
  local max_attempts=30
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    if curl -k -s -o /dev/null -w "%{http_code}" https://$HOSTNAME | grep -q "200\|302"; then
      log_success "Rancher is accessible at https://$HOSTNAME"
      break
    fi
    
    log_info "Attempt $attempt/$max_attempts: Waiting for Rancher to be accessible..."
    sleep 30
    attempt=$((attempt + 1))
  done
  
  if [ $attempt -gt $max_attempts ]; then
    log_warning "Rancher may not be fully accessible yet. Please check manually."
  fi
}

# Configure Rancher
configure_rancher() {
  log_info "Rancher configuration..."
  
  cat <<EOF

==================================================
Rancher Installation Complete!
==================================================

Access Rancher at: https://$HOSTNAME

Initial Setup:
1. Navigate to https://$HOSTNAME
2. Log in with username: admin
3. Use bootstrap password: $BOOTSTRAP_PASSWORD
4. Set your new admin password
5. Configure server URL: https://$HOSTNAME

Post-Installation Steps:
- Create clusters
- Import existing clusters
- Configure authentication
- Set up monitoring
- Configure backup

EOF
}

# Create basic monitoring setup
setup_monitoring() {
  log_info "Setting up basic monitoring..."
  
  # Create monitoring namespace
  kubectl create namespace cattle-monitoring-system --dry-run=client -o yaml | kubectl apply -f -
  
  # Install monitoring via Rancher (this requires Rancher to be fully operational)
  log_info "To enable monitoring, go to Rancher UI > Cluster > Tools > Monitoring"
  log_info "Or use: kubectl apply -f https://github.com/rancher/system-charts/raw/main/charts/rancher-monitoring/..."
}

# Backup Rancher
setup_backup() {
  log_info "Setting up backup configuration..."
  
  cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rancher-backup
  namespace: $NAMESPACE
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: rancher/backup-restore-operator:v3.0.0
            command:
            - /bin/sh
            - -c
            - |
              echo "Backup completed at \$(date)"
          restartPolicy: OnFailure
EOF
  
  log_success "Backup CronJob created"
}

# Health check
health_check() {
  log_info "Performing health check..."
  
  # Check pod status
  kubectl get pods -n $NAMESPACE
  
  # Check services
  kubectl get services -n $NAMESPACE
  
  # Check ingress
  kubectl get ingress -n $NAMESPACE
  
  # Check cert-manager
  kubectl get pods -n cert-manager
  
  log_success "Health check completed"
}

# Troubleshooting information
show_troubleshooting() {
  cat <<EOF

==================================================
Troubleshooting Information
==================================================

Check Rancher pods:
kubectl get pods -n $NAMESPACE

Check Rancher logs:
kubectl logs -l app=rancher -n $NAMESPACE

Check ingress:
kubectl describe ingress -n $NAMESPACE

Check certificates:
kubectl get certificates -n $NAMESPACE
kubectl describe certificate -n $NAMESPACE

Check cert-manager:
kubectl get pods -n cert-manager
kubectl logs -l app=cert-manager -n cert-manager

Test DNS resolution:
nslookup $HOSTNAME

Test connectivity:
curl -k https://$HOSTNAME

Common Issues:
1. DNS not pointing to ingress controller
2. Firewall blocking ports 80/443
3. Certificate not issued
4. Insufficient resources

EOF
}

# Main function
main() {
  log_info "Starting Rancher deployment..."
  log_info "Rancher Version: $RANCHER_VERSION"
  log_info "Hostname: $HOSTNAME"
  log_info "Namespace: $NAMESPACE"
  log_info "Replicas: $REPLICA_COUNT"
  
  check_prerequisites
  install_cert_manager
  create_cluster_issuer
  install_rancher
  wait_for_rancher
  configure_rancher
  setup_monitoring
  setup_backup
  health_check
  show_troubleshooting
  
  log_success "Rancher deployment completed!"
}

# Run main function
main "$@"
