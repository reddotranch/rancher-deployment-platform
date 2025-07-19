# Deployment Guide

This guide provides step-by-step instructions for deploying the Rancher Deployment Platform in various environments.

## Prerequisites

Before deploying, ensure you have the following:

- Docker Engine 20.10+
- Kubernetes cluster 1.24+
- Helm 3.8+
- Terraform 1.6+
- kubectl configured with cluster access
- Node.js 18+ (for development)

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/your-org/rancher-deployment-platform.git
cd rancher-deployment-platform
./scripts/setup.sh
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your configuration
vim .env
```

### 3. Start Development Environment

```bash
./scripts/setup.sh start
```

## Production Deployment

### Step 1: Infrastructure Deployment

1. Configure Terraform variables:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

2. Deploy infrastructure:

```bash
terraform init
terraform plan
terraform apply
```

### Step 2: Configure kubectl

```bash
aws eks update-kubeconfig --region <your-region> --name <cluster-name>
```

### Step 3: Install Required Components

1. Install AWS Load Balancer Controller:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

2. Install Cluster Autoscaler:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

3. Install Prometheus and Grafana:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123
```

### Step 4: Deploy Application

1. Build and push container image:

```bash
docker build -t ghcr.io/your-org/rancher-platform:latest .
docker push ghcr.io/your-org/rancher-platform:latest
```

2. Deploy using Helm:

```bash
helm upgrade --install rancher-app ./helm-charts/rancher-app \
  --namespace production \
  --create-namespace \
  --set environment=production \
  --set image.repository=ghcr.io/your-org/rancher-platform \
  --set image.tag=latest \
  --set replicaCount=3 \
  --wait --timeout=15m
```

## Environment-Specific Configurations

### Staging Environment

```bash
helm upgrade --install rancher-app ./helm-charts/rancher-app \
  --namespace staging \
  --create-namespace \
  --set environment=staging \
  --set replicaCount=2 \
  --set resources.requests.memory=256Mi \
  --set resources.limits.memory=512Mi
```

### Production Environment

```bash
helm upgrade --install rancher-app ./helm-charts/rancher-app \
  --namespace production \
  --create-namespace \
  --set environment=production \
  --set replicaCount=5 \
  --set resources.requests.memory=512Mi \
  --set resources.limits.memory=1Gi \
  --set autoscaling.enabled=true \
  --set autoscaling.maxReplicas=20
```

## CI/CD Pipeline Deployment

The platform includes automated CI/CD pipelines using GitHub Actions.

### Required Secrets

Configure the following secrets in your GitHub repository:

```bash
RANCHER_URL=https://rancher.yourdomain.com
RANCHER_TOKEN=your-rancher-api-token
SLACK_WEBHOOK=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
REGISTRY_TOKEN=your-container-registry-token
```

### Deployment Triggers

- **Staging**: Automatic deployment on push to `develop` branch
- **Production**: Automatic deployment on push to `main` branch
- **Manual**: Use workflow dispatch for on-demand deployments

## Monitoring and Observability

### Accessing Dashboards

After deployment, access the monitoring dashboards:

```bash
# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Application
kubectl port-forward -n production svc/rancher-app 8080:80
```

### Default Dashboards

- **Application Metrics**: Custom dashboard for application-specific metrics
- **Infrastructure**: Node, pod, and cluster metrics
- **Business Metrics**: Custom business logic metrics

## Backup and Recovery

### Velero Setup

1. Install Velero:

```bash
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.7.0 \
  --bucket your-backup-bucket \
  --backup-location-config region=us-west-2 \
  --snapshot-location-config region=us-west-2 \
  --secret-file credentials-velero
```

2. Create backup schedule:

```bash
velero schedule create daily-backup --schedule="0 2 * * *"
```

### Database Backups

For database backups, use the built-in backup job:

```bash
kubectl create job --from=cronjob/backup-job manual-backup-$(date +%Y%m%d)
```

## Scaling

### Horizontal Pod Autoscaling

The application includes HPA configuration:

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### Cluster Autoscaling

Node groups are configured for auto-scaling:

```bash
# Check current nodes
kubectl get nodes

# View autoscaler status
kubectl get events --field-selector source=cluster-autoscaler
```

## Security

### Pod Security Standards

The application enforces restricted pod security standards:

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  readOnlyRootFilesystem: true
```

### Network Policies

Network policies are enabled by default to restrict traffic:

```bash
# View network policies
kubectl get networkpolicies -n production
```

## Troubleshooting

### Common Issues

1. **Pod Startup Issues**:
   ```bash
   kubectl describe pod -l app=rancher-app -n production
   kubectl logs -l app=rancher-app -n production
   ```

2. **Service Discovery Issues**:
   ```bash
   kubectl get endpoints -n production
   kubectl get services -n production
   ```

3. **Resource Constraints**:
   ```bash
   kubectl top pods -n production
   kubectl describe node
   ```

### Health Checks

Monitor application health:

```bash
# Health endpoint
curl http://localhost:8080/health

# Readiness check
curl http://localhost:8080/health/ready

# Metrics
curl http://localhost:8080/metrics
```

## Rollback Procedures

### Application Rollback

```bash
# View deployment history
helm history rancher-app -n production

# Rollback to previous version
helm rollback rancher-app 1 -n production
```

### Infrastructure Rollback

```bash
# Terraform rollback
terraform plan -destroy
terraform apply

# Restore from backup
velero restore create --from-backup daily-backup-20231201
```

## Performance Optimization

### Resource Optimization

1. **CPU and Memory**: Adjust based on actual usage
2. **Storage**: Use appropriate storage classes
3. **Network**: Optimize service mesh configuration

### Caching

Configure Redis for caching:

```yaml
redis:
  enabled: true
  host: elasticache-cluster.region.cache.amazonaws.com
  port: 6379
```

## Maintenance

### Regular Tasks

1. **Update Dependencies**: Monthly security updates
2. **Certificate Renewal**: Automated via cert-manager
3. **Backup Verification**: Weekly restore tests
4. **Performance Review**: Monthly metrics analysis

### Scheduled Maintenance

```bash
# Drain nodes for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Cordon nodes to prevent scheduling
kubectl cordon <node-name>

# Uncordon after maintenance
kubectl uncordon <node-name>
```

## Support and Documentation

- **Issues**: [GitHub Issues](https://github.com/your-org/rancher-deployment-platform/issues)
- **Documentation**: [Project Wiki](https://github.com/your-org/rancher-deployment-platform/wiki)
- **Runbooks**: `/docs/runbooks/`
- **Architecture**: `/docs/architecture.md`
