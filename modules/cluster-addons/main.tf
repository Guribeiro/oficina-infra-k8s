# Metrics Server: fornece a API metrics.k8s.io usada pelo HPA da aplicação.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version

  values = [yamlencode({
    args = ["--kubelet-preferred-address-types=InternalIP"]
  })]
}

# New Relic Kubernetes integration: CPU/memória de nodes e pods, eventos do
# cluster e estado dos objetos (kube-state-metrics). Instalado apenas com licença.
resource "helm_release" "newrelic" {
  count = var.newrelic_license_key == "" ? 0 : 1

  name             = "newrelic-bundle"
  namespace        = "newrelic"
  create_namespace = true
  repository       = "https://helm-charts.newrelic.com"
  chart            = "nri-bundle"
  version          = var.nri_bundle_chart_version

  values = [yamlencode({
    global = {
      licenseKey  = var.newrelic_license_key
      cluster     = var.cluster_name
      lowDataMode = true
    }
    "newrelic-infrastructure" = { enabled = true }
    "kube-state-metrics"      = { enabled = true }
    "nri-kube-events"         = { enabled = true }
    "nri-metadata-injection"  = { enabled = true }
    # Logs da aplicação já chegam ao New Relic pelo agente APM (logs in context,
    # correlacionados com traces). O DaemonSet de logs é opcional para evitar duplicidade.
    "newrelic-logging"          = { enabled = var.enable_cluster_logging }
    "newrelic-prometheus-agent" = { enabled = false }
  })]

  depends_on = [helm_release.metrics_server]
}
