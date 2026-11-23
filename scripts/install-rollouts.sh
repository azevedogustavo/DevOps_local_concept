#!/usr/bin/env bash
set -euo pipefail

ROLLOUTS_NAMESPACE="argo-rollouts"
ROLLOUTS_HOST="rollouts.local"
ROLLOUTS_PORT="8080"

echo "==> Adicionando repositório Helm do Argo..."
helm repo add argo https://github.io --force-update
helm repo update

echo "==> Instalando Argo Rollouts no namespace '${ROLLOUTS_NAMESPACE}'..."
helm upgrade --install argo-rollouts argo/argo-rollouts \
  --namespace "${ROLLOUTS_NAMESPACE}" --create-namespace \
  --set dashboard.enabled=true \
  --set dashboard.ingress.enabled=true \
  --set dashboard.ingress.ingressClassName=traefik \
  --set dashboard.ingress.hosts[0]="${ROLLOUTS_HOST}" \
  --wait \
  --timeout 5m

echo "==> Configurando permissão RBAC para o Argo Rollouts gerenciar TraefikService..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argo-rollouts-traefik-role
  labels:
    rbac.authorization.k8s.io/aggregate-to-argo-rollouts: "true"
rules:
  - apiGroups:
      - traefik.io
      - traefik.containo.us
    resources:
      - traefikservices
    verbs:
      - get
      - list
      - watch
      - update
      - patch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-rollouts-traefik-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-rollouts-traefik-role
subjects:
  - kind: ServiceAccount
    name: argo-rollouts
    namespace: ${ROLLOUTS_NAMESPACE}
EOF

echo "==> Configurando acesso local ao Dashboard do Argo Rollouts..."
if ! grep -qE "^127\.0\.0\.1[[:space:]]+${ROLLOUTS_HOST}(\s|$)" /etc/hosts; then
  echo "127.0.0.1 ${ROLLOUTS_HOST}" | sudo tee -a /etc/hosts >/dev/null
fi

echo "==> Argo Rollouts instalado com sucesso!"
echo "Dashboard disponível em: http://${ROLLOUTS_HOST}:${ROLLOUTS_PORT}/rollouts"
