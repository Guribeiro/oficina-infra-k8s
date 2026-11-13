variable "name" {
  description = "Nome do repositório ECR"
  type        = string
}

variable "max_images" {
  description = "Quantidade de imagens mantidas pela lifecycle policy"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags aplicadas aos recursos"
  type        = map(string)
  default     = {}
}
