#!/usr/bin/env bash
set -euo pipefail

ARC_SYSTEM_NS="arc-systems"
ARC_RUNNER_NS="arc-runners"
INSTALLATION_NAME="arc-runner-set"
SECRET_NAME="github-arc-secret"

GITHUB_CONFIG_URL="https://github.com/azevedogustavo/DevOps_local_concept"
HARBOR_REGISTRY="harbor.local:8080"
GITHUB_PAT=""

# Captura automaticamente o IP do host na rede do k3d (funciona para qualquer nome de cluster)
HOST_IP=$(docker inspect $(docker ps --filter "label=app=k3d" -q | head -n 1) -f '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}' 2>/dev/null || hostname -I | awk '{print $1}')
echo "==> IP do Host detectado para os runners: ${HOST_IP}"

GITHUB_PAT="${GITHUB_PAT:-SEU_GITHUB_PAT_AQUI}"

if [[ "${GITHUB_PAT}" == "SEU_GITHUB_PAT_AQUI" || -z "${GITHUB_PAT}" ]]; then
  read -rsp "Digite seu GitHub Personal Access Token (PAT): " GITHUB_PAT
  echo ""
fi

if [[ "${GITHUB_PAT}" == "SEU_GITHUB_PAT_AQUI" || -z "${GITHUB_PAT}" ]]; then
  echo "Erro: Você precisa informar um GITHUB_PAT válido."
  exit 1
fi

echo "==> 1. Instalando o ARC Controller (Operador)..."
helm upgrade --install arc \
  --namespace "${ARC_SYSTEM_NS}" \
  --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --wait

echo "==> 2. Criando namespace e Secret de autenticação do GitHub..."
kubectl create namespace "${ARC_RUNNER_NS}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic "${SECRET_NAME}" \
  --namespace="${ARC_RUNNER_NS}" \
  --from-literal=github_token="${GITHUB_PAT}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> 3. Criando ConfigMap do daemon.json e instalando o Runner Scale Set..."
kubectl create configmap dind-daemon-config \
  --namespace="${ARC_RUNNER_NS}" \
  --from-literal=daemon.json="{\"insecure-registries\": [\"${HARBOR_REGISTRY}\", \"harbor-core.harbor.svc.cluster.local:80\", \"harbor-core.harbor.svc.cluster.local\"]}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Remove release anterior caso esteja travado em pending-upgrade/failed
if helm status "${INSTALLATION_NAME}" -n "${ARC_RUNNER_NS}" >/dev/null 2>&1; then
  echo "==> Limpando release anterior para evitar travamento de geração..."
  helm uninstall "${INSTALLATION_NAME}" -n "${ARC_RUNNER_NS}"
  sleep 5
fi

cat <<EOF | helm upgrade --install "${INSTALLATION_NAME}" \
  --namespace "${ARC_RUNNER_NS}" \
  --values - \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
githubConfigUrl: "${GITHUB_CONFIG_URL}"
githubConfigSecret: "${SECRET_NAME}"

template:
  spec:
    hostAliases:
      - ip: "${HOST_IP}"
        hostnames:
          - "harbor.local"
          - "sonar.local"
    containers:
      - name: runner
        image: ghcr.io/actions/actions-runner:latest
        command: ["/home/runner/run.sh"]
        env:
          - name: DOCKER_HOST
            value: unix:///var/run/docker.sock
          - name: RUNNER_WAIT_FOR_DOCKER_IN_SECONDS
            value: "120"
        volumeMounts:
          - name: work
            mountPath: /home/runner/_work
          - name: dind-sock
            mountPath: /var/run
      - name: dind
        image: docker:dind
        args:
          - dockerd
          - --host=unix:///var/run/docker.sock
          - --group=123
        env:
          - name: DOCKER_GROUP_GID
            value: "123"
        securityContext:
          privileged: true
        startupProbe:
          exec:
            command: ["docker", "info"]
          initialDelaySeconds: 0
          periodSeconds: 5
          failureThreshold: 24
        volumeMounts:
          - name: work
            mountPath: /home/runner/_work
          - name: dind-sock
            mountPath: /var/run
          - name: dind-externals
            mountPath: /home/runner/externals
          - name: dind-config
            mountPath: /etc/docker/daemon.json
            subPath: daemon.json
    volumes:
      - name: work
        emptyDir: {}
      - name: dind-sock
        emptyDir: {}
      - name: dind-externals
        emptyDir: {}
      - name: dind-config
        configMap:
          name: dind-daemon-config
EOF

echo "==> Instalação concluída! Aguarde ~10s para o pod listener subir e dispare o workflow."
