variable "cluster_name" {
  description = "Nome do cluster exibido no New Relic"
  type        = string
}

variable "newrelic_license_key" {
  description = "License key (ingest) do New Relic; vazio desativa a integração"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_cluster_logging" {
  description = "Envia logs de todos os containers ao New Relic via DaemonSet (Fluent Bit)"
  type        = bool
  default     = false
}

variable "metrics_server_chart_version" {
  description = "Versão do chart metrics-server"
  type        = string
  default     = "3.12.2"
}

variable "nri_bundle_chart_version" {
  description = "Versão do chart nri-bundle"
  type        = string
  default     = "5.0.140"
}
