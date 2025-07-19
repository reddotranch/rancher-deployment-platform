#!/bin/bash

# Install Prerequisites Script for Rancher Deployment Platform
# This script installs all required tools and dependencies

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

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -f /etc/debian_version ]; then
      OS="debian"
    elif [ -f /etc/redhat-release ]; then
      OS="redhat"
    else
      OS="linux"
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  else
    log_error "Unsupported operating system: $OSTYPE"
    exit 1
  fi
  
  log_info "Detected OS: $OS"
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Install Docker
install_docker() {
  if command_exists docker; then
    log_info "Docker is already installed"
    docker --version
    return
  fi
  
  log_info "Installing Docker..."
  
  case $OS in
    "debian")
      sudo apt-get update
      sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo usermod -aG docker $USER
      ;;
    "redhat")
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl start docker
      sudo systemctl enable docker
      sudo usermod -aG docker $USER
      ;;
    "macos")
      if command_exists brew; then
        brew install --cask docker
      else
        log_error "Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
        exit 1
      fi
      ;;
  esac
  
  log_success "Docker installed successfully"
}

# Install kubectl
install_kubectl() {
  if command_exists kubectl; then
    log_info "kubectl is already installed"
    kubectl version --client
    return
  fi
  
  log_info "Installing kubectl..."
  
  case $OS in
    "debian")
      sudo apt-get update
      sudo apt-get install -y apt-transport-https ca-certificates curl
      curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
      echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
      sudo apt-get update
      sudo apt-get install -y kubectl
      ;;
    "redhat")
      cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
      sudo yum install -y kubectl --disableexcludes=kubernetes
      ;;
    "macos")
      if command_exists brew; then
        brew install kubectl
      else
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        sudo install -o root -g wheel -m 0755 kubectl /usr/local/bin/kubectl
      fi
      ;;
    *)
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      ;;
  esac
  
  log_success "kubectl installed successfully"
}

# Install Helm
install_helm() {
  if command_exists helm; then
    log_info "Helm is already installed"
    helm version
    return
  fi
  
  log_info "Installing Helm..."
  
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  
  log_success "Helm installed successfully"
}

# Install Terraform
install_terraform() {
  if command_exists terraform; then
    log_info "Terraform is already installed"
    terraform version
    return
  fi
  
  log_info "Installing Terraform..."
  
  case $OS in
    "debian")
      wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt-get update && sudo apt-get install terraform
      ;;
    "redhat")
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
      sudo yum -y install terraform
      ;;
    "macos")
      if command_exists brew; then
        brew tap hashicorp/tap
        brew install hashicorp/tap/terraform
      else
        log_error "Please install Homebrew first"
        exit 1
      fi
      ;;
    *)
      TERRAFORM_VERSION="1.6.6"
      wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
      unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
      sudo mv terraform /usr/local/bin/
      rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
      ;;
  esac
  
  log_success "Terraform installed successfully"
}

# Install Node.js and npm
install_nodejs() {
  if command_exists node && command_exists npm; then
    log_info "Node.js and npm are already installed"
    node --version
    npm --version
    return
  fi
  
  log_info "Installing Node.js and npm..."
  
  case $OS in
    "debian")
      curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
      sudo apt-get install -y nodejs
      ;;
    "redhat")
      curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
      sudo yum install -y nodejs npm
      ;;
    "macos")
      if command_exists brew; then
        brew install node
      else
        log_error "Please install Homebrew first"
        exit 1
      fi
      ;;
  esac
  
  log_success "Node.js and npm installed successfully"
}

# Install AWS CLI
install_aws_cli() {
  if command_exists aws; then
    log_info "AWS CLI is already installed"
    aws --version
    return
  fi
  
  log_info "Installing AWS CLI..."
  
  case $OS in
    "debian"|"redhat")
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip awscliv2.zip
      sudo ./aws/install
      rm -rf aws awscliv2.zip
      ;;
    "macos")
      if command_exists brew; then
        brew install awscli
      else
        curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
        sudo installer -pkg AWSCLIV2.pkg -target /
        rm AWSCLIV2.pkg
      fi
      ;;
  esac
  
  log_success "AWS CLI installed successfully"
}

# Install additional tools
install_additional_tools() {
  log_info "Installing additional tools..."
  
  # Install jq
  if ! command_exists jq; then
    case $OS in
      "debian")
        sudo apt-get install -y jq
        ;;
      "redhat")
        sudo yum install -y jq
        ;;
      "macos")
        if command_exists brew; then
          brew install jq
        fi
        ;;
    esac
  fi
  
  # Install yq
  if ! command_exists yq; then
    case $OS in
      "debian"|"redhat")
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
        ;;
      "macos")
        if command_exists brew; then
          brew install yq
        fi
        ;;
    esac
  fi
  
  # Install git (if not present)
  if ! command_exists git; then
    case $OS in
      "debian")
        sudo apt-get install -y git
        ;;
      "redhat")
        sudo yum install -y git
        ;;
      "macos")
        if command_exists brew; then
          brew install git
        fi
        ;;
    esac
  fi
  
  log_success "Additional tools installed"
}

# Install Rancher CLI
install_rancher_cli() {
  if command_exists rancher; then
    log_info "Rancher CLI is already installed"
    rancher --version
    return
  fi
  
  log_info "Installing Rancher CLI..."
  
  RANCHER_CLI_VERSION="v2.7.0"
  
  case $OS in
    "debian"|"redhat")
      wget https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz
      tar -xzf rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz
      sudo mv rancher-${RANCHER_CLI_VERSION}/rancher /usr/local/bin/
      rm -rf rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz rancher-${RANCHER_CLI_VERSION}
      ;;
    "macos")
      wget https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-darwin-amd64-${RANCHER_CLI_VERSION}.tar.gz
      tar -xzf rancher-darwin-amd64-${RANCHER_CLI_VERSION}.tar.gz
      sudo mv rancher-${RANCHER_CLI_VERSION}/rancher /usr/local/bin/
      rm -rf rancher-darwin-amd64-${RANCHER_CLI_VERSION}.tar.gz rancher-${RANCHER_CLI_VERSION}
      ;;
  esac
  
  log_success "Rancher CLI installed successfully"
}

# Verify installations
verify_installations() {
  log_info "Verifying installations..."
  
  local tools=("docker" "kubectl" "helm" "terraform" "node" "npm" "aws" "jq" "git" "rancher")
  local failed_tools=()
  
  for tool in "${tools[@]}"; do
    if command_exists "$tool"; then
      log_success "$tool is installed"
    else
      log_error "$tool is not installed"
      failed_tools+=("$tool")
    fi
  done
  
  if [ ${#failed_tools[@]} -eq 0 ]; then
    log_success "All tools are installed successfully!"
  else
    log_error "Failed to install: ${failed_tools[*]}"
    exit 1
  fi
}

# Post-installation setup
post_installation_setup() {
  log_info "Running post-installation setup..."
  
  # Enable Docker service
  if [ "$OS" = "debian" ] || [ "$OS" = "redhat" ]; then
    sudo systemctl enable docker
    sudo systemctl start docker
  fi
  
  # Add user to docker group message
  if ! groups $USER | grep -q docker; then
    log_warning "You may need to log out and back in for Docker group changes to take effect"
    log_warning "Or run: newgrp docker"
  fi
  
  log_success "Post-installation setup completed"
}

# Main function
main() {
  log_info "Starting prerequisites installation..."
  
  detect_os
  
  install_docker
  install_kubectl
  install_helm
  install_terraform
  install_nodejs
  install_aws_cli
  install_additional_tools
  install_rancher_cli
  
  verify_installations
  post_installation_setup
  
  log_success "All prerequisites installed successfully!"
  log_info "You can now run './scripts/setup.sh' to set up the development environment"
}

# Run main function
main "$@"
