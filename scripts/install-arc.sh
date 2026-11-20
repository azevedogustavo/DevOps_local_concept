#!/usr/bin/env bash
set -euo pipefail

ARC_SYSTEM_NS="arc-systems"
ARC_RUNNER_NS="arc-runners"
INSTALLATION_NAME="arc-runner-set"
SECRET_NAME="github-arc-secret"

GITHUB_CONFIG_URL="https://github.com"
HARBOR_REGISTRY="harbor.local:8080"

# Captura automaticamente o IP do host na rede do k3d
HOST_IP=$(docker network inspect k3d-k3s-default -f '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || hostname -I | awk '{print $1}')
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

echo "==> 3. Instalando o Runner Scale Set com DinD, DNS local e Insecure Registry..."
cat <<EOF | helm upgrade --install "${INSTALLATION_NAME}" \
  --namespace "${ARC_RUNNER_NS}" \
  --values - \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --wait
githubConfigUrl: "${GITHUB_CONFIG_URL}"
githubConfigSecret: "${SECRET_NAME}"
containerMode:
  type: "dind"

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
          - --group=\$(DOCKER_GROUP_GID)
          - --insecure-registry=${HARBOR_REGISTRY}
          - --insecure-registry=harbor-core.harbor.svc.cluster.local:80
        env:
          - name: DOCKER_GROUP_GID
            value: "123"
        securityContext:
          privileged: true
        volumeMounts:
          - name: work
            mountPath: /home/runner/_work
          - name: dind-sock
            mountPath: /var/run
          - name: dind-externals
            mountPath: /home/runner/externals
EOF

echo "==> Instalação concluída! O runner já resolve harbor.local e sonar.local via ${HOST_IP}."
