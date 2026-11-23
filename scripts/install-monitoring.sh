#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests/monitoring"
NAMESPACE="monitoring"
GRAFANA_HOST="grafana.local"
PROM_HOST="prometheus.local"
ALERT_HOST="alertmanager.local"
GRAFANA_PORT="8080"

echo "=========================================================="
echo "🚀 Iniciando Instalação da Stack de Observabilidade (SRE)"
echo "   - Métricas: Prometheus Operator + Grafana + Alertmanager"
echo "   - Logs: Loki + Promtail"
echo "=========================================================="

# 1. Verificar pré-requisitos
command -v helm >/dev/null 2>&1 || { echo "❌ Erro: Helm não está instalado."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ Erro: kubectl não está instalado."; exit 1; }

echo "==> 1. Adicionando repositórios Helm..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add grafana https://grafana.github.io/helm-charts --force-update
helm repo update

echo "==> 2. Criando namespace '${NAMESPACE}'..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> 3. Instalando/Atualizando kube-prometheus-stack..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  -f "${MANIFESTS_DIR}/prometheus-values.yaml" \
  --timeout 10m \
  --wait

echo "==> 4. Instalando/Atualizando loki-stack (Loki + Promtail)..."
helm upgrade --install loki grafana/loki-stack \
  --namespace "${NAMESPACE}" \
  -f "${MANIFESTS_DIR}/loki-values.yaml" \
  --timeout 5m \
  --wait

echo "==> 5. Conectando Datasource do Loki ao Grafana..."
kubectl apply -f "${MANIFESTS_DIR}/loki-datasource.yaml"

echo "==> 6. Aplicando ServiceMonitor e PodMonitor para a minha-app..."
kubectl apply -f "${MANIFESTS_DIR}/service-monitor.yaml"

echo "==> 7. Aplicando Regras de Alerta do Prometheus (PrometheusRule)..."
kubectl apply -f "${MANIFESTS_DIR}/alert-rules.yaml"

echo "==> 8. Importando Dashboard da aplicação no Grafana..."
kubectl apply -f "${MANIFESTS_DIR}/dashboard-configmap.yaml"

echo "==> 9. Configurando resolução de DNS local no /etc/hosts..."
for HOST in "${GRAFANA_HOST}" "${PROM_HOST}" "${ALERT_HOST}"; do
  if ! grep -qE "^127\.0\.0\.1[[:space:]]+${HOST}(\s|$)" /etc/hosts 2>/dev/null; then
    echo "127.0.0.1 ${HOST}" | sudo tee -a /etc/hosts >/dev/null || echo "⚠️  Adicione manualmente ao seu /etc/hosts: 127.0.0.1 ${HOST}"
  fi
done

echo ""
echo "=========================================================="
echo "✅ Stack de Monitoramento Instalada com Sucesso!"
echo "=========================================================="
echo "📊 Grafana:      http://${GRAFANA_HOST}:${GRAFANA_PORT}"
echo "   Usuário:      admin"
echo "   Senha:        admin"
echo "🔥 Prometheus:   http://${PROM_HOST}:${GRAFANA_PORT}"
echo "🚨 Alertmanager: http://${ALERT_HOST}:${GRAFANA_PORT}"
echo "=========================================================="
echo "💡 Dica: Para validar o funcionamento, execute:"
echo "   ${SCRIPT_DIR}/test-monitoring.sh"
echo "=========================================================="
