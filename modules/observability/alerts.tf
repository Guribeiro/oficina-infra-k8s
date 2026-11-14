# Alertas do ambiente. Todas as condições ficam numa política por ambiente; com
# alert_email informado, um workflow envia os incidentes por e-mail.
resource "newrelic_alert_policy" "this" {
  name                = "${local.titulo} - Alertas"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

locals {
  # threshold_occurrences: "all" exige o limite violado durante toda a janela
  # (métricas contínuas); "at_least_once" dispara no primeiro evento (contadores).
  condicoes = merge(
    {
      erro_api = {
        nome        = "Taxa de erro da API acima de ${var.error_rate_threshold}%"
        descricao   = "Percentual de transações com erro na API NestJS (${var.app_name})."
        query       = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE ${local.app}"
        limite      = var.error_rate_threshold
        janela      = 300
        ocorrencias = "all"
      }
      latencia_p95 = {
        nome        = "Latência p95 acima de ${var.latency_p95_threshold}s"
        descricao   = "Percentil 95 da duração das rotas de negócio."
        query       = "SELECT percentile(duration, 95) FROM Transaction WHERE ${local.transacoes}"
        limite      = var.latency_p95_threshold
        janela      = 300
        ocorrencias = "all"
      }
      cpu_pod = {
        nome        = "CPU de pod acima de ${var.cpu_threshold}% do limit"
        descricao   = "Pressão de CPU sustentada; o HPA deveria escalar antes deste ponto."
        query       = "SELECT average(cpuCoresUtilization) FROM K8sContainerSample WHERE ${local.ns} FACET podName"
        limite      = var.cpu_threshold
        janela      = 300
        ocorrencias = "all"
      }
      restart_pod = {
        nome        = "Reinício de container (CrashLoop/OOM)"
        descricao   = "Qualquer reinício de container no namespace ${var.namespace}."
        query       = "SELECT sum(restartCountDelta) FROM K8sContainerSample WHERE ${local.ns} FACET podName"
        limite      = 0
        janela      = 300
        ocorrencias = "at_least_once"
      }
      falha_integracao = {
        nome        = "Falha de integração (e-mail, webhook, eventos de domínio)"
        descricao   = "Evento IntegracaoFalhou registrado pela aplicação."
        query       = "SELECT count(*) FROM IntegracaoFalhou WHERE ${local.app} FACET integracao"
        limite      = 0
        janela      = 300
        ocorrencias = "at_least_once"
      }
      falha_os = {
        nome        = "Erro no processamento de ordens de serviço"
        descricao   = "Exceções nas rotas de ordens de serviço e orçamentos."
        query       = "SELECT count(*) FROM TransactionError WHERE ${local.app} AND (transactionName LIKE '%ordens-servicos%' OR transactionName LIKE '%orcamentos%')"
        limite      = 0
        janela      = 300
        ocorrencias = "at_least_once"
      }
      erro_lambda = {
        nome        = "Erro nas Lambdas de autenticação"
        descricao   = "Exceções não tratadas em ${join(", ", var.lambda_function_names)}."
        query       = "SELECT count(*) FROM AwsLambdaInvocationError WHERE ${local.lambdas} FACET aws.lambda.arn"
        limite      = 0
        janela      = 300
        ocorrencias = "at_least_once"
      }
    },
    local.com_ping ? {
      health_check = {
        nome        = "Health check indisponível (Synthetics)"
        descricao   = "Falha no ping de ${var.health_check_url}."
        query       = "SELECT filter(count(*), WHERE result != 'SUCCESS') FROM SyntheticCheck WHERE ${local.synth} FACET locationLabel"
        limite      = 0
        janela      = 900
        ocorrencias = "at_least_once"
      }
    } : {},
  )
}

resource "newrelic_nrql_alert_condition" "this" {
  for_each = local.condicoes

  policy_id   = newrelic_alert_policy.this.id
  type        = "static"
  name        = "[${var.environment}] ${each.value.nome}"
  description = each.value.descricao
  enabled     = true

  violation_time_limit_seconds = 86400
  aggregation_window           = 60
  aggregation_method           = "event_flow"
  aggregation_delay            = 120

  nrql {
    query = each.value.query
  }

  critical {
    operator              = "above"
    threshold             = each.value.limite
    threshold_duration    = each.value.janela
    threshold_occurrences = each.value.ocorrencias
  }
}

# ---------------------------------------------------------------------------
# Notificação por e-mail (opcional)
# ---------------------------------------------------------------------------
resource "newrelic_notification_destination" "email" {
  count = var.alert_email == "" ? 0 : 1

  name = "${var.project_prefix}-email-${var.environment}"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.alert_email
  }
}

resource "newrelic_notification_channel" "email" {
  count = var.alert_email == "" ? 0 : 1

  name           = "${var.project_prefix}-email-${var.environment}"
  type           = "EMAIL"
  product        = "IINT"
  destination_id = newrelic_notification_destination.email[0].id

  property {
    key   = "subject"
    value = "[${var.environment}] {{ issueTitle }}"
  }
}

resource "newrelic_workflow" "email" {
  count = var.alert_email == "" ? 0 : 1

  name                  = "${local.titulo} - E-mail"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "politica-${var.environment}"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.this.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email[0].id
  }
}
