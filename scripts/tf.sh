#!/usr/bin/env bash
# Executa o Terraform de uma stack com o backend S3 correto.
#
#   scripts/tf.sh platform            <plan|apply|destroy|output>
#   scripts/tf.sh environment <hml|prd> <plan|apply|destroy|output>
#
# Variáveis: TF_STATE_BUCKET (obrigatória), AWS_REGION (padrão us-east-1),
# TF_VAR_newrelic_license_key (opcional, stack platform), AUTO_APPROVE=true (CI).
set -euo pipefail

STACK="${1:-}"
case "$STACK" in
  platform)
    ENVIRONMENT=""
    ACTION="${2:-plan}"
    STATE_KEY="oficina-infra-k8s/platform/terraform.tfstate"
    ;;
  environment)
    ENVIRONMENT="${2:-}"
    ACTION="${3:-plan}"
    if [[ "$ENVIRONMENT" != "hml" && "$ENVIRONMENT" != "prd" ]]; then
      echo "Uso: $0 environment <hml|prd> <plan|apply|destroy|output>" >&2
      exit 1
    fi
    STATE_KEY="oficina-infra-k8s/environment/${ENVIRONMENT}/terraform.tfstate"
    export TF_VAR_environment="$ENVIRONMENT"
    ;;
  *)
    echo "Uso: $0 <platform|environment> [hml|prd] <plan|apply|destroy|output>" >&2
    exit 1
    ;;
esac

: "${TF_STATE_BUCKET:?Defina TF_STATE_BUCKET (veja bootstrap/state.sh)}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export TF_VAR_state_bucket="$TF_STATE_BUCKET"
export TF_IN_AUTOMATION=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/stacks/$STACK"

APPROVE=()
[[ "${AUTO_APPROVE:-false}" == "true" ]] && APPROVE=(-auto-approve)

terraform init -input=false -reconfigure \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${STATE_KEY}" \
  -backend-config="region=${AWS_REGION}"

case "$ACTION" in
  plan)    terraform plan -input=false -lock-timeout=5m -out=tfplan ;;
  apply)   terraform apply -input=false -lock-timeout=5m "${APPROVE[@]}" ;;
  destroy) terraform destroy -input=false -lock-timeout=5m "${APPROVE[@]}" ;;
  output)  terraform output ;;
  *)
    echo "Ação inválida: $ACTION" >&2
    exit 1
    ;;
esac
