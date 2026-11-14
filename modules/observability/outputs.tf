output "dashboard_operacional_url" {
  description = "Link do dashboard operacional"
  value       = newrelic_one_dashboard.operacional.permalink
}

output "dashboard_negocio_url" {
  description = "Link do dashboard de negócio"
  value       = newrelic_one_dashboard.negocio.permalink
}

output "alert_policy_id" {
  description = "ID da política de alertas do ambiente"
  value       = newrelic_alert_policy.this.id
}
