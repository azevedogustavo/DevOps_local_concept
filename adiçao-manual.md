# 1. Cria um Middleware no namespace harbor para forçar X-Forwarded-Proto=http
cat <<EOF | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: harbor-http-headers
  namespace: harbor
spec:
  headers:
    customRequestHeaders:
      X-Forwarded-Proto: "http"
      X-Forwarded-Port: "8080"
EOF

# 2. Associa esse Middleware ao Ingress do Harbor
kubectl annotate ingress -n harbor harbor-ingress \
  traefik.ingress.kubernetes.io/router.middlewares=harbor-harbor-http-headers@kubernetescrd \
  --overwrite
middleware.traefik.io/harbor-http-headers created
ingress.networking.k8s.io/harbor-ingress annotated


kubectl patch autoscalingrunnerset arc-runner-set -n arc-runners --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/1/args/-",
    "value": "--insecure-registry=harbor.local:8080"
  }
]'

kubectl set env deployment/harbor-registry -n harbor -c registry REGISTRY_HTTP_RELATIVEURLS=true
kubectl set env deployment/harbor-core -n harbor REGISTRY_HTTP_RELATIVEURLS=true


kubectl apply -f apps/aplicacao.yaml

for node in $(docker ps --filter "name=k3d-" --format "{{.Names}}"); do
  # 1. Garante que o nó sabe resolver harbor.local para a sua máquina host
  docker exec "$node" sh -c "grep -q 'harbor.local' /etc/hosts || grep host.k3d.internal /etc/hosts | awk '{print \$1 \" harbor.local\"}' >> /etc/hosts"

  # 2. Cria o registries.yaml forçando o endpoint HTTP
  docker exec "$node" sh -c 'mkdir -p /etc/rancher/k3s && cat <<EOF > /etc/rancher/k3s/registries.yaml
mirrors:
  "harbor.local:8080":
    endpoint:
      - "http://harbor.local:8080"
EOF'

  # 3. Reinicia o nó para o K3s gerar o config.toml do containerd atualizado
  docker restart "$node"
done



# muito importante
echo "127.0.0.1 minha-app.local" | sudo tee -a /etc/hosts

#
GK_URL=$(printf "%s://%s.%s/%s/%s" "https" "open-policy-agent" "github.io" "gatekeeper" "charts")
helm repo add gatekeeper "$GK_URL"
helm repo update
helm install gatekeeper gatekeeper/gatekeeper --namespace gatekeeper-system --create-namespace
