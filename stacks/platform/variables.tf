variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixo dos recursos"
  type        = string
  default     = "oficina"
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.40.0.0/16"
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes do EKS"
  type        = string
  default     = "1.33"
}

variable "node_instance_types" {
  description = "Tipos de instância dos nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Mínimo de nodes"
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Nodes desejados na criação"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Máximo de nodes"
  type        = number
  default     = 4
}

variable "cluster_role_name" {
  description = "Role do control plane fornecida pelo Learner Lab"
  type        = string
  default     = "LabEksClusterRole"
}

variable "node_role_name" {
  description = "Role dos nodes fornecida pelo Learner Lab"
  type        = string
  default     = "LabEksNodeRole"
}

variable "newrelic_license_key" {
  description = "License key do New Relic (TF_VAR_newrelic_license_key); vazio desativa a integração K8s"
  type        = string
  default     = ""
  sensitive   = true
}
