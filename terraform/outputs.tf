# Outputs for Rancher Deployment Platform

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

# EKS Cluster Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = aws_eks_cluster.main.status
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Node Group Outputs
output "node_group_arn" {
  description = "EKS node group ARN"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "EKS node group status"
  value       = aws_eks_node_group.main.status
}

output "node_group_capacity_type" {
  description = "Type of capacity associated with the EKS Node Group"
  value       = aws_eks_node_group.main.capacity_type
}

output "node_group_instance_types" {
  description = "Set of instance types associated with the EKS Node Group"
  value       = aws_eks_node_group.main.instance_types
}

# Security Group Outputs
output "rancher_server_security_group_id" {
  description = "ID of the Rancher server security group"
  value       = aws_security_group.rancher_server.id
}

output "worker_nodes_security_group_id" {
  description = "ID of the worker nodes security group"
  value       = aws_security_group.worker_nodes.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

# Load Balancer Outputs
output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Canonical hosted zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = var.create_rds ? aws_db_instance.main[0].endpoint : null
}

output "rds_port" {
  description = "RDS instance port"
  value       = var.create_rds ? aws_db_instance.main[0].port : null
}

output "rds_database_name" {
  description = "RDS database name"
  value       = var.create_rds ? aws_db_instance.main[0].db_name : null
}

output "rds_username" {
  description = "RDS database username"
  value       = var.create_rds ? aws_db_instance.main[0].username : null
  sensitive   = true
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = var.create_rds ? aws_security_group.rds[0].id : null
}

# KMS Key Outputs
output "eks_kms_key_id" {
  description = "KMS key ID for EKS encryption"
  value       = aws_kms_key.eks.key_id
}

output "eks_kms_key_arn" {
  description = "KMS key ARN for EKS encryption"
  value       = aws_kms_key.eks.arn
}

output "rds_kms_key_id" {
  description = "KMS key ID for RDS encryption"
  value       = var.create_rds ? aws_kms_key.rds[0].key_id : null
}

output "rds_kms_key_arn" {
  description = "KMS key ARN for RDS encryption"
  value       = var.create_rds ? aws_kms_key.rds[0].arn : null
}

# CloudWatch Outputs
output "eks_cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for EKS"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "eks_cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for EKS"
  value       = aws_cloudwatch_log_group.eks_cluster.arn
}

# IAM Role Outputs
output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster service role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group role"
  value       = aws_iam_role.eks_node_group.arn
}

# Configuration Commands
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "rancher_url" {
  description = "URL to access Rancher (after installation)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "https://${aws_lb.main.dns_name}"
}

# Environment Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# Resource Tags
output "common_tags" {
  description = "Common tags applied to resources"
  value = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.project_owner
  }
}

# Monitoring URLs (conditional)
output "grafana_url" {
  description = "URL to access Grafana (if enabled)"
  value       = var.enable_monitoring ? (var.domain_name != "" ? "https://grafana.${var.domain_name}" : "https://grafana.${aws_lb.main.dns_name}") : null
}

output "prometheus_url" {
  description = "URL to access Prometheus (if enabled)"
  value       = var.enable_monitoring ? (var.domain_name != "" ? "https://prometheus.${var.domain_name}" : "https://prometheus.${aws_lb.main.dns_name}") : null
}

# Backup Information
output "velero_s3_bucket" {
  description = "S3 bucket for Velero backups (if enabled)"
  value       = var.enable_velero ? var.velero_s3_bucket : null
}

# Network Information
output "availability_zones" {
  description = "Availability zones used"
  value       = data.aws_availability_zones.available.names
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = aws_route_table.private[*].id
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost (approximate)"
  value       = "Please use AWS Cost Calculator for accurate estimates"
}

# Security Information
output "ssl_certificate_arn" {
  description = "SSL certificate ARN (if provided)"
  value       = var.ssl_certificate_arn
}

# Deployment Information
output "deployment_timestamp" {
  description = "Timestamp of deployment"
  value       = timestamp()
}