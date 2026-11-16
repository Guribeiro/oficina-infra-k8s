# Passo a passo: iniciar e encerrar uma sessão do AWS Learner Lab

Guia rápido para subir o ambiente completo da Oficina (hml e prd) no início de uma sessão
do Learner Lab e destruí-lo ao final, sem gastar o crédito do laboratório à toa.

> **Por que destruir no fim?** Encerrar a sessão (**End Lab**) só para as instâncias EC2.
> EKS, NAT Gateway, NLBs e RDS continuam ligados e consomem o crédito, cerca de US$ 5 a 7
> por dia com os dois ambientes.

## Pré-requisitos (uma vez)

- Os 4 repositórios clonados lado a lado:
  `oficina-infra-k8s`, `oficina-infra-db`, `oficina-lambda-auth`, `tech-challenge`.
- AWS CLI v2, GitHub CLI (`gh auth login`) e Docker. Terraform, jq, Node.js e kubectl são
  opcionais: sem eles, os scripts usam a imagem `tools/Dockerfile`.
- Perfil `learnerlab` no `~/.aws/config`:
  ```ini
  [profile learnerlab]
  region = us-east-1
  output = json
  ```
- (Opcional) `~/.newrelic.env` com as chaves do New Relic (veja o README, seção
  *Observabilidade*). Sem ele, o ambiente sobe sem New Relic.
- Na primeira sessão de todas: bucket do Terraform state e variável no GitHub:
  ```bash
  AWS_PROFILE=learnerlab ./bootstrap/state.sh
  SET_STATE_BUCKET=true ./bootstrap/github-secrets.sh
  ```

> ⚠️ Use sempre o perfil `learnerlab`. O perfil `default` desta máquina pode apontar para
> outra conta AWS.

## Iniciar a sessão

1. **Ligar o laboratório.** No AWS Academy, abra o Learner Lab e clique em **Start Lab**.
   Espere a bolinha ao lado de "AWS" ficar **verde** (1 a 3 minutos).

2. **Copiar as credenciais.** Clique em **AWS Details** → **AWS CLI: Show** e copie o bloco
   inteiro (começa com `[default]` e tem `aws_access_key_id`, `aws_secret_access_key` e
   `aws_session_token`).

3. **Gravar no perfil `learnerlab`.** No WSL, com o bloco copiado:
   ```bash
   powershell.exe -NoProfile -Command Get-Clipboard | tr -d '\r' \
     | sed 's/^\[default\]/[learnerlab]/' > ~/.aws/credentials
   AWS_PROFILE=learnerlab aws sts get-caller-identity
   ```
   A saída deve mostrar um ARN `assumed-role/voclabs/...`. Fora do WSL, cole o bloco em
   `~/.aws/credentials` trocando `[default]` por `[learnerlab]`.

4. **Atualizar as credenciais no GitHub** (detalhes abaixo):
   ```bash
   cd ~/www/oficina-infra-k8s
   ./bootstrap/github-secrets.sh
   ```

5. **Subir o ambiente** (cerca de 40 minutos):
   ```bash
   ./scripts/bringup.sh                 # plataforma + hml + prd
   ENVS=hml ./scripts/bringup.sh        # ou só homologação (mais rápido e barato)
   ```
   Ao final, o script imprime a URL do API Gateway de cada ambiente e o resultado do smoke
   test (`/api/health` = 200, CPF inválido = 400, sem token = 401). As URLs mudam a cada
   recriação; use-as no Postman (`baseUrl`) e no Swagger (`<URL>/docs`).

6. **Conferir no New Relic** (se configurado): os dashboards *Oficina Mecanica (hml/prd) -
   Operacional* e *- Negocio* são recriados pelo `bringup.sh`.

### Se a sessão expirar no meio do trabalho

A sessão dura cerca de 4 horas (o contador aparece no topo do Learner Lab). Ao expirar, as
credenciais param de funcionar e os pipelines do GitHub falham com erro de autenticação.
Clique em **Start Lab** de novo, repita os passos 2 a 4 e, se algum script estava rodando,
execute-o de novo: `bringup.sh` e `teardown.sh` são idempotentes e continuam de onde pararam.

## Encerrar a sessão

1. **Destruir o ambiente** (cerca de 20 a 30 minutos), ainda com a sessão ativa:
   ```bash
   cd ~/www/oficina-infra-k8s
   ./scripts/teardown.sh                # digite "destruir" para confirmar
   ```
   Ordem por ambiente: Lambdas → API Gateway e New Relic → namespace (remove o NLB) → RDS; por
   fim a plataforma (EKS, ECR, VPC, NAT). Para manter algo no ar:
   ```bash
   ENVS=prd ./scripts/teardown.sh       # destrói só prd e mantém a plataforma e hml
   KEEP_PLATFORM=1 ./scripts/teardown.sh
   ```
   Se falhar no meio (por exemplo, ENIs das Lambdas ainda sendo liberadas pela AWS), espere
   alguns minutos e rode de novo.

2. **Conferir que nada ficou ligado** (deve voltar vazio):
   ```bash
   export AWS_PROFILE=learnerlab
   aws eks list-clusters --query clusters
   aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
   aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
   ```

3. **Encerrar o laboratório.** No Learner Lab, clique em **End Lab**.

O que **permanece** entre sessões: o bucket do Terraform state, as configurações dos
repositórios no GitHub e os dados no New Relic. O que é **perdido**: os dados dos bancos
(recriados pelo seed no próximo `bringup.sh`) e as URLs do API Gateway.

## Sobre o `bootstrap/github-secrets.sh`

Os pipelines dos 4 repositórios acessam a AWS com as credenciais do Learner Lab guardadas
como secrets nos GitHub Environments. Essas credenciais são **temporárias**: mudam a cada
sessão e expiram em cerca de 4 horas. O script copia as credenciais atuais do perfil local
para o GitHub.

**O que ele faz:**

1. Confirma a conta com `aws sts get-caller-identity` e mostra o número dela.
2. Garante que os Environments `homologacao` e `producao` existam nos 4 repositórios
   (`tech-challenge`, `oficina-infra-k8s`, `oficina-infra-db`, `oficina-lambda-auth`).
3. Grava em cada um dos 8 Environments os secrets `AWS_ACCESS_KEY_ID`,
   `AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN`. Os valores vão do arquivo de credenciais
   direto para o `gh`, sem aparecer no terminal.
4. Com `SET_STATE_BUCKET=true`, grava também a variável `TF_STATE_BUCKET`
   (`oficina-tfstate-<conta>`) nos 3 repositórios de infraestrutura. Só é preciso na
   primeira vez: a conta do Learner Lab é a mesma em todas as sessões.

**Quando rodar:** no início de toda sessão (passo 4) e sempre que renovar as credenciais. Se
você só usa os scripts locais (`bringup.sh`/`teardown.sh`), ele não é obrigatório, mas sem
ele qualquer push ou merge dispara pipelines que falham por credencial expirada.

**Variáveis:**

| Variável | Padrão | Uso |
| --- | --- | --- |
| `PROFILE` | `learnerlab` | Perfil AWS de onde as credenciais são lidas |
| `OWNER` | `Guribeiro` | Dono dos repositórios no GitHub |
| `SET_STATE_BUCKET` | `false` | `true` grava também `TF_STATE_BUCKET` |

**Requisitos:** `gh` autenticado com permissão de administração nos repositórios (para
criar Environments e secrets) e o perfil AWS com credenciais válidas.

**Como conferir:**
```bash
gh secret list -R Guribeiro/oficina-infra-k8s -e homologacao
```
A coluna de atualização dos três `AWS_*` deve mostrar o horário de agora.

> As chaves do New Relic não mudam entre sessões e são publicadas uma única vez por
> `bootstrap/github-newrelic.sh` (lê `~/.newrelic.env`).
