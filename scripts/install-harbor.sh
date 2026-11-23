#!/usr/bin/env bash
set -euo pipefail

HARBOR_NAMESPACE="harbor"
HARBOR_HOST="harbor.local"
HARBOR_PORT="8080"
ADMIN_USER="admin"
HARBOR_ADMIN_PASSWORD="Harbor12345"   # troque em produção
REGISTRY="${HARBOR_HOST}:${HARBOR_PORT}"
DAEMON_JSON="/etc/docker/daemon.json"
HARBOR_URL="http://${HARBOR_HOST}:${HARBOR_PORT}/api/v2.0"

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
  --set internalTLS.enabled=false \
  --set expose.ingress.hosts.core="${HARBOR_HOST}" \
  --set expose.ingress.className=traefik \
  --set expose.ingress.annotations."traefik\.ingress\.kubernetes\.io/router\.entrypoints"=web \
  --set externalURL="http://${HARBOR_HOST}:${HARBOR_PORT}" \
  --set harborAdminPassword="${HARBOR_ADMIN_PASSWORD}" \
  --wait \
  --timeout 10m

echo "==> Configurando URLs relativas no Registry para evitar redirect HTTPS no push..."
kubectl set env deployment/harbor-registry -n "${HARBOR_NAMESPACE}" -c registry REGISTRY_HTTP_RELATIVEURLS=true
kubectl set env deployment/harbor-core -n "${HARBOR_NAMESPACE}" REGISTRY_HTTP_RELATIVEURLS=true
kubectl rollout status deployment/harbor-registry -n "${HARBOR_NAMESPACE}"
kubectl rollout status deployment/harbor-core -n "${HARBOR_NAMESPACE}"

echo "==> Configurando /etc/hosts e Docker local..."
if ! grep -qE "^127\.0\.0\.1[[:space:]]+${HARBOR_HOST}(\s|$)" /etc/hosts; then
  echo "127.0.0.1 ${HARBOR_HOST}" | sudo tee -a /etc/hosts >/dev/null
fi

if [[ ! -f "$DAEMON_JSON" ]]; then
  echo "{}" | sudo tee "$DAEMON_JSON" > /dev/null
fi

TMP_JSON=$(mktemp)
sudo jq --arg reg "$REGISTRY" '."insecure-registries" = ((."insecure-registries" // []) + [$reg] | unique)' "$DAEMON_JSON" > "$TMP_JSON"
sudo mv "$TMP_JSON" "$DAEMON_JSON"

sudo systemctl restart docker

echo "==> Aguardando API do Harbor ficar disponível..."
until curl -s "${HARBOR_URL}/ping" | grep -q "Pong"; do
  sleep 3
done

echo "==> Criando projeto 'poc'..."
curl -s -u "${ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" -X POST "${HARBOR_URL}/projects" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "poc",
    "metadata": {
      "public": "false"
    }
  }' >/dev/null || true

echo "==> Criando Robot Account de Push (ci-push)..."
PUSH_RESP=$(curl -s -u "${ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" -X POST "${HARBOR_URL}/robots" \
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
  }')

PUSH_USER=$(echo "$PUSH_RESP" | jq -r '.name // empty')
PUSH_PASS=$(echo "$PUSH_RESP" | jq -r '.secret // empty')

if [[ -n "$PUSH_USER" && -n "$PUSH_PASS" ]]; then
  echo "============================================================"
  echo "NOVA CONTA CI-PUSH CRIADA! Atualize nas Secrets do GitHub:"
  echo "HARBOR_PUSH_USER:     ${PUSH_USER}"
  echo "HARBOR_PUSH_PASSWORD: ${PUSH_PASS}"
  echo "============================================================"
fi

echo "==> Criando Robot Account de Pull (k8s-pull)..."
PULL_RESP=$(curl -s -u "${ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" -X POST "${HARBOR_URL}/robots" \
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

ROBOT_USER=$(echo "$PULL_RESP" | jq -r '.name // empty')
ROBOT_PASS=$(echo "$PULL_RESP" | jq -r '.secret // empty')

if [[ -n "$ROBOT_USER" && -n "$ROBOT_PASS" ]]; then
  kubectl create secret docker-registry harbor-pull-secret \
    --docker-server=harbor.local:8080 \
    --docker-username="$ROBOT_USER" \
    --docker-password="$ROBOT_PASS" \
    --namespace default \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "==> Setup do Harbor concluído com sucesso!"
