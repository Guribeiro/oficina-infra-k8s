# Plataforma compartilhada pelos ambientes hml e prd: rede, cluster EKS, registro
# de imagens e o VPC Link do API Gateway (as HTTP APIs ficam na stack environment).
locals {
  cluster_name = "${var.project}-eks"

  tags = {
    Project    = "oficina-mecanica"
    Repository = "oficina-infra-k8s"
    Stack      = "platform"
    ManagedBy  = "terraform"
  }
}

module "network" {
  source = "../../modules/network"

  name         = "${var.project}-vpc"
  cidr         = var.vpc_cidr
  cluster_name = local.cluster_name
}

module "eks" {
  source = "../../modules/eks"

  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  subnet_ids          = module.network.private_subnet_ids
  cluster_role_name   = var.cluster_role_name
  node_role_name      = var.node_role_name
  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
}

module "ecr" {
  source = "../../modules/ecr"

  name = "${var.project}-app"
}

module "cluster_addons" {
  source = "../../modules/cluster-addons"

  cluster_name         = local.cluster_name
  newrelic_license_key = var.newrelic_license_key

  depends_on = [module.eks]
}

module "api_gateway" {
  source = "../../modules/api-gateway"

  name       = "${var.project}-api-gateway"
  vpc_id     = module.network.vpc_id
  vpc_cidr   = module.network.vpc_cidr
  subnet_ids = module.network.private_subnet_ids
}
