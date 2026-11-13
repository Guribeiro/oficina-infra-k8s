# Consumidos via terraform_remote_state pela stack environment e pelos repositórios
# oficina-infra-db e oficina-lambda-auth.
output "aws_region" {
  description = "Região AWS"
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID da VPC"
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "CIDR da VPC"
  value       = module.network.vpc_cidr
}

output "private_subnet_ids" {
  description = "Subnets privadas"
  value       = module.network.private_subnet_ids
}

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group dos nodes/control plane (origem liberada no RDS)"
  value       = module.eks.cluster_security_group_id
}

output "ecr_repository_url" {
  description = "Repositório ECR da aplicação"
  value       = module.ecr.repository_url
}

output "vpc_link_id" {
  description = "ID do VPC Link"
  value       = module.api_gateway.vpc_link_id
}

output "newrelic_kubernetes_enabled" {
  description = "Integração New Relic Kubernetes instalada"
  value       = module.cluster_addons.newrelic_enabled
}
