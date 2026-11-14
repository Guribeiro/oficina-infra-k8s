#!/usr/bin/env bash
# Copia as credenciais temporárias do Learner Lab (perfil AWS local) para os
# GitHub Environments homologacao e producao dos 4 repositórios, sem imprimir os
# valores. Rodar a cada nova sessão do Learner Lab (as credenciais expiram).
#
#   PROFILE=learnerlab ./bootstrap/github-secrets.sh
#
# Com SET_STATE_BUCKET=true, também grava a variável TF_STATE_BUCKET nos
# repositórios de infraestrutura (necessário só na primeira vez).
set -euo pipefail

PROFILE="${PROFILE:-learnerlab}"
OWNER="${OWNER:-Guribeiro}"
REPOS=(tech-challenge oficina-infra-k8s oficina-infra-db oficina-lambda-auth)
INFRA_REPOS=(oficina-infra-k8s oficina-infra-db oficina-lambda-auth)
ENVS=(homologacao producao)

get() { aws configure get "$1" --profile "$PROFILE"; }

ACCOUNT_ID="$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)"
echo "Conta AWS: $ACCOUNT_ID (perfil $PROFILE)"

for repo in "${REPOS[@]}"; do
  for env in "${ENVS[@]}"; do
    gh api -X PUT "repos/$OWNER/$repo/environments/$env" >/dev/null
    get aws_access_key_id | gh secret set AWS_ACCESS_KEY_ID -R "$OWNER/$repo" -e "$env"
    get aws_secret_access_key | gh secret set AWS_SECRET_ACCESS_KEY -R "$OWNER/$repo" -e "$env"
    get aws_session_token | gh secret set AWS_SESSION_TOKEN -R "$OWNER/$repo" -e "$env"
  done
done

if [[ "${SET_STATE_BUCKET:-false}" == "true" ]]; then
  for repo in "${INFRA_REPOS[@]}"; do
    gh variable set TF_STATE_BUCKET -R "$OWNER/$repo" -b "oficina-tfstate-${ACCOUNT_ID}"
  done
fi
