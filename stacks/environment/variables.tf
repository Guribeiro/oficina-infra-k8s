variable "environment" {
  description = "Ambiente (hml ou prd)"
  type        = string

  validation {
    condition     = contains(["hml", "prd"], var.environment)
    error_message = "environment deve ser hml ou prd."
  }
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket" {
  description = "Bucket S3 do Terraform state (TF_VAR_state_bucket)"
  type        = string
}

variable "project" {
  description = "Prefixo dos recursos"
  type        = string
  default     = "oficina"
}

variable "throttling_burst_limit" {
  description = "Burst de requisições por segundo no stage"
  type        = number
  default     = 100
}

variable "throttling_rate_limit" {
  description = "Requisições por segundo sustentadas no stage"
  type        = number
  default     = 50
}

variable "authorizer_cache_ttl" {
  description = "Cache (segundos) das decisões do Lambda Authorizer"
  type        = number
  default     = 300
}

variable "log_retention_days" {
  description = "Retenção dos access logs do API Gateway"
  type        = number
  default     = 14
}
