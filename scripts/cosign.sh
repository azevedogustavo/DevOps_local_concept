#!/usr/bin/env bash
set -euo pipefail

# 1. Gera a senha aleatória
export COSIGN_PASSWORD=$(head -c 24 /dev/urandom | base64 | tr -d "/+=")

# 2. Executa o Cosign com o seu usuário para evitar problemas de permissão
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e COSIGN_PASSWORD \
  -v "$(pwd):/keys" \
  -w /keys \
  ghcr.io/sigstore/cosign/cosign:latest generate-key-pair

# 3. Exibe a senha e os arquivos gerados
echo ""
echo "=================================================="
echo "✅ Chaves geradas com sucesso!"
echo "🔑 SENHA (Salve no GitHub Secret COSIGN_PASSWORD):"
echo "$COSIGN_PASSWORD"
echo "=================================================="
echo "Arquivos criados:"
ls -l cosign.key cosign.pub