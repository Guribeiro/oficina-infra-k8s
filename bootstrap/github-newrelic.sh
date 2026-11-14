#!/usr/bin/env bash
# Publica as credenciais do New Relic nos repositórios (sem imprimir valores).
#
#   ./bootstrap/github-newrelic.sh [arquivo]     # padrão: ~/.newrelic.env
#
# O arquivo (fora do git, chmod 600) contém:
#   NEW_RELIC_ACCOUNT_ID=1234567
#   NEW_RELIC_LICENSE_KEY=...NRAL      (Ingest - License)
#   NEW_RELIC_API_KEY=NRAK-...         (User key)
#   NEW_RELIC_LAYER_ARN=arn:aws:lambda:us-east-1:451483290750:layer:NewRelicNodeJS22X:<versão>  (opcional)
#   ALERT_EMAIL=voce@exemplo.com       (opcional)
#
# Destinos:
#   Secrets dos Environments homologacao/producao
#     NEW_RELIC_LICENSE_KEY -> tech-challenge, oficina-infra-k8s, oficina-lambda-auth
#     NEW_RELIC_API_KEY     -> oficina-infra-k8s (dashboards/alertas), tech-challenge (marcador de deploy)
#   Variables de repositório
#     NEW_RELIC_ACCOUNT_ID  -> oficina-infra-k8s, oficina-lambda-auth
#     NEW_RELIC_LAYER_ARN   -> oficina-lambda-auth
#     ALERT_EMAIL           -> oficina-infra-k8s
set -euo pipefail

ARQUIVO="${1:-$HOME/.newrelic.env}"
OWNER="${OWNER:-Guribeiro}"
ENVS=(homologacao producao)
DEFAULT_LAYER="arn:aws:lambda:us-east-1:451483290750:layer:NewRelicNodeJS22X:118"

[[ -r "$ARQUIVO" ]] || { echo "Arquivo $ARQUIVO não encontrado." >&2; exit 1; }
set -a
# shellcheck disable=SC1090
source "$ARQUIVO"
set +a

: "${NEW_RELIC_ACCOUNT_ID:?defina NEW_RELIC_ACCOUNT_ID em $ARQUIVO}"
: "${NEW_RELIC_LICENSE_KEY:?defina NEW_RELIC_LICENSE_KEY em $ARQUIVO}"
: "${NEW_RELIC_API_KEY:?defina NEW_RELIC_API_KEY em $ARQUIVO}"
NEW_RELIC_LAYER_ARN="${NEW_RELIC_LAYER_ARN:-$DEFAULT_LAYER}"

[[ "$NEW_RELIC_ACCOUNT_ID" =~ ^[0-9]+$ ]] || { echo "NEW_RELIC_ACCOUNT_ID deve ser numérico." >&2; exit 1; }
[[ "$NEW_RELIC_API_KEY" == NRAK-* ]] || { echo "NEW_RELIC_API_KEY deve ser uma User key (NRAK-...)." >&2; exit 1; }
[[ ${#NEW_RELIC_LICENSE_KEY} -eq 40 ]] || { echo "NEW_RELIC_LICENSE_KEY deve ter 40 caracteres (Ingest - License)." >&2; exit 1; }

secret_env() { # repo nome valor
  for env in "${ENVS[@]}"; do
    gh api -X PUT "repos/$OWNER/$1/environments/$env" >/dev/null
    printf '%s' "$3" | gh secret set "$2" -R "$OWNER/$1" -e "$env"
  done
  echo "secret   $2 -> $1 (${ENVS[*]})"
}

variable() { # repo nome valor
  gh variable set "$2" -R "$OWNER/$1" -b "$3"
  echo "variable $2 -> $1"
}

for repo in tech-challenge oficina-infra-k8s oficina-lambda-auth; do
  secret_env "$repo" NEW_RELIC_LICENSE_KEY "$NEW_RELIC_LICENSE_KEY"
done
secret_env oficina-infra-k8s NEW_RELIC_API_KEY "$NEW_RELIC_API_KEY"
secret_env tech-challenge NEW_RELIC_API_KEY "$NEW_RELIC_API_KEY"

variable oficina-infra-k8s NEW_RELIC_ACCOUNT_ID "$NEW_RELIC_ACCOUNT_ID"
variable oficina-lambda-auth NEW_RELIC_ACCOUNT_ID "$NEW_RELIC_ACCOUNT_ID"
variable oficina-lambda-auth NEW_RELIC_LAYER_ARN "$NEW_RELIC_LAYER_ARN"
[[ -n "${ALERT_EMAIL:-}" ]] && variable oficina-infra-k8s ALERT_EMAIL "$ALERT_EMAIL"

echo "Pronto. NEW_RELIC_ENTITY_GUID (marcador de deploy no tech-challenge) é configurado após o primeiro dado do APM."
