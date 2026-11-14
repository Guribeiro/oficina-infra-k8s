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

variable "newrelic_account_id" {
  description = "Account ID do New Relic (TF_VAR_newrelic_account_id); vazio desativa dashboards e alertas"
  type        = string
  default     = ""
}

variable "newrelic_api_key" {
  description = "User API key do New Relic, NRAK-... (TF_VAR_newrelic_api_key); vazio desativa dashboards e alertas"
  type        = string
  default     = ""
  sensitive   = true
}

variable "newrelic_region" {
  description = "Região da conta New Relic (US ou EU)"
  type        = string
  default     = "US"
}

variable "alert_email" {
  description = "E-mail que recebe os alertas do ambiente (TF_VAR_alert_email); vazio não envia notificações"
  type        = string
  default     = ""
}
