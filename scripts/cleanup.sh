#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="poc-cluster"

read -rp "Isso vai deletar o cluster '${CLUSTER_NAME}' e todos os recursos. Continuar? [y/N] " confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
  echo "Cancelado."
  exit 0
fi

if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
  echo "==> Deletando cluster '${CLUSTER_NAME}'..."
  k3d cluster delete "${CLUSTER_NAME}"
else
  echo "Cluster '${CLUSTER_NAME}' não existe."
fi

echo "==> Limpando arquivos temporários..."
rm -f cosign.key cosign.pub trivy-results.json 2>/dev/null || true

echo "==> Cleanup concluído."