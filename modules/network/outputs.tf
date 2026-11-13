output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR da VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Subnets privadas (nodes EKS, VPC Link, RDS e Lambda)"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Subnets públicas (NAT Gateway)"
  value       = module.vpc.public_subnets
}
