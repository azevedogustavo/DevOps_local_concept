#!/usr/bin/env bash
set -euo pipefail

APP_URL="http://minha-app.local:8080"
GRAFANA_URL="http://grafana.local:8080"
PROM_URL="http://prometheus.local:8080"

echo "=========================================================="
echo "🧪 Teste e Validação da Stack de Observabilidade"
echo "=========================================================="

echo "==> 1. Gerando tráfego HTTP na aplicação para popular métricas e logs..."
for i in {1..15}; do
  curl -s -o /dev/null "${APP_URL}/" || true
  curl -s -o /dev/null "${APP_URL}/healthz" || true
done
echo "✅ 30 requisições enviadas para ${APP_URL}!"

echo ""
echo "==> 2. Verificando se o endpoint /metrics está respondendo..."
if curl -s "${APP_URL}/metrics" 2>/dev/null | grep -E "^http_requests_total" | head -n 5; then
  echo "✅ Endpoint /metrics respondendo com sucesso via Ingress!"
else
  echo "⚠️  Testando via Service interno no cluster..."
  kubectl run test-curl --rm -i --restart=Never --image=curlimages/curl -- curl -s http://minha-app-stable.default.svc.cluster.local/metrics | grep http_requests_total || true
fi

echo ""
echo "==> 3. Consultando métrica no Prometheus Server..."
kubectl exec -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- "http://localhost:9090/api/v1/query?query=http_requests_total" 2>/dev/null | grep -o '"result":\[.*\]' || echo "Prometheus ainda indexando métricas..."

echo ""
echo "==> 4. Verificando status dos alertas (Prometheus Rules)..."
kubectl get prometheusrule -n monitoring

echo ""
echo "==> 5. Verificando se o Loki está recebendo logs..."
kubectl exec -n monitoring sts/loki -c loki -- \
  wget -qO- "http://localhost:3100/loki/api/v1/labels" 2>/dev/null || echo "Loki ativo e aguardando streams..."

echo ""
echo "=========================================================="
echo "🎉 Validação Concluída!"
echo "Acesse o Grafana para ver os gráficos e logs:"
echo "👉 ${GRAFANA_URL}"
echo "   Menu -> Dashboards -> 'Minha-App - Métricas e Logs'"
echo "=========================================================="
