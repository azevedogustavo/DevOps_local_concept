#!/usr/bin/env bash
set -euo pipefail

HARBOR_NAMESPACE="harbor"
HARBOR_HOST="harbor.local"
HARBOR_PORT="8080"
HARBOR_ADMIN_PASSWORD="Harbor12345"   # troque em produção

echo "==> Verificando Helm..."
if ! command -v helm &>/dev/null; then
  echo "Erro: Helm não está instalado."
  exit 1
fi

echo "==> Adicionando repositório Helm do Harbor..."
helm repo add harbor https://helm.goharbor.io --force-update
helm repo update

echo "==> Instalando Harbor no namespace '${HARBOR_NAMESPACE}'..."
helm upgrade --install harbor harbor/harbor \
  --namespace "${HARBOR_NAMESPACE}" --create-namespace \
  --set expose.type=ingress \
  --set expose.tls.enabled=false \
  --set expose.ingress.hosts.core="${HARBOR_HOST}" \
  --set expose.ingress.className=traefik \
  --set externalURL="http://${HARBOR_HOST}:${HARBOR_PORT}" \
  --set harborAdminPassword="${HARBOR_ADMIN_PASSWORD}" \
  --wait \
  --timeout 10m

echo "==> Harbor instalado com sucesso!"
if ! grep -qE "^127\.0\.0\.1[[:space:]]+${HARBOR_HOST}(\s|$)" /etc/hosts; then
  echo "127.0.0.1 ${HARBOR_HOST}" | sudo tee -a /etc/hosts >/dev/null
fi
echo "1. Adicionado '127.0.0.1 ${HARBOR_HOST}' ao seu /etc/hosts"
echo "2. Acesse no navegador: http://${HARBOR_HOST}:${HARBOR_PORT} (usuário: admin)"
echo "3. Para 'docker login ${HARBOR_HOST}:${HARBOR_PORT}', adicione '${HARBOR_HOST}:${HARBOR_PORT}' em 'insecure-registries' no Docker."


HARBOR_URL="http://harbor.local:8080/api/v2.0"
ADMIN_USER="admin"
ADMIN_PASS="Harbor12345" # sua senha de admin

# Criar projeto privado chamado "poc"
curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" -X POST "${HARBOR_URL}/projects" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "poc",
    "metadata": {
      "public": "false"
    }
  }'

# Criar as Robot Accounts via API

# Conta de Push (CI/CD) — Permissões de Pull + Push
curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" -X POST "${HARBOR_URL}/robots" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ci-push",
    "description": "CI pipeline - push and pull",
    "level": "project",
    "duration": 30,
    "permissions": [
      {
        "kind": "project",
        "namespace": "poc",
        "access": [
          { "resource": "repository", "action": "pull" },
          { "resource": "repository", "action": "push" }
        ]
      }
    ]
  }'

#Conta de Pull (Cluster/Kubernetes) — Apenas Pull

# 1. Faz a requisição e guarda o JSON na variável RESPONSE
RESPONSE=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" -X POST "${HARBOR_URL}/robots" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "k8s-pull",
    "description": "Kubernetes cluster - pull only",
    "level": "project",
    "duration": 30,
    "permissions": [
      {
        "kind": "project",
        "namespace": "poc",
        "access": [
          { "resource": "repository", "action": "pull" }
        ]
      }
    ]
  }')

# 2. Extrai o usuário e o token usando jq (-r remove as aspas)
ROBOT_USER=$(echo "$RESPONSE" | jq -r '.name')
ROBOT_PASS=$(echo "$RESPONSE" | jq -r '.secret')

# Validação simples para garantir que o Harbor retornou os dados corretamente
#ISSO NÃO É IDENPOTENTE melhoria futura
if [[ -z "$ROBOT_USER" || "$ROBOT_USER" == "null" ]]; then
  echo "Erro ao criar Robot Account. Resposta do Harbor: $RESPONSE"
  exit 1
fi

# 3. Cria (ou atualiza) a Secret no Kubernetes usando as variáveis entre aspas simples/duplas corretamente
kubectl create secret docker-registry harbor-pull-secret \
  --docker-server=harbor.local:8080 \
  --docker-username="$ROBOT_USER" \
  --docker-password="$ROBOT_PASS" \
  --namespace default \
  --dry-run=client -o yaml | kubectl apply -f -