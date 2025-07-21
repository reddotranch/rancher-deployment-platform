#!/bin/bash

# Health Check Script for Rancher Deployment Platform
# This script performs comprehensive health checks

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

# Global variables
FAILED_CHECKS=0
TOTAL_CHECKS=0

# Track check results
check_result() {
  local check_name=$1
  local result=$2
  
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  if [ "$result" = "pass" ]; then
    log_success "$check_name: PASS"
  elif [ "$result" = "warning" ]; then
    log_warning "$check_name: WARNING"
  else
    log_error "$check_name: FAIL"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
}

# Check Docker
check_docker() {
  log_info "Checking Docker..."
  
  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      check_result "Docker Service" "pass"
    else
      check_result "Docker Service" "fail"
    fi
  else
    check_result "Docker Installation" "fail"
  fi
}

# Check Kubernetes
check_kubernetes() {
  log_info "Checking Kubernetes..."
  
  if command -v kubectl >/dev/null 2>&1; then
    check_result "kubectl Installation" "pass"
    
    if kubectl cluster-info >/dev/null 2>&1; then
      check_result "Kubernetes Connectivity" "pass"
      
      # Check nodes
      local ready_nodes=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
      local total_nodes=$(kubectl get nodes --no-headers | wc -l)
      
      if [ "$ready_nodes" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
        check_result "Kubernetes Nodes ($ready_nodes/$total_nodes ready)" "pass"
      else
        check_result "Kubernetes Nodes ($ready_nodes/$total_nodes ready)" "warning"
      fi
    else
      check_result "Kubernetes Connectivity" "warning"
    fi
  else
    check_result "kubectl Installation" "warning"
  fi
}

# Check application health
check_application() {
  log_info "Checking application health..."
  
  # Check if application is running locally
  if curl -f -s http://localhost:8080/health >/dev/null 2>&1; then
    check_result "Local Application Health" "pass"
  else
    check_result "Local Application Health" "fail"
  fi
  
  # Check Kubernetes deployments
  local namespaces=("staging" "production")
  
  for namespace in "${namespaces[@]}"; do
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
      local ready_pods=$(kubectl get pods -n "$namespace" --no-headers | grep "Running" | wc -l)
      local total_pods=$(kubectl get pods -n "$namespace" --no-headers | wc -l)
      
      if [ "$total_pods" -gt 0 ]; then
        if [ "$ready_pods" -eq "$total_pods" ]; then
          check_result "$namespace Pods ($ready_pods/$total_pods running)" "pass"
        else
          check_result "$namespace Pods ($ready_pods/$total_pods running)" "warning"
        fi
      else
        check_result "$namespace Environment" "warning"
      fi
    else
      check_result "$namespace Environment" "warning"
    fi
  done
}

# Check services
check_services() {
  log_info "Checking services..."
  
  # Check Docker Compose services
  if [ -f "docker-compose.yml" ]; then
    local running_services=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
    local total_services=$(docker-compose ps --services 2>/dev/null | wc -l)
    
    if [ "$total_services" -gt 0 ]; then
      if [ "$running_services" -eq "$total_services" ]; then
        check_result "Docker Compose Services ($running_services/$total_services running)" "pass"
      else
        check_result "Docker Compose Services ($running_services/$total_services running)" "warning"
      fi
    else
      check_result "Docker Compose Services" "warning"
    fi
  fi
  
  # Check Kubernetes services
  local namespaces=("staging" "production" "monitoring" "ingress-nginx")
  
  for namespace in "${namespaces[@]}"; do
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
      local services=$(kubectl get services -n "$namespace" --no-headers | wc -l)
      if [ "$services" -gt 0 ]; then
        check_result "$namespace Services ($services found)" "pass"
      else
        check_result "$namespace Services" "warning"
      fi
    fi
  done
}

# Check monitoring
check_monitoring() {
  log_info "Checking monitoring..."
  
  # Check Prometheus
  if kubectl get pods -n monitoring --no-headers | grep prometheus >/dev/null 2>&1; then
    local prometheus_pods=$(kubectl get pods -n monitoring --no-headers | grep prometheus | grep Running | wc -l)
    if [ "$prometheus_pods" -gt 0 ]; then
      check_result "Prometheus" "pass"
    else
      check_result "Prometheus" "warning"
    fi
  else
    check_result "Prometheus" "warning"
  fi
  
  # Check Grafana
  if kubectl get pods -n monitoring --no-headers | grep grafana >/dev/null 2>&1; then
    local grafana_pods=$(kubectl get pods -n monitoring --no-headers | grep grafana | grep Running | wc -l)
    if [ "$grafana_pods" -gt 0 ]; then
      check_result "Grafana" "pass"
    else
      check_result "Grafana" "warning"
    fi
  else
    check_result "Grafana" "warning"
  fi
}

# Check networking
check_networking() {
  log_info "Checking networking..."
  
  # Check ingress controller
  if kubectl get pods -n ingress-nginx --no-headers | grep controller >/dev/null 2>&1; then
    local ingress_pods=$(kubectl get pods -n ingress-nginx --no-headers | grep controller | grep Running | wc -l)
    if [ "$ingress_pods" -gt 0 ]; then
      check_result "Ingress Controller" "pass"
    else
      check_result "Ingress Controller" "warning"
    fi
  else
    check_result "Ingress Controller" "warning"
  fi
  
  # Check cert-manager
  if kubectl get pods -n cert-manager --no-headers >/dev/null 2>&1; then
    local cert_manager_pods=$(kubectl get pods -n cert-manager --no-headers | grep Running | wc -l)
    if [ "$cert_manager_pods" -ge 3 ]; then
      check_result "cert-manager" "pass"
    else
      check_result "cert-manager" "warning"
    fi
  else
    check_result "cert-manager" "warning"
  fi
}

# Check security
check_security() {
  log_info "Checking security..."
  
  # Check pod security policies
  local secure_pods=0
  local total_pods=0
  
  for namespace in staging production; do
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
      local namespace_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
      total_pods=$((total_pods + namespace_pods))
      
      # Check if pods are running as non-root (simplified check)
      local non_root_pods=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].spec.securityContext.runAsNonRoot}' 2>/dev/null | grep -o true | wc -l)
      secure_pods=$((secure_pods + non_root_pods))
    fi
  done
  
  if [ "$total_pods" -gt 0 ]; then
    if [ "$secure_pods" -gt 0 ]; then
      check_result "Pod Security ($secure_pods/$total_pods secure)" "pass"
    else
      check_result "Pod Security" "warning"
    fi
  else
    check_result "Pod Security" "warning"
  fi
}

# Check storage
check_storage() {
  log_info "Checking storage..."
  
  # Check persistent volumes
  local pvs=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
  local bound_pvs=$(kubectl get pv --no-headers 2>/dev/null | grep Bound | wc -l)
  
  if [ "$pvs" -gt 0 ]; then
    if [ "$bound_pvs" -eq "$pvs" ]; then
      check_result "Persistent Volumes ($bound_pvs/$pvs bound)" "pass"
    else
      check_result "Persistent Volumes ($bound_pvs/$pvs bound)" "warning"
    fi
  else
    check_result "Persistent Volumes" "warning"
  fi
  
  # Check storage classes
  local storage_classes=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
  if [ "$storage_classes" -gt 0 ]; then
    check_result "Storage Classes ($storage_classes found)" "pass"
  else
    check_result "Storage Classes" "warning"
  fi
}

# Check resource usage
check_resources() {
  log_info "Checking resource usage..."
  
  # Check node resources
  if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
    if kubectl top nodes >/dev/null 2>&1; then
      local high_cpu_nodes=$(kubectl top nodes --no-headers | awk '{print $3}' | sed 's/%//' | awk '$1 > 80' | wc -l)
      local high_memory_nodes=$(kubectl top nodes --no-headers | awk '{print $5}' | sed 's/%//' | awk '$1 > 80' | wc -l)
      
      if [ "$high_cpu_nodes" -eq 0 ] && [ "$high_memory_nodes" -eq 0 ]; then
        check_result "Node Resource Usage" "pass"
      else
        check_result "Node Resource Usage (high usage detected)" "warning"
      fi
    else
      check_result "Node Resource Metrics" "warning"
    fi
  fi
}

# Check backup status
check_backup() {
  log_info "Checking backup status..."
  
  # Check Velero if installed
  if kubectl get namespace velero >/dev/null 2>&1; then
    local velero_pods=$(kubectl get pods -n velero --no-headers | grep Running | wc -l)
    if [ "$velero_pods" -gt 0 ]; then
      check_result "Velero Backup System" "pass"
    else
      check_result "Velero Backup System" "warning"
    fi
  else
    check_result "Backup System" "warning"
  fi
}

# Generate report
generate_report() {
  log_info "Generating health check report..."
  
  local report_file="health-check-report-$(date +%Y%m%d-%H%M%S).txt"
  local passed=$((TOTAL_CHECKS - FAILED_CHECKS))
  
  cat > "$report_file" <<EOF
# Rancher Deployment Platform Health Check Report
# Generated on $(date)

## Summary
Total Checks: $TOTAL_CHECKS
Passed: $passed
Failed: $FAILED_CHECKS
Success Rate: $(( passed * 100 / TOTAL_CHECKS ))%

## System Information
Hostname: $(hostname)
Operating System: $(uname -s)
Kernel Version: $(uname -r)
Architecture: $(uname -m)

## Docker Information
$(docker version --format '{{.Server.Version}}' 2>/dev/null | head -1 || echo "Docker not accessible")

## Kubernetes Information
$(kubectl version --short 2>/dev/null || echo "kubectl not configured")

## Cluster Nodes
$(kubectl get nodes 2>/dev/null || echo "Cluster not accessible")

## Running Pods
$(kubectl get pods --all-namespaces 2>/dev/null || echo "Pods not accessible")

## Services
$(kubectl get services --all-namespaces 2>/dev/null || echo "Services not accessible")

## Recommendations
EOF

  if [ "$FAILED_CHECKS" -gt 0 ]; then
    cat >> "$report_file" <<EOF
- $FAILED_CHECKS checks failed. Review the output above for details.
- Check logs for failed components: kubectl logs <pod-name> -n <namespace>
- Verify resource availability: kubectl describe node
- Check events: kubectl get events --all-namespaces
EOF
  else
    cat >> "$report_file" <<EOF
- All checks passed successfully!
- System is healthy and ready for production use.
- Consider setting up monitoring alerts for proactive monitoring.
EOF
  fi
  
  log_success "Health check report saved to: $report_file"
}

# Show summary
show_summary() {
  local passed=$((TOTAL_CHECKS - FAILED_CHECKS))
  
  echo
  echo "===================================================="
  echo "HEALTH CHECK SUMMARY"
  echo "===================================================="
  echo "Total Checks: $TOTAL_CHECKS"
  echo "Passed: $passed"
  echo "Failed: $FAILED_CHECKS"
  echo "Success Rate: $(( passed * 100 / TOTAL_CHECKS ))%"
  echo "===================================================="
  
  if [ "$FAILED_CHECKS" -eq 0 ]; then
    log_success "All health checks passed! System is healthy."
    return 0
  else
    log_error "$FAILED_CHECKS health checks failed. System needs attention."
    return 1
  fi
}

# Main function
main() {
  log_info "Starting comprehensive health check..."
  
  check_docker
  check_kubernetes
  check_application
  check_services
  check_monitoring
  check_networking
  check_security
  check_storage
  check_resources
  check_backup
  
  generate_report
  show_summary
}

# Run main function
main "$@"
