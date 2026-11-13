variable "name" {
  description = "Prefixo dos recursos do VPC Link"
  type        = string
}

variable "vpc_id" {
  description = "VPC do VPC Link"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC (destino permitido a partir do VPC Link)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets privadas do VPC Link"
  type        = list(string)
}

variable "tags" {
  description = "Tags aplicadas aos recursos"
  type        = map(string)
  default     = {}
}
