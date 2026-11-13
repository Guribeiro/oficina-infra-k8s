variable "name" {
  description = "Nome da VPC"
  type        = string
}

variable "cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
}

variable "cluster_name" {
  description = "Nome do cluster EKS (usado nas tags de descoberta de subnets)"
  type        = string
}

variable "tags" {
  description = "Tags aplicadas aos recursos"
  type        = map(string)
  default     = {}
}
