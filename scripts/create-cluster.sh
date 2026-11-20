#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="poc-cluster"

if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
  echo "Cluster '${CLUSTER_NAME}' já existe. Nada a fazer."
  exit 0
fi

echo "==> Criando cluster '${CLUSTER_NAME}'..."
k3d cluster create "${CLUSTER_NAME}" \
  --servers 1 \
  --agents 2 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer" \
  --kubeconfig-update-default

echo "==> Aguardando nós ficarem prontos..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "==> Cluster pronto:"
kubectl get nodes