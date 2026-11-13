data "aws_availability_zones" "available" {
  state = "available"

  # Learner Lab: EKS não aceita us-east-1e para o control plane.
  exclude_names = ["us-east-1e"]
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.name
  cidr = var.cidr

  azs             = local.azs
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, i)]
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, i + 10)]

  # Um único NAT Gateway para reduzir custo (decisão documentada em ADR).
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags exigidas pelo Kubernetes para criar load balancers nas subnets corretas.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = var.tags
}
