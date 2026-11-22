# 🔧 Guia de Troubleshooting e Lições Aprendidas

Este guia consolida os diagnósticos, erros operacionais e soluções de engenharia implementadas durante o desenvolvimento da Prova de Conceito (POC). Ele serve como base de conhecimento prático para operação, manutenção e resolução de incidentes no ambiente **DevOps Local Concept**.

---

## 📋 Sumário de Incidentes
1. [Harbor: Registry Inseguro (HTTP) nos nós k3d](#1-harbor-registry-inseguro-http-nos-nós-k3d)
2. [Harbor: Loop de Redirecionamento e Headers atrás do Traefik](#2-harbor-loop-de-redirecionamento-e-headers-atrás-do-traefik)
3. [SonarQube: Falha de Inicialização do Pod (vm.max_map_count)](#3-sonarqube-falha-de-inicialização-do-pod-vmmax_map_count)
4. [SonarQube: Senha Padrão de Admin e Geração de Token](#4-sonarqube-senha-padrão-de-admin-e-geração-de-token)
5. [ARC Runner: Docker-in-Docker rejeitando Push para o Harbor](#5-arc-runner-docker-in-docker-rejeitando-push-para-o-harbor)
6. [ArgoCD: Erro de Tamanho Máximo em CRDs do Kyverno e Prometheus](#6-argocd-erro-de-tamanho-máximo-em-crds-do-kyverno-e-prometheus)
7. [Argo Rollouts: Permissão RBAC e Dessincronização do TraefikService](#7-argo-rollouts-permissão-rbac-e-dessincronização-do-traefikservice)
8. [Kyverno: Falha de Verificação de Assinatura em Registry sem TLS](#8-kyverno-falha-de-verificação-de-assinatura-em-registry-sem-tls)
9. [Traefik Ingress: Erro 404 ao Acessar por localhost em vez do Hostname](#9-traefik-ingress-erro-404-ao-acessar-por-localhost-em-vez-do-hostname)
10. [Cheat Sheet de Comandos de Diagnóstico](#10-cheat-sheet-de-comandos-de-diagnóstico)

---

## 1. Harbor: Registry Inseguro (HTTP) nos nós k3d

### ⚠️ Sintoma:
Ao tentar fazer o deploy de um pod que baixa imagens do Harbor local, o pod entra em status `ImagePullBackOff` ou `ErrImagePull` com o erro:
```text
Failed to pull image "harbor.local:8080/poc/minha-app:...": 
http: server gave HTTP response to HTTPS client
```

### 🔍 Causa Raiz:
O runtime de contêineres do k3s (**containerd**) exige conexões HTTPS com certificados TLS válidos por padrão. Como a POC utiliza HTTP na porta `8080`, os nós do k3d não confiam no endpoint sem instrução explícita. Além disso, os contêineres dos nós k3d não sabiam resolver o domínio `harbor.local`.

### 💡 Solução Aplicada:
1. Injetar a configuração de espelhos inseguros em `/etc/rancher/k3s/registries.yaml` em cada nó do cluster k3d:
```bash
for node in $(docker ps --filter "name=k3d-" --format "{{.Names}}"); do
  # Garante resolução DNS de harbor.local apontando para o host interno
  docker exec "$node" sh -c "grep -q 'harbor.local' /etc/hosts || grep host.k3d.internal /etc/hosts | awk '{print \$1 \" harbor.local\"}' >> /etc/hosts"

  # Configura containerd para aceitar HTTP na porta 8080
  docker exec "$node" sh -c 'mkdir -p /etc/rancher/k3s && cat <<EOF > /etc/rancher/k3s/registries.yaml
mirrors:
  "harbor.local:8080":
    endpoint:
      - "http://harbor.local:8080"
EOF'

  # Reinicia o nó para recarregar o containerd
  docker restart "$node"
done
```

---

## 2. Harbor: Loop de Redirecionamento e Headers atrás do Traefik

### ⚠️ Sintoma:
Ao tentar realizar login no Harbor via interface web ou executar `docker login harbor.local:8080`, o cliente recebe erros de redirecionamento infinito ou o Docker reclama de respostas em HTTPS inesperadas.

### 🔍 Causa Raiz:
O Traefik atua como reverse proxy na frente do Harbor. Se os headers `X-Forwarded-Proto` e `X-Forwarded-Port` não forem propagados explicitamente com o valor `http` e `8080`, os componentes internos do Harbor (`harbor-core` e `harbor-portal`) supõem que a requisição externa é HTTPS e tentam forçar redirecionamento.

### 💡 Solução Aplicada:
1. Criação de um `Middleware` do Traefik no namespace `harbor`:
```yaml
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
```
2. Associação do Middleware ao Ingress do Harbor:
```bash
kubectl annotate ingress -n harbor harbor-ingress \
  traefik.ingress.kubernetes.io/router.middlewares=harbor-harbor-http-headers@kubernetescrd \
  --overwrite
```
3. Ativação de URLs relativas nos deployments do Harbor:
```bash
kubectl set env deployment/harbor-registry -n harbor -c registry REGISTRY_HTTP_RELATIVEURLS=true
kubectl set env deployment/harbor-core -n harbor REGISTRY_HTTP_RELATIVEURLS=true
```

---

## 3. SonarQube: Falha de Inicialização do Pod (vm.max_map_count)

### ⚠️ Sintoma:
O pod do SonarQube entra em loop de reinicialização (`CrashLoopBackOff`) com a mensagem nos logs:
```text
max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
```

### 🔍 Causa Raiz:
O SonarQube embute uma instância de **Elasticsearch** para indexação de código e métricas. O kernel do Linux possui uma trava de segurança (`vm.max_map_count`) que por padrão é definida como `65530` na maioria das distribuições, o que impede a inicialização do motor de busca.

### 💡 Solução Aplicada:
Ajustar o parâmetro diretamente no kernel do host antes de instalar o SonarQube:
```bash
sudo sysctl -w vm.max_map_count=524288
# Para persistir entre reboots do host:
echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.d/99-sonarqube.conf
```

---

## 4. SonarQube: Senha Padrão de Admin e Geração de Token

### ⚠️ Sintoma:
O script de automação definia a senha do SonarQube via parâmetros Helm (`account.adminPassword`), mas ao tentar autenticar no primeiro login, a senha continuava sendo a padrão de fábrica (`admin:admin`) ou bloqueava tentativas de login automatizado.

### 🔍 Causa Raiz:
Em determinadas versões do chart oficial do SonarQube Community, a criação do banco de dados inicial ignora a senha passada pelo Helm caso o banco não execute os scripts de post-install no tempo correto.

### 💡 Solução Aplicada:
Automação idempotente pós-instalação no script `install-sonarqube.sh`:
1. Disparar uma chamada HTTP para a API interna do SonarQube forçando a alteração de senha:
```bash
kubectl exec -n sonarqube statefulset/sonarqube-sonarqube -- \
  curl -i -u "admin:admin" -X POST \
  "http://localhost:9000/api/users/change_password" \
  --data-urlencode "login=admin" \
  --data-urlencode "previousPassword=admin" \
  --data-urlencode "password=${SONAR_ADMIN_PASSWORD}"
```
2. Gerar o token de análise estática (`GLOBAL_ANALYSIS_TOKEN`) automaticamente via API e exibi-lo para cadastro nos Secrets do GitHub:
```bash
SONAR_TOKEN=$(kubectl exec -n sonarqube statefulset/sonarqube-sonarqube -- \
  curl -s -u "admin:${SONAR_ADMIN_PASSWORD}" -X POST \
  "http://localhost:9000/api/user_tokens/generate" \
  -d "name=github-actions-$(date +%s)" \
  -d "type=GLOBAL_ANALYSIS_TOKEN" | jq -r '.token')
```

---

## 5. ARC Runner: Docker-in-Docker rejeitando Push para o Harbor

### ⚠️ Sintoma:
O step de `docker push` dentro do workflow do GitHub Actions falha com:
```text
Get "https://harbor.local:8080/v2/": dial tcp: lookup harbor.local: no such host
ou
http: server gave HTTP response to HTTPS client
```

### 🔍 Causa Raiz:
O runner do ARC utiliza o modo **Docker-in-Docker (DinD)** para construir e enviar imagens. O contêiner de daemon do Docker (`dind`) roda isolado dentro do pod do runner e, portanto:
1. Não possui as configurações de registro inseguro do Docker do host.
2. Não conhece o IP do host mapeado para `harbor.local`.

### 💡 Solução Aplicada:
1. Criar um `ConfigMap` com o arquivo `daemon.json` contendo os registries inseguros:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dind-daemon-config
  namespace: arc-runners
data:
  daemon.json: |
    {
      "insecure-registries": ["harbor.local:8080", "harbor-core.harbor.svc.cluster.local:80"]
    }
```
2. No manifesto de instalação do Scale Set do ARC (`scripts/install-arc.sh`), montar esse ConfigMap no contêiner `dind` em `/etc/docker/daemon.json` e injetar a entrada `hostAliases`:
```yaml
hostAliases:
  - ip: "<IP_DO_HOST_NO_K3D>"
    hostnames:
      - "harbor.local"
```

---

## 6. ArgoCD: Erro de Tamanho Máximo em CRDs do Kyverno e Prometheus

### ⚠️ Sintoma:
Ao tentar sincronizar a aplicação do Kyverno ou do `kube-prometheus-stack` no ArgoCD, a sincronização falha com o erro:
```text
CustomResourceDefinition.apiextensions.k8s.io ... is invalid: 
metadata.annotations: Too long: must have at most 262144 bytes
```

### 🔍 Causa Raiz:
O `kubectl apply` padrão (Client-Side Apply) tenta salvar todo o estado do recurso na anotação `kubectl.kubernetes.io/last-applied-configuration`. Como os CRDs do Kyverno e do Prometheus Operator possuem dezenas de milhares de linhas de OpenAPI schema, a anotação excede o limite máximo permitido pelo Kubernetes (256 KB).

### 💡 Solução Aplicada:
Habilitar **Server-Side Apply** nas aplicações do ArgoCD (`apps/kyverno.yaml` e `apps/monitoring.yaml`):
```yaml
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true # Obrigatório para CRDs grandes
```

---

## 7. Argo Rollouts: Permissão RBAC e Dessincronização do TraefikService

### ⚠️ Sintoma:
1. O controlador do Argo Rollouts acusa erro de permissão ao tentar alterar pesos no Canary:
```text
traefikservices.traefik.io is forbidden: User "system:serviceaccount:argo-rollouts:argo-rollouts" 
cannot patch resource "traefikservices"
```
2. O ArgoCD marca a aplicação como **OutOfSync** perpetuamente após o início de um rollout.

### 🔍 Causa Raiz:
1. O chart padrão do Argo Rollouts não inclui permissões RBAC para os CRDs proprietários do Traefik (`traefik.io`).
2. O controlador do Rollouts altera o campo `weight` dinamicamente no `TraefikService`. Como o manifesto no Git possuía um peso fixo, o ArgoCD detectava divergência contínua entre o Git e o cluster.

### 💡 Solução Aplicada:
1. Criar uma `ClusterRole` agregada concedendo permissão total sobre `traefikservices` para a ServiceAccount do Argo Rollouts (`scripts/install-rollouts.sh`):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argo-rollouts-traefik-role
  labels:
    rbac.authorization.k8s.io/aggregate-to-argo-rollouts: "true"
rules:
  - apiGroups: ["traefik.io", "traefik.containo.us"]
    resources: ["traefikservices"]
    verbs: ["get", "list", "watch", "update", "patch"]
```
2. No manifesto de deploy e no Helm chart, omitir ou ignorar a comparação de diferenças no campo `spec.weighted.services[*].weight` dentro da configuração do ArgoCD.

---

## 8. Kyverno: Falha de Verificação de Assinatura em Registry sem TLS

### ⚠️ Sintoma:
Ao aplicar a política `verify-cosign-signature`, o Kyverno rejeita pods com o erro:
```text
failed to verify signature: Get "https://harbor.local:8080/v2/...": 
server gave HTTP response to HTTPS client
```

### 🔍 Causa Raiz:
Por padrão de segurança, o Kyverno exige comunicação HTTPS estrita com o registry de imagens para baixar os metadados de assinatura do Cosign.

### 💡 Solução Aplicada:
1. Configurar o argumento `allowInsecureRegistry: true` nos argumentos de inicialização do Kyverno (`apps/kyverno.yaml`):
```yaml
admissionController:
  container:
    extraArgs:
      allowInsecureRegistry: true
```
2. Adicionar o parâmetro `insecure: true` diretamente na regra `verifyImages` da política (`manifests/policies/kyverno/verify-signed-images.yaml`):
```yaml
verifyImages:
  - imageReferences:
      - "harbor.local:8080/poc/*"
    insecure: true
    mutateDigest: true
    verifyDigest: true
    required: true
```

---

## 9. Traefik Ingress: Erro 404 ao Acessar por localhost em vez do Hostname

### ⚠️ Sintoma:
Executar `curl http://localhost:8080` retorna `404 page not found`.

### 🔍 Causa Raiz:
O Traefik Ingress Controller v3 avalia regras baseadas no cabeçalho HTTP `Host`. Como os IngressRoutes e Ingresses estão mapeados para domínios específicos (`minha-app.local`, `harbor.local`, `argocd.local`), chamadas diretas para `localhost` não encontram nenhum roteador associado e caem no backend default 404.

### 💡 Solução:
Garantir o cadastro no `/etc/hosts` do host:
```bash
echo "127.0.0.1 minha-app.local harbor.local argocd.local sonar.local rollouts.local grafana.local" | sudo tee -a /etc/hosts
```
Para testes manuais via terminal sem alterar o `/etc/hosts`, utilize o cabeçalho `Host`:
```bash
curl -H "Host: minha-app.local" http://localhost:8080/healthz
```

---

## 10. Cheat Sheet de Comandos de Diagnóstico

### Inspecionar Status Geral do Cluster:
```bash
# Verificar pods em todos os namespaces
kubectl get pods -A -o wide

# Verificar nós e status do cluster
kubectl get nodes -o wide
k3d cluster list
```

### Diagnosticar Problemas de Políticas e Admissão:
```bash
# Verificar status e violações do OPA Gatekeeper
kubectl get constraint -A
kubectl describe k8sdisallowlatesttag disallow-latest-tag-default-ns

# Verificar políticas e relatórios do Kyverno
kubectl get clusterpolicy
kubectl get policyreports -A
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller --tail=100
```

### Diagnosticar Argo Rollouts e Canary:
```bash
# Inspecionar status do Rollout
kubectl argo rollouts get rollout minha-app -n default --watch

# Inspecionar pesos atuais do TraefikService
kubectl get traefikservice minha-app-wrr -n default -o yaml
```

### Diagnosticar Observabilidade (Métricas e Logs):
```bash
# Verificar regras do Prometheus carregadas
kubectl get prometheusrule -A

# Testar se os pods estão expondo /metrics
kubectl run test-curl --rm -it --image=curlimages/curl -- \
  curl http://minha-app-stable.default.svc.cluster.local/metrics
```
