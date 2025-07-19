# Makefile for Rancher Deployment Platform

.PHONY: help setup install build test deploy clean lint format docker-build docker-push terraform-init terraform-plan terraform-apply terraform-destroy helm-lint helm-deploy kubernetes-deploy monitoring-setup backup-setup security-scan docs

# Default target
.DEFAULT_GOAL := help

# Variables
PROJECT_NAME := rancher-deployment-platform
VERSION := $(shell node -p "require('./package.json').version" 2>/dev/null || echo "1.0.0")
REGISTRY := ghcr.io
IMAGE_NAME := $(REGISTRY)/$(PROJECT_NAME)
NAMESPACE_STAGING := staging
NAMESPACE_PROD := production
TERRAFORM_DIR := terraform
HELM_CHART := helm-charts/rancher-app

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

define log_info
	@echo -e "$(BLUE)[INFO]$(NC) $(1)"
endef

define log_success
	@echo -e "$(GREEN)[SUCCESS]$(NC) $(1)"
endef

define log_warning
	@echo -e "$(YELLOW)[WARNING]$(NC) $(1)"
endef

define log_error
	@echo -e "$(RED)[ERROR]$(NC) $(1)"
endef

## Display this help message
help:
	@echo "$(PROJECT_NAME) - Rancher Deployment Platform"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## Complete project setup
setup: ## Setup the complete development environment
	$(call log_info,"Setting up the development environment...")
	@chmod +x scripts/setup.sh
	@./scripts/setup.sh setup
	$(call log_success,"Setup completed!")

## Install dependencies
install: ## Install Node.js dependencies
	$(call log_info,"Installing dependencies...")
	@npm install
	$(call log_success,"Dependencies installed!")

## Build the application
build: ## Build the application
	$(call log_info,"Building application...")
	@npm run build 2>/dev/null || echo "No build script found"
	$(call log_success,"Application built!")

## Run tests
test: ## Run all tests
	$(call log_info,"Running tests...")
	@npm test
	$(call log_success,"Tests completed!")

## Run tests with coverage
test-coverage: ## Run tests with coverage report
	$(call log_info,"Running tests with coverage...")
	@npm run test:coverage
	$(call log_success,"Test coverage completed!")

## Lint code
lint: ## Run linter
	$(call log_info,"Running linter...")
	@npm run lint
	$(call log_success,"Linting completed!")

## Format code
format: ## Format code with prettier
	$(call log_info,"Formatting code...")
	@npm run format
	$(call log_success,"Code formatted!")

## Start development server
dev: ## Start development server
	$(call log_info,"Starting development server...")
	@npm run dev

## Start production server
start: ## Start production server
	$(call log_info,"Starting production server...")
	@npm start

## Build Docker image
docker-build: ## Build Docker image
	$(call log_info,"Building Docker image...")
	@docker build -t $(IMAGE_NAME):$(VERSION) -t $(IMAGE_NAME):latest .
	$(call log_success,"Docker image built: $(IMAGE_NAME):$(VERSION)")

## Push Docker image
docker-push: docker-build ## Push Docker image to registry
	$(call log_info,"Pushing Docker image...")
	@docker push $(IMAGE_NAME):$(VERSION)
	@docker push $(IMAGE_NAME):latest
	$(call log_success,"Docker image pushed!")

## Start development environment with Docker Compose
docker-up: ## Start all services with docker-compose
	$(call log_info,"Starting development environment...")
	@docker-compose up -d
	$(call log_success,"Development environment started!")

## Stop development environment
docker-down: ## Stop all services
	$(call log_info,"Stopping development environment...")
	@docker-compose down
	$(call log_success,"Development environment stopped!")

## View logs from Docker Compose
docker-logs: ## View logs from all services
	@docker-compose logs -f

## Initialize Terraform
terraform-init: ## Initialize Terraform
	$(call log_info,"Initializing Terraform...")
	@cd $(TERRAFORM_DIR) && terraform init
	$(call log_success,"Terraform initialized!")

## Plan Terraform deployment
terraform-plan: ## Plan Terraform deployment
	$(call log_info,"Planning Terraform deployment...")
	@cd $(TERRAFORM_DIR) && terraform plan
	$(call log_success,"Terraform plan completed!")

## Apply Terraform configuration
terraform-apply: ## Apply Terraform configuration
	$(call log_info,"Applying Terraform configuration...")
	@cd $(TERRAFORM_DIR) && terraform apply
	$(call log_success,"Terraform applied!")

## Destroy Terraform infrastructure
terraform-destroy: ## Destroy Terraform infrastructure
	$(call log_warning,"This will destroy all infrastructure!")
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@cd $(TERRAFORM_DIR) && terraform destroy
	$(call log_success,"Infrastructure destroyed!")

## Validate Terraform
terraform-validate: ## Validate Terraform configuration
	$(call log_info,"Validating Terraform...")
	@cd $(TERRAFORM_DIR) && terraform validate
	$(call log_success,"Terraform validation completed!")

## Lint Helm chart
helm-lint: ## Lint Helm chart
	$(call log_info,"Linting Helm chart...")
	@helm lint $(HELM_CHART)
	$(call log_success,"Helm chart linted!")

## Template Helm chart
helm-template: ## Generate Kubernetes manifests from Helm chart
	$(call log_info,"Templating Helm chart...")
	@helm template rancher-app $(HELM_CHART) --output-dir ./generated-manifests
	$(call log_success,"Helm templates generated!")

## Deploy to staging using Helm
helm-deploy-staging: ## Deploy to staging environment
	$(call log_info,"Deploying to staging...")
	@helm upgrade --install rancher-app $(HELM_CHART) \
		--namespace $(NAMESPACE_STAGING) \
		--create-namespace \
		--set environment=staging \
		--set image.repository=$(IMAGE_NAME) \
		--set image.tag=$(VERSION) \
		--wait --timeout=10m
	$(call log_success,"Deployed to staging!")

## Deploy to production using Helm
helm-deploy-prod: ## Deploy to production environment
	$(call log_info,"Deploying to production...")
	@helm upgrade --install rancher-app $(HELM_CHART) \
		--namespace $(NAMESPACE_PROD) \
		--create-namespace \
		--set environment=production \
		--set image.repository=$(IMAGE_NAME) \
		--set image.tag=$(VERSION) \
		--set replicaCount=3 \
		--wait --timeout=15m
	$(call log_success,"Deployed to production!")

## Get Kubernetes cluster info
k8s-info: ## Get Kubernetes cluster information
	$(call log_info,"Getting cluster information...")
	@kubectl cluster-info
	@kubectl get nodes
	@kubectl get namespaces

## Get application status
k8s-status: ## Get application status in Kubernetes
	$(call log_info,"Getting application status...")
	@echo "Staging Environment:"
	@kubectl get pods,svc,ing -n $(NAMESPACE_STAGING) 2>/dev/null || echo "Staging namespace not found"
	@echo ""
	@echo "Production Environment:"
	@kubectl get pods,svc,ing -n $(NAMESPACE_PROD) 2>/dev/null || echo "Production namespace not found"

## View application logs
k8s-logs: ## View application logs
	@echo "Choose environment:"
	@echo "1) Staging"
	@echo "2) Production"
	@read -p "Enter choice (1-2): " choice; \
	case $$choice in \
		1) kubectl logs -l app.kubernetes.io/name=rancher-app -n $(NAMESPACE_STAGING) -f ;; \
		2) kubectl logs -l app.kubernetes.io/name=rancher-app -n $(NAMESPACE_PROD) -f ;; \
		*) echo "Invalid choice" ;; \
	esac

## Port forward to application
k8s-port-forward: ## Port forward to access application locally
	@echo "Choose environment:"
	@echo "1) Staging"
	@echo "2) Production"
	@read -p "Enter choice (1-2): " choice; \
	case $$choice in \
		1) kubectl port-forward -n $(NAMESPACE_STAGING) svc/rancher-app 8080:80 ;; \
		2) kubectl port-forward -n $(NAMESPACE_PROD) svc/rancher-app 8080:80 ;; \
		*) echo "Invalid choice" ;; \
	esac

## Setup monitoring stack
monitoring-setup: ## Setup Prometheus and Grafana
	$(call log_info,"Setting up monitoring stack...")
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo update
	@helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--create-namespace \
		--set grafana.adminPassword=admin123
	$(call log_success,"Monitoring stack deployed!")

## Run security scan
security-scan: ## Run security scan with Trivy
	$(call log_info,"Running security scan...")
	@docker run --rm -v $(PWD):/workspace \
		aquasec/trivy:latest fs /workspace
	$(call log_success,"Security scan completed!")

## Run security scan on Docker image
security-scan-image: docker-build ## Run security scan on Docker image
	$(call log_info,"Scanning Docker image...")
	@docker run --rm \
		aquasec/trivy:latest image $(IMAGE_NAME):$(VERSION)
	$(call log_success,"Image security scan completed!")

## Setup backup solution
backup-setup: ## Setup Velero backup solution
	$(call log_info,"Setting up backup solution...")
	$(call log_warning,"Please ensure you have configured AWS credentials and S3 bucket")
	@kubectl apply -f https://raw.githubusercontent.com/vmware-tanzu/velero/main/examples/common/00-prereqs.yaml
	$(call log_success,"Backup prerequisites applied!")

## Create manual backup
backup-create: ## Create manual backup
	$(call log_info,"Creating manual backup...")
	@velero backup create manual-backup-$(shell date +%Y%m%d-%H%M%S) --wait
	$(call log_success,"Manual backup created!")

## List backups
backup-list: ## List all backups
	@velero backup get

## Clean up development environment
clean: ## Clean up development environment
	$(call log_info,"Cleaning up...")
	@docker-compose down -v 2>/dev/null || true
	@docker system prune -f
	@rm -rf node_modules/.cache 2>/dev/null || true
	@rm -rf logs/*.log 2>/dev/null || true
	@rm -rf generated-manifests 2>/dev/null || true
	$(call log_success,"Cleanup completed!")

## Generate documentation
docs: ## Generate documentation
	$(call log_info,"Generating documentation...")
	@npm run docs 2>/dev/null || echo "No docs script found"
	$(call log_success,"Documentation generated!")

## Check system health
health-check: ## Perform system health check
	$(call log_info,"Performing health check...")
	@curl -f http://localhost:8080/health 2>/dev/null || echo "Application not accessible"
	@docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "Docker not running"
	@kubectl get pods --all-namespaces 2>/dev/null || echo "Kubernetes not accessible"

## Show project status
status: ## Show overall project status
	$(call log_info,"Project Status:")
	@echo "Version: $(VERSION)"
	@echo "Image: $(IMAGE_NAME):$(VERSION)"
	@echo ""
	@echo "Docker Services:"
	@docker-compose ps 2>/dev/null || echo "Docker Compose not running"
	@echo ""
	@echo "Kubernetes Status:"
	@make k8s-status 2>/dev/null || echo "Kubernetes not accessible"

## Update dependencies
update: ## Update all dependencies
	$(call log_info,"Updating dependencies...")
	@npm update
	@helm repo update
	$(call log_success,"Dependencies updated!")

## Run full CI pipeline locally
ci: lint test security-scan docker-build ## Run complete CI pipeline locally
	$(call log_success,"CI pipeline completed successfully!")

## Prepare for release
release: ci helm-lint terraform-validate ## Prepare for release
	$(call log_info,"Preparing release...")
	@echo "Version: $(VERSION)"
	@echo "Image: $(IMAGE_NAME):$(VERSION)"
	$(call log_success,"Release preparation completed!")
