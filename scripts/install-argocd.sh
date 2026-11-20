#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NAMESPACE="argocd"
ARGOCD_HOST="argocd.local"
ARGOCD_PORT="8080"

echo "==> Adicionando repositório Helm do ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update

echo "==> Instalando ArgoCD no namespace '${ARGOCD_NAMESPACE}'..."
helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" --create-namespace \
  --set configs.params."server\.insecure"=true \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=traefik \
  --set server.ingress.hostname="${ARGOCD_HOST}" \
  --wait \
  --timeout 10m

echo "==> ArgoCD instalado. Senha inicial do admin:"
kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

echo "==> Para acessar:"
if ! grep -qE "^127\.0\.0\.1[[:space:]]+${ARGOCD_HOST}(\s|$)" /etc/hosts; then
  echo "127.0.0.1 ${ARGOCD_HOST}" | sudo tee -a /etc/hosts >/dev/null
fi
echo "1. Adicionado '127.0.0.1 ${ARGOCD_HOST}' ao seu /etc/hosts"
echo "2. Abra no navegador: http://${ARGOCD_HOST}:${ARGOCD_PORT} (usuário: admin)"