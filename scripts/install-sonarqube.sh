#!/usr/bin/env bash
set -euo pipefail

SONAR_NAMESPACE="sonarqube"
SONAR_HOST="sonar.local"
SONAR_PORT="8080"
SONAR_ADMIN_PASSWORD="Son@r12345!Admin"  # troque em produção
POSTGRES_PASSWORD="SonarDB12345"      # troque em produção
MONITORING_PASSCODE="SonarMonitor123" # troque em produção

echo "==> Verificando Helm..."
if ! command -v helm &>/dev/null; then
  echo "Erro: Helm não está instalado."
  exit 1
fi

echo "==> Ajustando vm.max_map_count no host para evitar erro(requisito do SonarQube/Elasticsearch)..."
sudo sysctl -w vm.max_map_count=524288 >/dev/null

echo "==> Adicionando repositórios Helm..."
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube --force-update
helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
helm repo update

echo "==> Instalando PostgreSQL externo para o SonarQube..."
helm upgrade --install sonarqube-postgresql bitnami/postgresql \
  --namespace "${SONAR_NAMESPACE}" --create-namespace \
  --set auth.username=sonar \
  --set auth.password="${POSTGRES_PASSWORD}" \
  --set auth.database=sonar \
  --set primary.persistence.size=2Gi \
  --wait --timeout 5m

echo "==> Instalando SonarQube (Community Build)..."
helm upgrade --install sonarqube sonarqube/sonarqube \
  --namespace "${SONAR_NAMESPACE}" \
  --set community.enabled=true \
  --set postgresql.enabled=false \
  --set account.adminPassword="${SONAR_ADMIN_PASSWORD}" \
  --set account.currentAdminPassword=admin \
  --set monitoringPasscode="${MONITORING_PASSCODE}" \
  --set jdbcOverwrite.enabled=true \
  --set jdbcOverwrite.jdbcUrl="jdbc:postgresql://sonarqube-postgresql:5432/sonar" \
  --set jdbcOverwrite.jdbcUsername=sonar \
  --set jdbcOverwrite.jdbcPassword="${POSTGRES_PASSWORD}" \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=traefik \
  --set ingress.hosts[0].name="${SONAR_HOST}" \
  --set ingress.hosts[0].path=/ \
  --wait --timeout 10m

# Adiciona no /etc/hosts sem duplicar
if ! grep -qE "^127\.0\.0\.1[[:space:]]+${SONAR_HOST}(\s|$)" /etc/hosts; then
  echo "127.0.0.1 ${SONAR_HOST}" | sudo tee -a /etc/hosts >/dev/null
fi

echo "==> Definindo senha do admin via API..."
kubectl exec -n "${SONAR_NAMESPACE}" statefulset/sonarqube-sonarqube -- \
    curl -i -u "admin:admin" -X POST \
    "http://localhost:9000/api/users/change_password" \
    --data-urlencode "login=admin" \
    --data-urlencode "previousPassword=admin" \
    --data-urlencode "password=${SONAR_ADMIN_PASSWORD}"

echo "==> SonarQube instalado com sucesso!"
echo "1. Acesse no navegador: http://${SONAR_HOST}:${SONAR_PORT}"
echo "2. Usuário: admin | Senha: ${SONAR_ADMIN_PASSWORD}"
echo ""
echo "Credenciais do banco:"
echo "  Host: sonarqube-postgresql.${SONAR_NAMESPACE}.svc.cluster.local"
echo "  User: sonar"
echo "  Password: ${POSTGRES_PASSWORD}"

echo "credencial para ser salva no github"

SONAR_TOKEN=$(kubectl exec -n sonarqube statefulset/sonarqube-sonarqube -- \
  curl -s -u 'admin:Son@r12345!Admin' -X POST \
  "http://localhost:9000/api/user_tokens/generate" \
  -d "name=github-actions-$(date +%s)" \
  -d "type=GLOBAL_ANALYSIS_TOKEN" | jq -r '.token')

echo "Token gerado: ${SONAR_TOKEN}"
