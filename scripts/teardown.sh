#!/usr/bin/env bash
# Destrói a infraestrutura da Oficina na AWS ao fim de uma sessão do Learner Lab,
# na ordem que evita dependências presas (o EKS, o NAT, os NLBs e os RDS consomem o
# orçamento mesmo com o lab encerrado).
#
#   ./scripts/teardown.sh                 # hml e prd + plataforma (pede confirmação)
#   ENVS=prd ./scripts/teardown.sh        # só prd; a plataforma é mantida
#   YES=1 ./scripts/teardown.sh           # sem confirmação interativa
#
# Por ambiente:
#   1. Lambdas (oficina-lambda-auth): lê os outputs da environment, por isso sai antes dela
#   2. environment (infra-k8s): HTTP API, rotas, authorizer e observabilidade New Relic
#   3. namespace oficina-<env>: remove o Service e, com ele, o NLB criado pelo Kubernetes
#   4. banco (oficina-infra-db): RDS e segredos (os dados são perdidos)
# Por fim, se todos os ambientes foram destruídos: platform (EKS, ECR, VPC, NAT).
#
# Mantidos: bucket do Terraform state (bootstrap/state.sh) e as credenciais no GitHub.
# Para recriar: ./scripts/bringup.sh
#
# Variáveis: veja scripts/ciclo-comum.sh. KEEP_PLATFORM=1 mantém a plataforma.
# shellcheck source=scripts/ciclo-comum.sh
source "$(dirname "${BASH_SOURCE[0]}")/ciclo-comum.sh"

validar_ambientes
checar_repositorios
checar_sessao_aws
checar_states_pendentes

DESTRUIR_PLATAFORMA=0
if [[ "${KEEP_PLATFORM:-0}" != "1" && " $ENVS " == *" hml "* && " $ENVS " == *" prd "* ]]; then
  DESTRUIR_PLATAFORMA=1
fi

echo
echo "Serão DESTRUÍDOS na conta $ACCOUNT_ID:"
for env in $ENVS; do
  echo "  - $env: API Gateway, Lambdas, namespace oficina-$env (NLB), RDS oficina-db-$env e segredos"
done
[[ "$DESTRUIR_PLATAFORMA" == "1" ]] && echo "  - plataforma: EKS $EKS_CLUSTER, ECR (com as imagens), VPC Link, NAT e VPC"
echo "Os dados dos bancos não têm snapshot e serão perdidos."

if [[ "${YES:-0}" != "1" ]]; then
  read -r -p "Digite 'destruir' para continuar: " resposta
  [[ "$resposta" == "destruir" ]] || erro "Cancelado."
fi

carregar_newrelic
[[ -n "${TF_VAR_newrelic_api_key:-}" ]] \
  || aviso "Sem a User key do New Relic, o destroy da environment falha se houver dashboards/alertas no state."
preparar_ferramentas
export AUTO_APPROVE=true

for env in $ENVS; do
  etapa "[$env] Lambdas de autenticação"
  tf_lambda "$env" destroy

  etapa "[$env] environment (API Gateway e observabilidade)"
  tf_infra_k8s environment "$env" destroy

  sleep 15
  remover_log_groups_orfaos "/aws/lambda/oficina-auth-cpf-$env" "/aws/lambda/oficina-authorizer-$env" \
    "/aws/apigateway/oficina-api-$env"

  etapa "[$env] namespace oficina-$env e NLB da aplicação"
  if cluster_existe; then
    em_repo "$INFRA_K8S_DIR" bash -c "aws eks update-kubeconfig --name '$EKS_CLUSTER' --region '$AWS_REGION' >/dev/null \
      && kubectl delete namespace 'oficina-$env' --ignore-not-found --wait=true --timeout=10m"
    for _ in $(seq 1 30); do
      [[ -z "$(nlbs_do_ambiente "$env")" ]] && break
      echo "Aguardando a remoção do NLB de $env..."
      sleep 10
    done
    [[ -z "$(nlbs_do_ambiente "$env")" ]] || aviso "NLB de $env ainda existe; a VPC pode não ser removida."
  else
    echo "Cluster $EKS_CLUSTER não existe; nada a remover."
  fi

  etapa "[$env] banco de dados"
  tf_db "$env" destroy
done

if [[ "$DESTRUIR_PLATAFORMA" == "1" ]]; then
  etapa "platform (EKS, ECR, VPC)"
  # ENIs das Lambdas na VPC podem levar alguns minutos para serem liberadas pela AWS;
  # o provider aguarda, mas se o destroy expirar basta executar o script de novo.
  tf_infra_k8s platform destroy
else
  echo
  echo "Plataforma mantida (ENVS=\"$ENVS\" ou KEEP_PLATFORM=1)."
fi

etapa "Teardown concluído"
echo "Mantidos: bucket $TF_STATE_BUCKET e as configurações do GitHub."
echo "Para recriar: ./scripts/bringup.sh"
