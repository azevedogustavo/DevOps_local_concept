#!/usr/bin/env bash
set -euo pipefail

echo "==> Verificando kubectl..."
if ! command -v kubectl &>/dev/null; then
  echo "kubectl não encontrado. Instalando..."
  KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
else
  echo "kubectl já instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

echo "==> Verificando k3d..."
if ! command -v k3d &>/dev/null; then
  echo "k3d não encontrado. Instalando..."
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
  echo "k3d já instalado: $(k3d version | head -n1)"
fi

echo "==> Instalação concluída."