#!/usr/bin/env bash
# Funções compartilhadas por scripts/bringup.sh e scripts/teardown.sh (não executar direto).
#
# Os 4 repositórios precisam estar clonados lado a lado:
#   <workspace>/oficina-infra-k8s  <workspace>/oficina-infra-db
#   <workspace>/oficina-lambda-auth  <workspace>/tech-challenge
#
# Variáveis:
#   AWS_PROFILE          perfil da sessão do Learner Lab (padrão: learnerlab)
#   AWS_REGION           padrão us-east-1
#   ENVS                 ambientes, padrão "hml prd"
#   TF_STATE_BUCKET      padrão oficina-tfstate-<account_id>
#   NEWRELIC_ENV_FILE    credenciais New Relic, padrão ~/.newrelic.env (opcional)
#   USE_TOOLS_IMAGE      1 = Terraform/deploy dentro da imagem tools/Dockerfile;
#                        padrão: automático (usa a imagem se terraform/jq/node faltarem)

set -euo pipefail

INFRA_K8S_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$(cd "$INFRA_K8S_DIR/.." && pwd)"
INFRA_DB_DIR="$WORKSPACE/oficina-infra-db"
LAMBDA_DIR="$WORKSPACE/oficina-lambda-auth"
APP_DIR="$WORKSPACE/tech-challenge"

export AWS_PROFILE="${AWS_PROFILE:-learnerlab}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
ENVS="${ENVS:-hml prd}"
NEWRELIC_ENV_FILE="${NEWRELIC_ENV_FILE:-$HOME/.newrelic.env}"
EKS_CLUSTER="${EKS_CLUSTER:-oficina-eks}"
TOOLS_IMAGE="oficina-tools:local"

etapa() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
aviso() { printf '\033[33m[aviso]\033[0m %s\n' "$*" >&2; }
erro() { printf '\033[31m[erro]\033[0m %s\n' "$*" >&2; exit 1; }

validar_ambientes() {
  local env
  for env in $ENVS; do
    [[ "$env" == "hml" || "$env" == "prd" ]] || erro "Ambiente inválido em ENVS: $env"
  done
}

checar_repositorios() {
  local dir
  for dir in "$INFRA_DB_DIR" "$LAMBDA_DIR" "$APP_DIR"; do
    [[ -d "$dir" ]] || erro "Repositório não encontrado: $dir (clone os 4 repositórios lado a lado)"
  done
}

checar_sessao_aws() {
  command -v aws >/dev/null || erro "AWS CLI não instalada."
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" \
    || erro "Credenciais AWS inválidas ou expiradas (perfil $AWS_PROFILE). Renove a sessão do Learner Lab."
  export TF_STATE_BUCKET="${TF_STATE_BUCKET:-oficina-tfstate-${ACCOUNT_ID}}"
  aws s3api head-bucket --bucket "$TF_STATE_BUCKET" >/dev/null 2>&1 \
    || erro "Bucket do state $TF_STATE_BUCKET não existe (rode bootstrap/state.sh)."
  echo "Conta AWS $ACCOUNT_ID | perfil $AWS_PROFILE | state $TF_STATE_BUCKET | ambientes: $ENVS"
}

# Credenciais New Relic (opcionais): sem elas a observabilidade fica desligada.
carregar_newrelic() {
  if [[ ! -r "$NEWRELIC_ENV_FILE" ]]; then
    aviso "$NEWRELIC_ENV_FILE não encontrado: New Relic desativado nesta execução."
    return
  fi
  set -a
  # shellcheck disable=SC1090
  source "$NEWRELIC_ENV_FILE"
  set +a
  export TF_VAR_newrelic_license_key="${NEW_RELIC_LICENSE_KEY:-}"
  export TF_VAR_newrelic_account_id="${NEW_RELIC_ACCOUNT_ID:-}"
  export TF_VAR_newrelic_api_key="${NEW_RELIC_API_KEY:-}"
  export TF_VAR_alert_email="${ALERT_EMAIL:-}"
  export TF_VAR_newrelic_layer_arn="${NEW_RELIC_LAYER_ARN:-arn:aws:lambda:us-east-1:451483290750:layer:NewRelicNodeJS22X:118}"
  echo "New Relic: credenciais carregadas de $NEWRELIC_ENV_FILE"
}

preparar_ferramentas() {
  if [[ -z "${USE_TOOLS_IMAGE:-}" ]]; then
    USE_TOOLS_IMAGE=0
    local cmd
    for cmd in terraform jq node kubectl; do
      command -v "$cmd" >/dev/null || USE_TOOLS_IMAGE=1
    done
  fi
  if [[ "$USE_TOOLS_IMAGE" == "1" ]]; then
    command -v docker >/dev/null || erro "Instale terraform, jq, node e kubectl, ou o Docker para usar a imagem de ferramentas."
    echo "Ferramentas: imagem $TOOLS_IMAGE (tools/Dockerfile)"
    docker build -q -t "$TOOLS_IMAGE" "$INFRA_K8S_DIR/tools" >/dev/null
  else
    echo "Ferramentas: instaladas na máquina"
  fi
}

# Executa um comando dentro do diretório de um repositório, localmente ou na imagem.
#   em_repo <dir> <comando...>
em_repo() {
  local dir="$1"
  shift
  if [[ "$USE_TOOLS_IMAGE" != "1" ]]; then
    (cd "$dir" && "$@")
    return
  fi

  local args=(--rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e TF_IN_AUTOMATION=1
    -v "$WORKSPACE:/workspace" -w "/workspace/${dir#"$WORKSPACE"/}")
  if [[ -d "$HOME/.aws" ]]; then
    args+=(-v "$(readlink -f "$HOME/.aws"):/aws:ro" -e AWS_CONFIG_FILE=/aws/config
      -e AWS_SHARED_CREDENTIALS_FILE=/aws/credentials)
  fi
  local var
  for var in AWS_PROFILE AWS_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
    TF_STATE_BUCKET AUTO_APPROVE IMAGE_TAG SEED NEW_RELIC_LICENSE_KEY \
    TF_VAR_newrelic_license_key TF_VAR_newrelic_account_id TF_VAR_newrelic_api_key \
    TF_VAR_alert_email TF_VAR_newrelic_layer_arn; do
    [[ -n "${!var:-}" ]] && args+=(-e "$var")
  done
  docker run "${args[@]}" "$TOOLS_IMAGE" -c "$(printf '%q ' "$@")"
}

tf_infra_k8s() { em_repo "$INFRA_K8S_DIR" ./scripts/tf.sh "$@"; }
tf_db() { em_repo "$INFRA_DB_DIR" ./scripts/tf.sh "$@"; }
tf_lambda() { em_repo "$LAMBDA_DIR" ./scripts/tf.sh "$@"; }

cluster_existe() {
  aws eks describe-cluster --name "$EKS_CLUSTER" --query cluster.status --output text >/dev/null 2>&1
}

configurar_kubectl() {
  command -v kubectl >/dev/null || return 1
  aws eks update-kubeconfig --name "$EKS_CLUSTER" --region "$AWS_REGION" >/dev/null
}

# NLBs criados pelo Service da aplicação (tags definidas no overlay Kustomize).
nlbs_do_ambiente() {
  local env="$1" arn
  for arn in $(aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn' --output text); do
    aws elbv2 describe-tags --resource-arns "$arn" \
      --query "TagDescriptions[?Tags[?Key=='oficina-env' && Value=='$env']].ResourceArn" --output text
  done
}
