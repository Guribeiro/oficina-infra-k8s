output "newrelic_enabled" {
  description = "Indica se a integração New Relic Kubernetes foi instalada"
  value       = length(helm_release.newrelic) > 0
}
