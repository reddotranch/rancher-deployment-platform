# Quick Start Guide

Get your Rancher Deployment Platform up and running in minutes!

## 🚀 One-Command Setup

```bash
# Clone and setup (if you haven't already)
cd rancher-deployment-platform

# Install all prerequisites
./scripts/install-prerequisites.sh

# Deploy Rancher server
./scripts/deploy-rancher.sh --mode docker --domain rancher.local

# Access Rancher UI
open https://localhost
```

## 📋 Prerequisites Checklist

- [ ] Ubuntu 20.04+ or similar Linux distribution
- [ ] 8GB+ RAM and 4+ CPU cores
- [ ] 50GB+ free disk space
- [ ] Internet connectivity
- [ ] Sudo privileges

## 🎯 Quick Commands

### Deploy Rancher Server
```bash
# Docker deployment (development)
./scripts/deploy-rancher.sh --mode docker

# Kubernetes deployment (production)
./scripts/deploy-rancher.sh --mode kubernetes --domain rancher.yourdomain.com --email admin@yourdomain.com
```

### Provision Clusters
```bash
# Development cluster
./scripts/provision-clusters.sh --name dev-cluster --type development --nodes 3

# Production cluster  
./scripts/provision-clusters.sh --name prod-cluster --type production --nodes 5
```

### Deploy Applications
```bash
# Sample web app
./scripts/deploy-apps.sh --app sample-web-app --namespace web-apps

# Microservices demo with Helm
./scripts/deploy-apps.sh --app microservices-demo --namespace demo --method helm --monitoring
```

### Monitor and Manage
```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Access Grafana dashboard
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin123)
```

## 🔗 Important URLs

After deployment, access these services:

| Service | URL | Credentials |
|---------|-----|-------------|
| Rancher UI | https://localhost | admin/[check deployment output] |
| Grafana | http://localhost:3000 | admin/admin123 |
| Sample App | https://app.example.com | - |

## 📱 Status Commands

```bash
# Check Rancher server status
docker ps | grep rancher

# Check cluster connectivity
kubectl cluster-info

# View application status
./scripts/deploy-apps.sh --status

# View resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

## 🆘 Quick Troubleshooting

### Rancher Won't Start
```bash
# Check logs
docker logs rancher-server

# Restart services
docker-compose restart
```

### Can't Connect to Cluster
```bash
# Check kubeconfig
kubectl config view
kubectl config current-context

# Reset cluster connection
kubectl config use-context <cluster-name>
```

### Application Not Accessible
```bash
# Check ingress
kubectl get ingress --all-namespaces

# Check services
kubectl get services --all-namespaces

# Port forward for testing
kubectl port-forward -n <namespace> svc/<service> 8080:80
```

## 📚 Next Steps

1. **Explore the UI**: Login to Rancher and explore the cluster management features
2. **Deploy More Apps**: Try deploying your own applications using the provided templates
3. **Set Up Monitoring**: Configure alerts and dashboards in Grafana
4. **Scale Clusters**: Add more nodes or create additional clusters
5. **Security**: Review and implement security policies

## 💡 Tips

- Use `k9s` for a terminal-based Kubernetes dashboard
- Set up aliases: `alias k=kubectl` and `alias r=rancher`
- Keep your kubeconfig organized: `export KUBECONFIG=~/.kube/config:~/.kube/dev-config`
- Monitor resource usage: `watch kubectl top nodes`

## 🆘 Get Help

- 📖 [Full Documentation](docs/installation.md)
- 🐛 [Troubleshooting Guide](docs/troubleshooting.md)
- 💬 [Community Support](https://github.com/rancher/rancher/discussions)
- 📧 [Contact Support](mailto:support@example.com)

---

**Happy Orchestrating! 🎼**
