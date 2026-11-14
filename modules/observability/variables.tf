variable "environment" {
  description = "Ambiente (hml ou prd), usado nos nomes de dashboards, políticas e monitores"
  type        = string
}

variable "app_name" {
  description = "Nome da aplicação no APM (NEW_RELIC_APP_NAME do overlay Kustomize)"
  type        = string
}

variable "namespace" {
  description = "Namespace Kubernetes do ambiente"
  type        = string
}

variable "cluster_name" {
  description = "Nome do cluster no New Relic (global.cluster do nri-bundle)"
  type        = string
}

variable "lambda_function_names" {
  description = "Funções Lambda do ambiente (dados chegam pela layer do New Relic)"
  type        = list(string)
}

variable "health_check_enabled" {
  description = "Cria o monitor Synthetics e o alerta de disponibilidade (precisa ser conhecido no plan)"
  type        = bool
  default     = false
}

variable "health_check_url" {
  description = "URL pública do health check (via API Gateway); usada quando health_check_enabled = true"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "E-mail que recebe as notificações dos alertas; vazio mantém só os issues no New Relic"
  type        = string
  default     = ""
}

variable "synthetics_period" {
  description = "Frequência do monitor de disponibilidade"
  type        = string
  default     = "EVERY_15_MINUTES"
}

variable "error_rate_threshold" {
  description = "Taxa de erro (%) das transações que abre incidente"
  type        = number
  default     = 5
}

variable "latency_p95_threshold" {
  description = "Latência p95 (segundos) que abre incidente"
  type        = number
  default     = 1
}

variable "cpu_threshold" {
  description = "Uso de CPU (% do limit do container) que abre incidente"
  type        = number
  default     = 80
}

variable "project_prefix" {
  description = "Prefixo dos nomes dos recursos"
  type        = string
  default     = "oficina"
}
