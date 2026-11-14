# Observabilidade de um ambiente no New Relic: dashboards operacional e de negócio,
# monitor de disponibilidade (Synthetics) e alertas com notificação por e-mail.
#
# Fontes de dados:
#   - APM (agente Node na API NestJS): Transaction, TransactionError e os eventos
#     customizados OrdemServicoStatusAlterada e IntegracaoFalhou (appName = var.app_name).
#   - Kubernetes (nri-bundle, stack platform): K8sContainerSample, K8sHpaSample.
#   - Lambdas (layer do New Relic, oficina-lambda-auth): AwsLambdaInvocation(Error).
#   - Synthetics: SyntheticCheck do monitor de health check.
locals {
  titulo = "Oficina Mecanica (${var.environment})"

  app      = "appName = '${var.app_name}'"
  ns       = "namespaceName = '${var.namespace}' AND clusterName = '${var.cluster_name}'"
  lambdas  = "(${join(" OR ", [for nome in var.lambda_function_names : "aws.lambda.arn LIKE '%:function:${nome}'"])})"
  monitor  = "${var.project_prefix}-health-${var.environment}"
  synth    = "monitorName = '${local.monitor}'"
  com_ping = var.health_check_url != ""

  # Rotas com regras de negócio (exclui health check e documentação).
  transacoes = "${local.app} AND transactionType = 'Web' AND name NOT LIKE '%health%' AND name NOT LIKE '%docs%'"

  # ---------------------------------------------------------------------------
  # Dashboard operacional
  # ---------------------------------------------------------------------------
  operacional_api = [
    { tipo = "billboard", titulo = "Throughput (rpm)", row = 1, col = 1, w = 3, h = 3,
    query = "FROM Transaction SELECT rate(count(*), 1 minute) AS 'rpm' WHERE ${local.app} SINCE 30 minutes ago COMPARE WITH 1 day ago" },
    { tipo = "billboard", titulo = "Taxa de erro (%)", row = 1, col = 4, w = 3, h = 3,
    query = "FROM Transaction SELECT percentage(count(*), WHERE error IS true) AS 'Erros' WHERE ${local.app} SINCE 30 minutes ago COMPARE WITH 1 day ago" },
    { tipo = "billboard", titulo = "Latência p95 (ms)", row = 1, col = 7, w = 3, h = 3,
    query = "FROM Transaction SELECT percentile(duration * 1000, 95) AS 'p95' WHERE ${local.transacoes} SINCE 30 minutes ago COMPARE WITH 1 day ago" },
    { tipo = "billboard", titulo = "Disponibilidade (Synthetics)", row = 1, col = 10, w = 3, h = 3,
    query = "FROM SyntheticCheck SELECT percentage(count(*), WHERE result = 'SUCCESS') AS 'Uptime' WHERE ${local.synth} SINCE 1 day ago" },
    { tipo = "line", titulo = "Latência p50 / p95 / p99 (ms)", row = 4, col = 1, w = 6, h = 3,
    query = "FROM Transaction SELECT percentile(duration * 1000, 50, 95, 99) WHERE ${local.transacoes} TIMESERIES AUTO" },
    { tipo = "line", titulo = "Throughput e erros por minuto", row = 4, col = 7, w = 6, h = 3,
    query = "FROM Transaction SELECT rate(count(*), 1 minute) AS 'Requisições', rate(filter(count(*), WHERE error IS true), 1 minute) AS 'Erros' WHERE ${local.app} TIMESERIES AUTO" },
    { tipo = "table", titulo = "Latência e erros por rota", row = 7, col = 1, w = 8, h = 4,
    query = "FROM Transaction SELECT count(*) AS 'Chamadas', percentile(duration * 1000, 50) AS 'p50 (ms)', percentile(duration * 1000, 95) AS 'p95 (ms)', percentile(duration * 1000, 99) AS 'p99 (ms)', percentage(count(*), WHERE error IS true) AS 'Erro (%)' WHERE ${local.transacoes} FACET name LIMIT 30" },
    { tipo = "bar", titulo = "Erros por classe", row = 7, col = 9, w = 4, h = 4,
    query = "FROM TransactionError SELECT count(*) WHERE ${local.app} FACET error.class, transactionName LIMIT 10" },
  ]

  operacional_k8s = [
    { tipo = "line", titulo = "CPU por pod (% do limit)", row = 1, col = 1, w = 6, h = 3,
    query = "FROM K8sContainerSample SELECT average(cpuCoresUtilization) WHERE ${local.ns} FACET podName TIMESERIES AUTO" },
    { tipo = "line", titulo = "Memória por pod (MiB)", row = 1, col = 7, w = 6, h = 3,
    query = "FROM K8sContainerSample SELECT average(memoryWorkingSetBytes) / 1048576 AS 'MiB' WHERE ${local.ns} FACET podName TIMESERIES AUTO" },
    { tipo = "line", titulo = "Réplicas do HPA", row = 4, col = 1, w = 6, h = 3,
    query = "FROM K8sHpaSample SELECT latest(currentReplicas) AS 'Atuais', latest(desiredReplicas) AS 'Desejadas', latest(maxReplicas) AS 'Máximo' WHERE ${local.ns} TIMESERIES AUTO" },
    { tipo = "line", titulo = "CPU e memória dos nós (%)", row = 4, col = 7, w = 6, h = 3,
    query = "FROM K8sNodeSample SELECT average(allocatableCpuCoresUtilization) AS 'CPU', average(allocatableMemoryUtilization) AS 'Memória' WHERE clusterName = '${var.cluster_name}' FACET nodeName TIMESERIES AUTO" },
    { tipo = "bar", titulo = "Reinícios de containers (24h)", row = 7, col = 1, w = 6, h = 3,
    query = "FROM K8sContainerSample SELECT sum(restartCountDelta) WHERE ${local.ns} FACET podName SINCE 1 day ago" },
    { tipo = "table", titulo = "Pods do ambiente", row = 7, col = 7, w = 6, h = 3,
    query = "FROM K8sPodSample SELECT latest(status) AS 'Status', latest(isReady) AS 'Ready', latest(nodeName) AS 'Nó' WHERE ${local.ns} FACET podName SINCE 10 minutes ago" },
  ]

  operacional_auth = [
    { tipo = "line", titulo = "Invocações por função", row = 1, col = 1, w = 6, h = 3,
    query = "FROM AwsLambdaInvocation SELECT count(*) WHERE ${local.lambdas} FACET aws.lambda.arn TIMESERIES AUTO" },
    { tipo = "line", titulo = "Duração p95 por função (ms)", row = 1, col = 7, w = 6, h = 3,
    query = "FROM AwsLambdaInvocation SELECT percentile(duration * 1000, 95) WHERE ${local.lambdas} FACET aws.lambda.arn TIMESERIES AUTO" },
    { tipo = "line", titulo = "Erros por função", row = 4, col = 1, w = 6, h = 3,
    query = "FROM AwsLambdaInvocationError SELECT count(*) WHERE ${local.lambdas} FACET aws.lambda.arn TIMESERIES AUTO" },
    { tipo = "line", titulo = "Health check: duração (ms)", row = 4, col = 7, w = 6, h = 3,
    query = "FROM SyntheticCheck SELECT average(duration) WHERE ${local.synth} FACET locationLabel TIMESERIES AUTO" },
  ]

  # ---------------------------------------------------------------------------
  # Dashboard de negócio
  # ---------------------------------------------------------------------------
  os_evento = "FROM OrdemServicoStatusAlterada"
  negocio = [
    { tipo = "billboard", titulo = "OS recebidas hoje", row = 1, col = 1, w = 3, h = 3,
    query = "${local.os_evento} SELECT count(*) AS 'OS' WHERE ${local.app} AND statusNovo = 'RECEBIDA' SINCE today COMPARE WITH 1 week ago" },
    { tipo = "billboard", titulo = "OS entregues hoje", row = 1, col = 4, w = 3, h = 3,
    query = "${local.os_evento} SELECT count(*) AS 'OS' WHERE ${local.app} AND statusNovo = 'ENTREGUE' SINCE today COMPARE WITH 1 week ago" },
    { tipo = "billboard", titulo = "Tempo médio por etapa (min)", row = 1, col = 7, w = 6, h = 3,
    query = "${local.os_evento} SELECT average(duracaoNoStatusAnteriorSeg) / 60 AS 'min' WHERE ${local.app} AND statusAnterior IN ('EM_DIAGNOSTICO', 'EM_EXECUCAO', 'FINALIZADA') FACET statusAnterior SINCE 7 days ago" },
    { tipo = "bar", titulo = "Volume diário de OS recebidas", row = 4, col = 1, w = 6, h = 3,
    query = "${local.os_evento} SELECT count(*) AS 'OS' WHERE ${local.app} AND statusNovo = 'RECEBIDA' FACET dateOf(timestamp) SINCE 30 days ago LIMIT 31" },
    { tipo = "bar", titulo = "Tempo médio em cada status (min, 7 dias)", row = 4, col = 7, w = 6, h = 3,
    query = "${local.os_evento} SELECT average(duracaoNoStatusAnteriorSeg) / 60 AS 'min' WHERE ${local.app} AND statusAnterior IS NOT NULL FACET statusAnterior SINCE 7 days ago" },
    { tipo = "line", titulo = "Transições de status por hora", row = 7, col = 1, w = 6, h = 3,
    query = "${local.os_evento} SELECT count(*) WHERE ${local.app} FACET statusNovo TIMESERIES 1 hour SINCE 1 day ago" },
    { tipo = "line", titulo = "Falhas de integração", row = 7, col = 7, w = 6, h = 3,
    query = "FROM IntegracaoFalhou SELECT count(*) WHERE ${local.app} FACET integracao, operacao TIMESERIES AUTO SINCE 1 day ago" },
    { tipo = "table", titulo = "Últimas falhas de integração", row = 10, col = 1, w = 8, h = 3,
    query = "FROM IntegracaoFalhou SELECT timestamp, integracao, operacao, erro WHERE ${local.app} SINCE 1 day ago LIMIT 50" },
    { tipo = "billboard", titulo = "Erros nas Lambdas de autenticação (24h)", row = 10, col = 9, w = 4, h = 3,
    query = "FROM AwsLambdaInvocationError SELECT count(*) AS 'Erros' WHERE ${local.lambdas} SINCE 1 day ago" },
  ]

  paginas_operacional = {
    "API (APM)"                      = local.operacional_api
    "Kubernetes (${var.namespace})"  = local.operacional_k8s
    "Autenticação e disponibilidade" = local.operacional_auth
  }
}

resource "newrelic_one_dashboard" "operacional" {
  name        = "${local.titulo} - Operacional"
  permissions = "public_read_only"

  dynamic "page" {
    for_each = local.paginas_operacional

    content {
      name = page.key

      dynamic "widget_billboard" {
        for_each = [for w in page.value : w if w.tipo == "billboard"]
        content {
          title  = widget_billboard.value.titulo
          row    = widget_billboard.value.row
          column = widget_billboard.value.col
          width  = widget_billboard.value.w
          height = widget_billboard.value.h
          nrql_query {
            query = widget_billboard.value.query
          }
        }
      }

      dynamic "widget_line" {
        for_each = [for w in page.value : w if w.tipo == "line"]
        content {
          title  = widget_line.value.titulo
          row    = widget_line.value.row
          column = widget_line.value.col
          width  = widget_line.value.w
          height = widget_line.value.h
          nrql_query {
            query = widget_line.value.query
          }
        }
      }

      dynamic "widget_bar" {
        for_each = [for w in page.value : w if w.tipo == "bar"]
        content {
          title  = widget_bar.value.titulo
          row    = widget_bar.value.row
          column = widget_bar.value.col
          width  = widget_bar.value.w
          height = widget_bar.value.h
          nrql_query {
            query = widget_bar.value.query
          }
        }
      }

      dynamic "widget_table" {
        for_each = [for w in page.value : w if w.tipo == "table"]
        content {
          title  = widget_table.value.titulo
          row    = widget_table.value.row
          column = widget_table.value.col
          width  = widget_table.value.w
          height = widget_table.value.h
          nrql_query {
            query = widget_table.value.query
          }
        }
      }
    }
  }
}

resource "newrelic_one_dashboard" "negocio" {
  name        = "${local.titulo} - Negocio"
  permissions = "public_read_only"

  page {
    name = "Ordens de serviço"

    dynamic "widget_billboard" {
      for_each = [for w in local.negocio : w if w.tipo == "billboard"]
      content {
        title  = widget_billboard.value.titulo
        row    = widget_billboard.value.row
        column = widget_billboard.value.col
        width  = widget_billboard.value.w
        height = widget_billboard.value.h
        nrql_query {
          query = widget_billboard.value.query
        }
      }
    }

    dynamic "widget_line" {
      for_each = [for w in local.negocio : w if w.tipo == "line"]
      content {
        title  = widget_line.value.titulo
        row    = widget_line.value.row
        column = widget_line.value.col
        width  = widget_line.value.w
        height = widget_line.value.h
        nrql_query {
          query = widget_line.value.query
        }
      }
    }

    dynamic "widget_bar" {
      for_each = [for w in local.negocio : w if w.tipo == "bar"]
      content {
        title  = widget_bar.value.titulo
        row    = widget_bar.value.row
        column = widget_bar.value.col
        width  = widget_bar.value.w
        height = widget_bar.value.h
        nrql_query {
          query = widget_bar.value.query
        }
      }
    }

    dynamic "widget_table" {
      for_each = [for w in local.negocio : w if w.tipo == "table"]
      content {
        title  = widget_table.value.titulo
        row    = widget_table.value.row
        column = widget_table.value.col
        width  = widget_table.value.w
        height = widget_table.value.h
        nrql_query {
          query = widget_table.value.query
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Disponibilidade: ping no health check público (API Gateway -> NLB -> pods).
# Monitores do tipo ping não consomem a cota de checks do plano gratuito.
# ---------------------------------------------------------------------------
resource "newrelic_synthetics_monitor" "health" {
  count = local.com_ping ? 1 : 0

  name             = local.monitor
  type             = "SIMPLE"
  status           = "ENABLED"
  period           = var.synthetics_period
  uri              = var.health_check_url
  locations_public = ["US_EAST_1", "SA_EAST_1"]

  verify_ssl                = true
  treat_redirect_as_failure = true
  validation_string         = "\"status\":\"ok\""
}
