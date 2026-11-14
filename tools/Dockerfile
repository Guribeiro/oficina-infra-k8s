# Ferramentas usadas por scripts/bringup.sh e scripts/teardown.sh quando não estão
# instaladas na máquina: Terraform, AWS CLI, Node.js (build das Lambdas), kubectl e jq.
FROM hashicorp/terraform:1.13.4

ARG KUBECTL_VERSION=v1.33.5

RUN apk add --no-cache bash aws-cli nodejs npm zip jq git curl \
  && curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  && chmod +x /usr/local/bin/kubectl

ENTRYPOINT ["bash"]
