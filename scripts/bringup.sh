#!/usr/bin/env bash
# Recria a infraestrutura da Oficina na AWS (nova sessão do Learner Lab ou após o
# scripts/teardown.sh), na mesma ordem do primeiro deploy, e termina com um smoke test.
#
#   ./scripts/bringup.sh                  # plataforma + hml e prd
#   ENVS=hml ./scripts/bringup.sh         # plataforma + só hml
#   SEED=false ./scripts/bringup.sh       # não popular os bancos (padrão: true)
#
# Ordem:
#   1. platform (infra-k8s): VPC, EKS, ECR, VPC Link, add-ons (nri-bundle com a license)
#   2. imagem da aplicação: build do HEAD de tech-challenge e push no ECR (se ausente)
#   Por ambiente:
#   3. banco (oficina-infra-db): RDS e segredos
#   4. aplicação (tech-challenge/scripts/deploy.sh): migrations, seed e NLB interno
#   5. environment (infra-k8s): HTTP API integrada ao NLB
#   6. Lambdas (oficina-lambda-auth): /auth/cpf e authorizer
#   7. environment de novo: anexa o authorizer às rotas protegidas
#   8. smoke test pelo API Gateway
#
# Todos os passos são idempotentes: se algo falhar (ex.: credenciais expiradas), corrija
# e execute de novo. Variáveis: veja scripts/ciclo-comum.sh.
# shellcheck source=scripts/ciclo-comum.sh
source "$(dirname "${BASH_SOURCE[0]}")/ciclo-comum.sh"

validar_ambientes
checar_repositorios
checar_sessao_aws
checar_states_pendentes
carregar_newrelic
preparar_ferramentas
export AUTO_APPROVE=true
export SEED="${SEED:-true}"

if [[ ! -d "$LAMBDA_DIR/node_modules" ]]; then
  etapa "dependências das Lambdas (npm ci)"
  em_repo "$LAMBDA_DIR" npm ci --no-audit --no-fund
fi

etapa "platform (EKS, ECR, VPC) - cerca de 15 minutos na criação"
tf_infra_k8s platform apply

etapa "imagem da aplicação"
command -v docker >/dev/null || erro "Docker é necessário para o build da imagem da aplicação."
export IMAGE_TAG="${IMAGE_TAG:-$(git -C "$APP_DIR" rev-parse --short HEAD)}"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
if aws ecr describe-images --repository-name oficina-app --image-ids "imageTag=$IMAGE_TAG" >/dev/null 2>&1; then
  echo "Imagem oficina-app:$IMAGE_TAG já está no ECR."
else
  [[ -z "$(git -C "$APP_DIR" status --porcelain --untracked-files=no)" ]] \
    || aviso "tech-challenge tem alterações não commitadas; a imagem $IMAGE_TAG não corresponde exatamente ao commit."
  aws ecr get-login-password | docker login -u AWS --password-stdin "$REGISTRY" >/dev/null
  docker build -q --target production -t "$REGISTRY/oficina-app:$IMAGE_TAG" "$APP_DIR" >/dev/null
  docker push -q "$REGISTRY/oficina-app:$IMAGE_TAG" >/dev/null
  echo "Imagem oficina-app:$IMAGE_TAG publicada."
fi

declare -A URLS
for env in $ENVS; do
  etapa "[$env] banco de dados (RDS) - cerca de 8 minutos na criação"
  tf_db "$env" apply

  etapa "[$env] aplicação (migrations, seed=$SEED, NLB)"
  em_repo "$APP_DIR" ./scripts/deploy.sh "$env"

  etapa "[$env] environment (API Gateway)"
  tf_infra_k8s environment "$env" apply

  etapa "[$env] Lambdas de autenticação"
  tf_lambda "$env" apply

  etapa "[$env] environment (authorizer)"
  tf_infra_k8s environment "$env" apply

  URLS[$env]="$(aws apigatewayv2 get-apis \
    --query "Items[?Name=='oficina-api-$env'].ApiEndpoint | [0]" --output text)"
done

etapa "Smoke test pelo API Gateway"
falhas=0
for env in $ENVS; do
  url="${URLS[$env]}"
  saude="$(curl -s -o /dev/null -w '%{http_code}' --retry 6 --retry-delay 10 --retry-all-errors "$url/api/health" || true)"
  cpf_invalido="$(curl -s -o /dev/null -w '%{http_code}' -X POST "$url/auth/cpf" \
    -H 'content-type: application/json' -d '{"cpf":"123"}' || true)"
  sem_token="$(curl -s -o /dev/null -w '%{http_code}' "$url/api/clientes" || true)"
  echo "$env  $url"
  echo "     GET /api/health = $saude (esperado 200) | POST /auth/cpf inválido = $cpf_invalido (400) | GET /api/clientes sem token = $sem_token (401)"
  [[ "$saude" == "200" && "$cpf_invalido" == "400" && "$sem_token" == "401" ]] || falhas=1
done

etapa "Bringup concluído"
echo "Se a sessão do Learner Lab é nova, atualize as credenciais no GitHub:"
echo "  ./bootstrap/github-secrets.sh"
[[ "$falhas" == "0" ]] || erro "Smoke test com falhas; verifique os logs acima."
