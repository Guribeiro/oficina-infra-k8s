terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.101"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

# Sem credenciais o provider recebe valores neutros: nenhum recurso New Relic é
# planejado (module.observability com count = 0) e ele nunca chama a API.
provider "newrelic" {
  account_id = local.newrelic_ativo ? tonumber(var.newrelic_account_id) : 0
  api_key    = local.newrelic_ativo ? var.newrelic_api_key : "desativado"
  region     = var.newrelic_region
}
