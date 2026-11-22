Senha defaul do sonarqube apesar do parâmetro

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