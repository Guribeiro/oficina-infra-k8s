# Recursos específicos de cada ambiente sobre a plataforma compartilhada: uma HTTP API
# própria (rotas e integrações em HTTP APIs são da API, não do stage), integração
# privada com a API no EKS (NLB interno via VPC Link) e o Lambda Authorizer.
#
# A stack é tolerante à ordem de entrega: o NLB nasce com o primeiro deploy da
# aplicação e a função authorizer com o repositório oficina-lambda-auth. Enquanto
# não existirem, os recursos dependentes não são criados; basta reaplicar depois.
locals {
  api_prefix      = "${var.project}-api"
  authorizer_name = "${var.project}-authorizer-${var.environment}"

  tags = {
    Project     = "oficina-mecanica"
    Repository  = "oficina-infra-k8s"
    Stack       = "environment"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  platform = data.terraform_remote_state.platform.outputs

  nlb_arn        = one(data.aws_lbs.app.arns)
  app_disponivel = local.nlb_arn != null

  authorizer_disponivel = contains(data.aws_lambda_functions.all.function_names, local.authorizer_name)

  # Rotas que não exigem token (o NestJS também não as protege).
  rotas_publicas = toset([
    "POST /api/sessions/sign-in",
    "GET /api/health",
    "GET /api/ordens-servicos/rastreio",
    "POST /api/webhooks/pagamentos",
    "GET /docs",
    "GET /docs/{proxy+}",
  ])
}

data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "oficina-infra-k8s/platform/terraform.tfstate"
    region = var.aws_region
  }
}

# NLB interno criado pelo Service oficina-service (tags definidas no overlay Kustomize da app).
data "aws_lbs" "app" {
  tags = {
    "oficina-app" = "api"
    "oficina-env" = var.environment
  }
}

data "aws_lb_listener" "app" {
  count = local.app_disponivel ? 1 : 0

  load_balancer_arn = local.nlb_arn
  port              = 80
}

data "aws_lambda_functions" "all" {}

data "aws_lambda_function" "authorizer" {
  count = local.authorizer_disponivel ? 1 : 0

  function_name = local.authorizer_name
}

# ---------------------------------------------------------------------------
# HTTP API e stage
# ---------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "this" {
  name          = "${local.api_prefix}-${var.environment}"
  protocol_type = "HTTP"
  description   = "Oficina Mecanica (${var.environment}): autenticacao por CPF (Lambda) e API NestJS no EKS"

  cors_configuration {
    allow_origins  = ["*"]
    allow_methods  = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers  = ["authorization", "content-type", "x-request-id"]
    expose_headers = ["x-request-id"]
    max_age        = 300
  }
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${local.api_prefix}-${var.environment}"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }

  # Access log em JSON: requestId é propagado à API como x-request-id (correlação ponta a ponta).
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      routeKey           = "$context.routeKey"
      path               = "$context.path"
      status             = "$context.status"
      protocol           = "$context.protocol"
      responseLength     = "$context.responseLength"
      responseLatency    = "$context.responseLatency"
      integrationLatency = "$context.integrationLatency"
      integrationStatus  = "$context.integrationStatus"
      integrationError   = "$context.integrationErrorMessage"
      authorizerError    = "$context.authorizer.error"
      principalId        = "$context.authorizer.principalId"
    })
  }
}

# ---------------------------------------------------------------------------
# Lambda Authorizer (função publicada pelo repositório oficina-lambda-auth)
# ---------------------------------------------------------------------------
resource "aws_apigatewayv2_authorizer" "jwt" {
  count = local.authorizer_disponivel ? 1 : 0

  api_id                            = aws_apigatewayv2_api.this.id
  name                              = "${local.authorizer_name}-jwt"
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = data.aws_lambda_function.authorizer[0].invoke_arn
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  identity_sources                  = ["$request.header.Authorization"]
  authorizer_result_ttl_in_seconds  = var.authorizer_cache_ttl
}

resource "aws_lambda_permission" "authorizer" {
  count = local.authorizer_disponivel ? 1 : 0

  statement_id  = "AllowApiGatewayAuthorizer-${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.authorizer[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.jwt[0].id}"
}

# ---------------------------------------------------------------------------
# Integração privada com a API NestJS no EKS
# ---------------------------------------------------------------------------
resource "aws_apigatewayv2_integration" "app" {
  count = local.app_disponivel ? 1 : 0

  api_id                 = aws_apigatewayv2_api.this.id
  description            = "API NestJS (${var.environment}) via VPC Link -> NLB interno"
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = data.aws_lb_listener.app[0].arn
  connection_type        = "VPC_LINK"
  connection_id          = local.platform.vpc_link_id
  payload_format_version = "1.0"
  timeout_milliseconds   = 29000

  # Encaminha o caminho sem o nome do stage e o requestId do gateway como
  # correlation id (lido pelo logger da aplicação).
  request_parameters = {
    "overwrite:path"                = "$request.path"
    "overwrite:header.x-request-id" = "$context.requestId"
  }
}

resource "aws_apigatewayv2_route" "publicas" {
  for_each = local.app_disponivel ? local.rotas_publicas : toset([])

  api_id             = aws_apigatewayv2_api.this.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.app[0].id}"
  authorization_type = "NONE"
}

# Demais rotas da API exigem token JWT (clientes via CPF ou funcionários).
resource "aws_apigatewayv2_route" "protegida" {
  count = local.app_disponivel ? 1 : 0

  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /api/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.app[0].id}"
  authorization_type = local.authorizer_disponivel ? "CUSTOM" : "NONE"
  authorizer_id      = local.authorizer_disponivel ? aws_apigatewayv2_authorizer.jwt[0].id : null
}
