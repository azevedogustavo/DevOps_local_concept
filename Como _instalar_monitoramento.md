Como o Portmail está depreciado. O Grafana Alloy será utilizado (por que?)


Configurar os quatro componentes na sua PoC do k3d é um processo sequencial. A boa notícia é que a maior parte do trabalho é feita com o Helm, e a configuração é bem direta.

O fluxo que vamos seguir é: primeiro instalar o Prometheus + Grafana (que já vêm juntos), depois instalar o Loki para armazenar os logs, e por fim configurar o Alloy para coletar os logs dos pods e enviá-los ao Loki.

📊 Passo 1: Prometheus + Grafana (Métricas)
O chart kube-prometheus-stack é a maneira mais rápida de ter Prometheus e Grafana funcionando e integrados, pois ele já instala e configura tudo o que é necessário .

Adicione o repositório e instale:

bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
Verifique e acesse:
Após a instalação, você pode acessar o Grafana para confirmar que está tudo certo.

bash
# Obtenha a senha do admin
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d
# Faça o port-forward para acessar a UI
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
Acesse http://localhost:3000 (usuário admin). O Prometheus já estará lá como um data source.

📝 Passo 2: Loki (Armazenamento de Logs)
Para uma PoC local, o modo SingleBinary (monolítico) do Loki é o mais simples, pois roda tudo em um único pod e usa o filesystem local para armazenamento .

Crie um arquivo loki-values.yaml para configurar o modo de implantação e o armazenamento:

yaml
deploymentMode: SingleBinary
singleBinary:
  replicas: 1
# Desabilita os outros modos de deployment
read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0
# Configuração de armazenamento local
loki:
  auth_enabled: false
  storage:
    type: filesystem
Instale o Loki:

bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki -n monitoring -f loki-values.yaml
🚚 Passo 3: Grafana Alloy (Coleta de Logs)
O Alloy precisa de uma configuração que diga a ele para descobrir os pods e para onde enviar os logs. A forma mais limpa é usar um arquivo values.yaml com a configuração em HCL.

Crie o arquivo alloy-values.yaml. O ponto de atenção aqui é a URL do Loki, que deve apontar para o serviço correto dentro do cluster (loki-gateway.monitoring.svc.cluster.local) .

yaml
alloy:
  mounts:
    varlog: true
  configMap:
    content: |
      discovery.kubernetes "pods" {
        role = "pod"
      }

      loki.source.kubernetes "pods" {
        targets    = discovery.kubernetes.pods.targets
        forward_to = [loki.write.local.receiver]
      }

      loki.write "local" {
        endpoint {
          url = "http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push"
        }
      }
Instale o Alloy:

bash
helm install alloy grafana/alloy -n monitoring -f alloy-values.yaml
🔗 Passo 4: Conectar o Grafana ao Loki
Com o Loki rodando, falta apenas dizer ao Grafana para usá-lo como fonte de dados. A maneira mais "GitOps" de fazer isso no kube-prometheus-stack é usando um ConfigMap com uma label específica, pois o Grafana já possui um sidecar que detecta e carrega esses ConfigMaps automaticamente .

Crie o arquivo loki-datasource.yaml:

yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-loki-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        uid: loki
        url: http://loki-gateway.monitoring.svc.cluster.local
        access: proxy
Aplique o ConfigMap:

bash
kubectl apply -f loki-datasource.yaml
Em alguns segundos, o Grafana vai detectar o novo data source e o Loki estará disponível para consultas.

✅ Verificação Final
Para confirmar que tudo está funcionando:

Acesse o Grafana (http://localhost:3000).

Vá em Explore (ícone de bússola no menu lateral).

No seletor de data source no topo, escolha Loki.

No campo de query, use o modo Builder ou insira uma consulta LogQL simples como {namespace="default"} para ver os logs dos pods que estão rodando no seu cluster.

Se os logs aparecerem, sua stack de observabilidade está completa e integrada.

---
# Instalação passo a passo

Configurar os quatro componentes na sua PoC do k3d é um processo sequencial. A boa notícia é que a maior parte do trabalho é feita com o Helm, e a configuração é bem direta.

O fluxo que vamos seguir é: primeiro instalar o Prometheus + Grafana (que já vêm juntos), depois instalar o Loki para armazenar os logs, e por fim configurar o Alloy para coletar os logs dos pods e enviá-los ao Loki.

📊 Passo 1: Prometheus + Grafana (Métricas)
O chart kube-prometheus-stack é a maneira mais rápida de ter Prometheus e Grafana funcionando e integrados, pois ele já instala e configura tudo o que é necessário .

Adicione o repositório e instale:

bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
Verifique e acesse:
Após a instalação, você pode acessar o Grafana para confirmar que está tudo certo.

bash
# Obtenha a senha do admin
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d
# Faça o port-forward para acessar a UI
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
Acesse http://localhost:3000 (usuário admin). O Prometheus já estará lá como um data source.

📝 Passo 2: Loki (Armazenamento de Logs)
Para uma PoC local, o modo SingleBinary (monolítico) do Loki é o mais simples, pois roda tudo em um único pod e usa o filesystem local para armazenamento .

Crie um arquivo loki-values.yaml para configurar o modo de implantação e o armazenamento:

yaml
deploymentMode: SingleBinary
singleBinary:
  replicas: 1
# Desabilita os outros modos de deployment
read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0
# Configuração de armazenamento local
loki:
  auth_enabled: false
  storage:
    type: filesystem
Instale o Loki:

bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki -n monitoring -f loki-values.yaml
🚚 Passo 3: Grafana Alloy (Coleta de Logs)
O Alloy precisa de uma configuração que diga a ele para descobrir os pods e para onde enviar os logs. A forma mais limpa é usar um arquivo values.yaml com a configuração em HCL.

Crie o arquivo alloy-values.yaml. O ponto de atenção aqui é a URL do Loki, que deve apontar para o serviço correto dentro do cluster (loki-gateway.monitoring.svc.cluster.local) .

yaml
alloy:
  mounts:
    varlog: true
  configMap:
    content: |
      discovery.kubernetes "pods" {
        role = "pod"
      }

      loki.source.kubernetes "pods" {
        targets    = discovery.kubernetes.pods.targets
        forward_to = [loki.write.local.receiver]
      }

      loki.write "local" {
        endpoint {
          url = "http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push"
        }
      }
Instale o Alloy:

bash
helm install alloy grafana/alloy -n monitoring -f alloy-values.yaml
🔗 Passo 4: Conectar o Grafana ao Loki
Com o Loki rodando, falta apenas dizer ao Grafana para usá-lo como fonte de dados. A maneira mais "GitOps" de fazer isso no kube-prometheus-stack é usando um ConfigMap com uma label específica, pois o Grafana já possui um sidecar que detecta e carrega esses ConfigMaps automaticamente .

Crie o arquivo loki-datasource.yaml:

yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-loki-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        uid: loki
        url: http://loki-gateway.monitoring.svc.cluster.local
        access: proxy
Aplique o ConfigMap:

bash
kubectl apply -f loki-datasource.yaml
Em alguns segundos, o Grafana vai detectar o novo data source e o Loki estará disponível para consultas.

✅ Verificação Final
Para confirmar que tudo está funcionando:

Acesse o Grafana (http://localhost:3000).

Vá em Explore (ícone de bússola no menu lateral).

No seletor de data source no topo, escolha Loki.

No campo de query, use o modo Builder ou insira uma consulta LogQL simples como {namespace="default"} para ver os logs dos pods que estão rodando no seu cluster.

Se os logs aparecerem, sua stack de observabilidade está completa e integrada.





---
<br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br>







🛠️ Passo a Passo para Integrar o Alloy ao Loki
1. Instalar o Loki (se ainda não tiver)
Partindo do princípio que você já tem o Loki rodando (conforme conversamos anteriormente), certifique-se de que ele está acessível. O endpoint de push geralmente é algo como http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push.

2. Instalar o Alloy via Helm com Configuração Customizada
A forma mais limpa de configurar o Alloy é fornecer um arquivo values.yaml que contenha a configuração completa em HCL. O Helm chart do Alloy permite injetar essa configuração diretamente.

Crie um arquivo chamado alloy-values.yaml com o seguinte conteúdo:

yaml
alloy:
  # Monta o diretório de logs do host para que o Alloy possa ler os logs dos containers
  mounts:
    varlog: true
  
  configMap:
    # A configuração do Alloy é definida aqui em HCL
    content: |
      // 1. Componente de Descoberta: Descobre todos os Pods no cluster
      discovery.kubernetes "pods" {
        role = "pod"
      }

      // 2. Componente de Coleta: Coleta logs dos Pods descobertos
      loki.source.kubernetes "pods" {
        targets    = discovery.kubernetes.pods.targets
        forward_to = [loki.write.local.receiver]
      }

      // 3. Componente de Escrita: Envia os logs para o Loki
      loki.write "local" {
        endpoint {
          // Substitua pela URL do seu Loki. 
          // Exemplo: http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push
          url = "http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push"
        }
      }
Explicação da configuração:

discovery.kubernetes "pods": Este componente consulta a API do Kubernetes para encontrar todos os Pods em execução .

loki.source.kubernetes "pods": Ele pega a lista de Pods descobertos e coleta os logs de cada um deles .

loki.write "local": Este é o destino final. Ele recebe os logs e os envia para o endpoint do Loki que você especificar .

Instalação:
Com o arquivo alloy-values.yaml criado, execute o comando Helm:

bash
# Adicione o repositório (se ainda não fez)
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Instale o Alloy usando o seu arquivo de valores
helm install alloy grafana/alloy -n monitoring -f alloy-values.yaml
O Helm chart do Alloy, por padrão, já cria um DaemonSet, o que é ideal para coletar logs de todos os nós do seu cluster k3d .

3. Configurar o Data Source no Grafana
O passo final é garantir que o Grafana saiba onde encontrar o Loki. Se você já adicionou o Loki como data source anteriormente (via ConfigMap ou interface), o Alloy começará a enviar logs e eles aparecerão lá automaticamente.

💡 Dica para a PoC: Coleta de Métricas com o Alloy
Como o Alloy também é um coletor de métricas, você pode usá-lo para substituir a necessidade do Prometheus fazer o scraping diretamente. O Alloy possui um componente chamado prometheus.operator.servicemonitors que é capaz de descobrir e respeitar os seus ServiceMonitor customizados . Isso significa que, se você já tem um ServiceMonitor para o seu backend, pode configurar o Alloy para coletar essas métricas e enviá-las para o Prometheus, centralizando ainda mais a coleta.

Para uma PoC, no entanto, manter o Prometheus fazendo o scraping e usar o Alloy apenas para logs já é uma vitória e simplifica o entendimento.





Para integrar Prometheus + Grafana (métricas) e Loki/Promtail (logs) aos pods que rodam no k3d, a abordagem mais prática é usar Helm para instalar a stack de observabilidade no cluster e, em seguida, configurar o Prometheus para descobrir automaticamente os pods da sua aplicação.

O ponto central é: o Prometheus não descobre pods por anotações simples (prometheus.io/scrape); ele usa recursos customizados chamados ServiceMonitor ou PodMonitor . Você precisará criar um desses recursos no seu chart Helm ou aplicar separadamente.

📊 Métricas com Prometheus + Grafana
1. Instalar a stack de monitoramento
Use o chart kube-prometheus-stack, que já inclui Prometheus, Grafana, Alertmanager e exporters .

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```
2. Permitir que o Prometheus descubra ServiceMonitors de outros namespaces
Por padrão, o Prometheus só descobre ServiceMonitors no próprio namespace. Para que ele veja os da sua aplicação (em outro namespace), ajuste os valores na instalação:

```
helm upgrade monitoring prometheus-community/kube-prometheus-stack -n monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false
```
Isso remove a restrição de labels e permite a descoberta global .

3. Criar um ServiceMonitor para sua aplicação
O ServiceMonitor precisa de um Service que aponte para os pods da aplicação e exponha a porta de métricas. Supondo que seu backend exponha métricas na porta 8080 com path /metrics:

```
yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: meu-backend-monitor
  namespace: minha-app  # mesmo namespace do Service
spec:
  selector:
    matchLabels:
      app: meu-backend  # label do seu Service
  endpoints:
  - port: http-metrics   # nome da porta no Service
    path: /metrics
    interval: 30s
```

O Service correspondente precisa ter a label app: meu-backend e uma porta nomeada http-metrics.

4. Acessar o Grafana

```
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```
Obtenha a senha do admin:

```
kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
```
Acesse http://localhost:3000 (usuário admin). O Prometheus já estará configurado como data source .

📝 Logs com Loki + Promtail
⚠️ Aviso importante sobre o Promtail: A ferramenta Promtail foi oficialmente descontinuada (EOL em 2 de março de 2026) . Para uma PoC em 2026, é mais seguro usar o Grafana Alloy (sucessor do Promtail) ou, se quiser manter a simplicidade, usar o Promtail ciente de que é uma solução legada. Abaixo segue o Promtail por ser o que consta no seu PDF, mas considere migrar para o Alloy em uma versão futura.

1. Instalar o Loki (modo monolítico)
Para PoC local, o modo SingleBinary com storage em filesystem é o mais simples:

```
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki -n monitoring \
  --set deploymentMode=SingleBinary \
  --set singleBinary.replicas=1 \
  --set read.replicas=0 \
  --set write.replicas=0 \
  --set backend.replicas=0 \
  --set loki.auth_enabled=false \
  --set loki.storage.type=filesystem
```
Isso sobe um único pod Loki com armazenamento local .

2. Instalar o Promtail (DaemonSet)
O Promtail roda em cada nó do cluster e coleta logs dos pods locais. Como o k3d pode ter múltiplos "nós" (containers), o DaemonSet garante cobertura de todos eles .

```
helm install promtail grafana/promtail -n monitoring \
  --set config.clients[0].url=http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push
```
O endereço loki-gateway é o serviço criado pelo chart do Loki para receber os logs.

3. Adicionar o Loki como data source no Grafana
Crie um ConfigMap com a label grafana_datasource: "1" para que o sidecar do Grafana o detecte automaticamente :

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-loki-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        uid: loki
        url: http://loki-gateway.monitoring.svc.cluster.local
        access: proxy
        isDefault: false

```
Aplique com kubectl apply -f. Após alguns segundos, o Loki aparecerá no menu de data sources do Grafana.

4. Correlacionar métricas e logs
Uma das grandes vantagens do Promtail é usar o mesmo service discovery do Prometheus, o que significa que os logs carregam labels como namespace, pod, container. No Grafana, você pode configurar o data source do Loki para incluir um link para o Prometheus usando esses labels, permitindo pular de um pico de métrica diretamente para os logs daquele pod específico .

💡 Dica para a PoC
Como você já tem um pipeline de infraestrutura separado, inclua os comandos Helm e os manifestos (ServiceMonitor, ConfigMap do Loki) nesse pipeline. Assim, a stack de observabilidade é implantada de forma reprodutível, e o README documenta como acessar o Grafana e validar que as métricas/logs da aplicação estão chegando.

