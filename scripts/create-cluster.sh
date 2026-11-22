#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="poc-cluster"

# Verifica exatamente pelo nome do cluster sem o cabeçalho
if k3d cluster list --no-headers | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  echo "==> Cluster '${CLUSTER_NAME}' já existe. Garantindo que esteja iniciado..."
  k3d cluster start "${CLUSTER_NAME}"
else
  echo "==> Criando cluster '${CLUSTER_NAME}'..."
  k3d cluster create "${CLUSTER_NAME}" \
    --servers 1 \
    --agents 2 \
    --port "8080:80@loadbalancer" \
    --port "8443:443@loadbalancer" \
    --kubeconfig-update-default
fi

echo "==> Aguardando nós ficarem prontos..."
kubectl --context "k3d-${CLUSTER_NAME}" wait --for=condition=Ready nodes --all --timeout=120s

echo "==> Cluster pronto:"
kubectl --context "k3d-${CLUSTER_NAME}" get nodes