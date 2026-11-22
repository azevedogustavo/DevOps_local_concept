#!/usr/bin/env bash
# Esse script roda no runner

set -euo pipefail

# Descobre a arquitetura da máquina (amd64 ou arm64) e a última versão
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
COSIGN_VERSION=$(curl -s https://github.com | grep -Po '"tag_name": "\K.*?(?=")')

# Baixa e instala o binário do Cosign
curl -O -L "https://github.com{COSIGN_VERSION}/cosign-linux-${ARCH}"
sudo mv "cosign-linux-${ARCH}" /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Verifica a instalação
cosign version