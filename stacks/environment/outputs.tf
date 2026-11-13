# Consumidos pelo repositório oficina-lambda-auth (rota POST /auth/cpf) via terraform_remote_state.
output "api_id" {
  description = "ID da HTTP API do ambiente"
  value       = aws_apigatewayv2_api.this.id
}

output "api_execution_arn" {
  description = "ARN de execução (permissões de invocação das Lambdas)"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "invoke_url" {
  description = "URL base do ambiente no API Gateway"
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "app_integrada" {
  description = "Integração com o NLB da aplicação criada (false até o primeiro deploy da app)"
  value       = local.app_disponivel
}

output "authorizer_ativo" {
  description = "Lambda Authorizer anexado às rotas protegidas (false até o deploy da Lambda)"
  value       = local.authorizer_disponivel
}
