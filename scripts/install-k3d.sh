#!/usr/bin/env bash
set -euo pipefail

# Detecta a arquitetura
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Arquitetura não suportada: $ARCH"; exit 1 ;;
esac

echo "==> Verificando kubectl..."
if ! command -v kubectl &>/dev/null; then
  echo "kubectl não encontrado. Instalando para linux/${ARCH}..."
  KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  
  curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256"
  
  echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
  
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl kubectl.sha256
else
  echo "kubectl já instalado: $(kubectl version --client | head -n1)"
fi

echo "==> Verificando k3d..."
if ! command -v k3d &>/dev/null; then
  echo "k3d não encontrado. Instalando..."
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
  echo "k3d já instalado: $(k3d version | head -n1)"
fi

echo "==> Instalação concluída."
