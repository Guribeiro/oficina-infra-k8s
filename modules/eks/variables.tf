variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets privadas do cluster e dos nodes"
  type        = list(string)
}

variable "cluster_role_name" {
  description = "Nome base da role IAM existente do control plane (Learner Lab); aceita prefixo/sufixo gerado pelo lab"
  type        = string
}

variable "node_role_name" {
  description = "Nome base da role IAM existente dos nodes (Learner Lab); aceita prefixo/sufixo gerado pelo lab"
  type        = string
}

variable "node_instance_types" {
  description = "Tipos de instância do node group"
  type        = list(string)
}

variable "node_min_size" {
  description = "Mínimo de nodes"
  type        = number
}

variable "node_desired_size" {
  description = "Quantidade desejada inicial de nodes"
  type        = number
}

variable "node_max_size" {
  description = "Máximo de nodes"
  type        = number
}

variable "tags" {
  description = "Tags aplicadas aos recursos"
  type        = map(string)
  default     = {}
}
