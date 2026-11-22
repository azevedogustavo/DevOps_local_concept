# 🏗️ Arquitetura da Solução: DevOps Local Concept

Este documento descreve detalhadamente a arquitetura de engenharia da Prova de Conceito (POC) de ambiente Kubernetes local, concebida para operar de forma 100% autônoma na máquina do desenvolvedor, sem dependências de nuvens públicas (Cloud-free).

---

## 📌 1. Visão Geral da Arquitetura

O ambiente foi projetado para simular uma esteira corporativa completa de **DevSecOps**, **GitOps**, **Observabilidade** e **Deploy Progressivo (Canary)**. Toda a stack roda em um cluster local Kubernetes provisionado sobre containers Docker via **k3d**, combinando baixo consumo de recursos e alta fidelidade com clusters de produção.

### Pilares Fundamentais:
1. **Cluster Local & Roteamento**: Kubernetes k3s via `k3d` com o controlador de Ingress **Traefik v3** nativo, expondo portas centrais (`8080` HTTP e `8443` HTTPS) para o host.
2. **Container Registry Local Privado**: **Harbor v2** gerenciando imagens de contêineres locais, repositórios OCI e artefatos de assinatura.
3. **CI/CD In-Cluster (DevSecOps)**: GitHub Actions acionado por agentes efêmeros locais via **Actions Runner Controller (ARC)**, orquestrando testes, análise estática de código (SAST) com **SonarQube**, verificação de vulnerabilidades com **Trivy**, push e assinatura digital com **Cosign**.
4. **GitOps & Continuous Delivery**: **ArgoCD** reconciliando o repositório Git com o cluster de forma declarativa.
5. **Estratégia de Deploy Progressivo**: **Argo Rollouts** realizando deploys do tipo **Canary** com controle dinâmico de tráfego via **TraefikService** (Weighted Round-Robin).
6. **Segurança em Camadas (Defense in Depth)**: **OPA Gatekeeper** (validação de tags mutáveis `:latest` via Rego) e **Kyverno** (verificação criptográfica de imagens assinadas com Cosign).
7. **Observabilidade Unificada**: Métricas coletadas pelo **Prometheus Operator** (`kube-prometheus-stack`), logs ingeridos pelo **Loki** com **Promtail**, dashboards no **Grafana** e regras de alerta ativas.

---

## 📐 2. Diagrama da Topologia Completa

```mermaid
flowchart TB
    subgraph HOST["💻 Máquina Host (Linux Developer)"]
        BROWSER["🌐 Navegador Web & cURL<br/>(127.0.0.1:8080 / 8443)"]
        GIT_REPO["📁 Repositório Git (GitHub)<br/>DevOps_local_concept"]

        subgraph K3D_CLUSTER["☸️ Cluster k3d: poc-cluster (Docker-in-Docker)"]
            
            subgraph INGRESS_LAYER["Camada de Entrada & Roteamento"]
                LB["k3d LoadBalancer (Proxy :80 / :443)"]
                TRAEFIK["Traefik Ingress Controller v3"]
                LB --> TRAEFIK
            end

            subgraph SEC_LAYER["🛡️ Políticas & Admissão (Admission Webhooks)"]
                OPA["OPA Gatekeeper<br/>(Bloqueia :latest via Rego)"]
                KYVERNO["Kyverno Controller<br/>(Valida Assinatura Cosign)"]
            end

            subgraph GITOPS_LAYER["🔄 GitOps & Rollouts"]
                ARGOCD["ArgoCD Server & Controller<br/>(ns: argocd)"]
                ROLLOUT_CTRL["Argo Rollouts Controller<br/>(ns: argo-rollouts)"]
            end

            subgraph CI_RUNNERS["🚀 CI Engine (Runner In-Cluster)"]
                ARC_CTRL["ARC Controller<br/>(ns: arc-systems)"]
                RUNNER_POD["GitHub Runner Pod (DinD)<br/>(ns: arc-runners)"]
                ARC_CTRL --> RUNNER_POD
            end

            subgraph INFRA_SVCS["🧰 Serviços de Infraestrutura"]
                HARBOR["Harbor Registry v2<br/>(ns: harbor)"]
                SONAR["SonarQube + PostgreSQL<br/>(ns: sonarqube)"]
            end

            subgraph APP_NS["📦 Aplicação: Minha-App (ns: default)"]
                TRAEFIK_WRR["TraefikService (WRR)<br/>minha-app-wrr"]
                SVC_STABLE["Service<br/>minha-app-stable (80%)"]
                SVC_CANARY["Service<br/>minha-app-canary (20%)"]
                POD_STABLE["Pods Estáveis (v1)<br/>Distroless / Go"]
                POD_CANARY["Pods Canary (v2)<br/>Distroless / Go"]
                HPA["HorizontalPodAutoscaler<br/>(2 a 5 réplicas)"]

                TRAEFIK_WRR -->|80% peso| SVC_STABLE --> POD_STABLE
                TRAEFIK_WRR -->|20% peso| SVC_CANARY --> POD_CANARY
                HPA -.->|Escala CPU| POD_STABLE
            end

            subgraph SRE_STACK["📊 Observabilidade (ns: monitoring)"]
                PROM["Prometheus Server<br/>(kube-prometheus-stack)"]
                GRAFANA["Grafana Dashboards"]
                LOKI["Grafana Loki"]
                PROM_RULE["PrometheusRule<br/>(Alerta de Teste)"]

                PROM --> GRAFANA
                LOKI --> GRAFANA
                PROM_RULE -.-> PROM
            end

        end
    end

    %% Roteamentos externos
    BROWSER -->|minha-app.local:8080| LB
    BROWSER -->|argocd.local:8080| LB
    BROWSER -->|harbor.local:8080| LB
    BROWSER -->|sonar.local:8080| LB
    BROWSER -->|grafana.local:8080| LB
    BROWSER -->|rollouts.local:8080| LB

    %% Roteamentos internos Traefik
    TRAEFIK -->|Host: minha-app.local| TRAEFIK_WRR
    TRAEFIK -->|Host: argocd.local| ARGOCD
    TRAEFIK -->|Host: harbor.local| HARBOR
    TRAEFIK -->|Host: sonar.local| SONAR
    TRAEFIK -->|Host: grafana.local| GRAFANA
    TRAEFIK -->|Host: rollouts.local| ROLLOUT_CTRL

    %% Interações GitOps e CI
    GIT_REPO <-->|Webhooks / Polling| ARGOCD
    RUNNER_POD -->|Build & SAST| SONAR
    RUNNER_POD -->|Push Imagem & Cosign| HARBOR
    RUNNER_POD -->|Atualiza Tag no Helm| GIT_REPO
    ARGOCD -->|Aplica Manifestos| APP_NS
    ROLLOUT_CTRL -->|Gerencia Pesos| TRAEFIK_WRR

    %% Validação de Admissão
    KYVERNO -.->|Intercepta Create Pod| APP_NS
    OPA -.->|Intercepta Create Pod| APP_NS
    KYVERNO -.->|Verifica Assinatura OCI| HARBOR

    %% Monitoramento
    PROM -.->|Scrape /metrics| APP_NS
```

---

## 🌐 3. Mapeamento de Rede e DNS Local

Para viabilizar o acesso unificado por nome em vez de portas aleatórias, as portas HTTP (`8080`) e HTTPS (`8443`) do host são roteadas diretamente para o Traefik Ingress Controller através do balanceador de carga do k3d.

Configuração do `/etc/hosts` no host:
```text
127.0.0.1 minha-app.local harbor.local argocd.local sonar.local rollouts.local grafana.local
```

### Matriz de Endereçamento e Serviços:

| Host DNS Local | Porta Host | Namespace | Serviço Interno Kubernetes | Ingress Controller | Finalidade |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `minha-app.local` | `8080` | `default` | `minha-app-wrr` (TraefikService) | Traefik v3 | Endpoint da aplicação Go com roteamento Canary |
| `harbor.local` | `8080` | `harbor` | `harbor-portal:80` | Traefik v3 | Registry privado local OCI e scanner Trivy |
| `argocd.local` | `8080` | `argocd` | `argocd-server:80` | Traefik v3 | Interface e API do ArgoCD (GitOps) |
| `sonar.local` | `8080` | `sonarqube` | `sonarqube-sonarqube:9000` | Traefik v3 | Dashboard e API do SonarQube Community |
| `rollouts.local` | `8080` | `argo-rollouts` | `argo-rollouts-dashboard:3100` | Traefik v3 | Interface visual do Argo Rollouts |
| `grafana.local` | `8080` | `monitoring` | `monitoring-grafana:80` | Traefik v3 | Dashboards de métricas (Prometheus) e logs (Loki) |

---

## 🔄 4. Fluxos Operacionais de Ponta a Ponta

### 4.1. Fluxo de CI/CD DevSecOps (Pipeline Automatizado)
O pipeline (`.github/workflows/ci-devsecops.yml`) roda integralmente dentro do cluster k3d através do Actions Runner Controller (ARC):

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Desenvolvedor
    participant Git as GitHub Repo
    participant ARC as Runner Pod (ARC)
    participant Sonar as SonarQube
    participant Trivy as Trivy Scanner
    participant Harbor as Harbor Registry
    participant Cosign as Cosign CLI
    participant Argo as ArgoCD

    Dev->>Git: git push origin main
    Git->>ARC: Dispara Job no runner arc-runner-set
    ARC->>ARC: Checkout do código (fetch-depth: 0)
    ARC->>ARC: Executa testes unitários Go & gera coverage.out
    ARC->>Sonar: Envia análise de código estático (SAST)
    Sonar-->>ARC: Valida Quality Gate
    ARC->>ARC: Build da imagem Docker (Multi-stage Distroless)
    ARC->>Trivy: Executa scan de vulnerabilidades (CRITICAL, HIGH)
    Trivy-->>ARC: Relatório de segurança aprovado
    ARC->>Harbor: Login e Docker Push (tag por SHA do commit)
    ARC->>Cosign: Assina o digest da imagem com chave privada
    Cosign->>Harbor: Envia assinatura OCI (.sig) associada ao digest
    ARC->>Git: Atualiza tag da imagem em charts/minha-app/values.yaml [skip ci]
    Argo->>Git: Detecta alteração na branch main
    Argo->>Argo: Dispara sincronização declarativa no cluster
```

---

### 4.2. Fluxo de Deploy Progressivo (Canary com TraefikService)
Em vez de utilizar o Deployment padrão do Kubernetes com RollingUpdate, a aplicação adota o Custom Resource **Rollout** gerenciado pelo **Argo Rollouts**:

```mermaid
flowchart LR
    REQ["Requisições HTTP<br/>(minha-app.local:8080)"]
    IR["IngressRoute Traefik<br/>Host(minha-app.local)"]
    TS["TraefikService WRR<br/>minha-app-wrr"]
    
    STABLE["Service Stable<br/>minha-app-stable (80%)"]
    CANARY["Service Canary<br/>minha-app-canary (20%)"]
    
    PODS_V1["Pods Versão Atual (v1)"]
    PODS_V2["Pods Nova Versão (v2)"]

    REQ --> IR --> TS
    TS -->|80% do tráfego| STABLE --> PODS_V1
    TS -->|20% do tráfego| CANARY --> PODS_V2
```

1. Quando uma nova tag de imagem é submetida pelo pipeline, o Argo Rollouts detecta a mudança.
2. É criado um ReplicaSet Canary executando a nova versão.
3. O controlador do Argo Rollouts altera dinamicamente a definição do `TraefikService` para rotear **20%** do tráfego para os novos pods e **80%** para os pods estáveis.
4. Após uma pausa de observação (1 minuto configurado na POC), o tráfego é promovido para **100%** e os pods antigos são finalizados com segurança.

---

### 4.3. Fluxo de Segurança em Camadas (Admission Controllers)
O cluster implementa uma defesa em profundidade com dois controladores de admissão agindo em sinergia:

```mermaid
flowchart TD
    API["kube-apiserver: Requisição de Criação de Pod"]
    
    subgraph OPA_GATEKEEPER["1. OPA Gatekeeper (Rego)"]
        CHK_TAG{"A tag da imagem<br/>é ':latest' ou vazia?"}
        DENY_OPA["❌ REJEITADO:<br/>Tag :latest proibida por política"]
    end

    subgraph KYVERNO_ENGINE["2. Kyverno (Supply Chain Security)"]
        CHK_SIG{"A imagem possui<br/>assinatura Cosign válida<br/>com a chave da PoC?"}
        DENY_KYV["❌ REJEITADO:<br/>Imagem não assinada ou chave inválida"]
    end

    ALLOW["✅ APROVADO:<br/>Pod agendado no cluster"]

    API --> CHK_TAG
    CHK_TAG -- Sim --> DENY_OPA
    CHK_TAG -- Não --> CHK_SIG
    CHK_SIG -- Não --> DENY_KYV
    CHK_SIG -- Sim --> ALLOW
```

- **OPA Gatekeeper**: Utiliza um `ConstraintTemplate` e uma `Constraint` baseados em Rego para impedir que contêineres utilizem a tag mutável `:latest` ou submetam imagens sem tag definida.
- **Kyverno**: Utiliza uma `ClusterPolicy` com a diretiva `verifyImages` para inspecionar criptograficamente a assinatura no registry Harbor contra a chave pública pública Cosign (`cosign.pub`).

---

### 4.4. Fluxo de Observabilidade e SRE
- **Métricas da Aplicação**: A aplicação Go exporta métricas nativas do Prometheus no endpoint `/metrics` (`http_requests_total`). O Prometheus Operator realiza o scrape automaticamente por meio das anotações `prometheus.io/scrape: "true"` e `prometheus.io/port: "80"`.
- **Logs Centralizados**: O DaemonSet do **Promtail** lê os logs de contêineres diretamente de `/var/log/pods` nos nós do cluster e encaminha para o **Loki**.
- **Visualização Integrada**: O Grafana é provisionado com datasources automáticos (Prometheus e Loki) via sidecar com a label `grafana_datasource: "1"`.
- **Alertas**: A regra `manifests/monitoring/prometheus-alert-rule.yaml` injeta um alerta de validação (`AlertaDeTeste`) associado à release `monitoring`.

---

## 📋 5. Tabela de Componentes e Namespaces

| Namespace | Componente / Ferramenta | Papel na Arquitetura | Método de Instalação |
| :--- | :--- | :--- | :--- |
| `kube-system` | **Traefik v3** | Ingress Controller nativo do k3s | Built-in k3d |
| `harbor` | **Harbor v2** | Registry privado de imagens locais & OCI | Helm Chart (`scripts/install-harbor.sh`) |
| `sonarqube` | **SonarQube Community + PostgreSQL** | Análise estática de código (SAST) | Helm Chart (`scripts/install-sonarqube.sh`) |
| `arc-systems` | **ARC Scale Set Controller** | Operador do GitHub Actions Runner | Helm OCI (`scripts/install-arc.sh`) |
| `arc-runners` | **ARC Runner Set** | Pods executores do GitHub Actions com DinD | Helm OCI (`scripts/install-arc.sh`) |
| `argocd` | **ArgoCD v2.x** | Motor de GitOps para sincronização contínua | Helm Chart (`scripts/install-argocd.sh`) |
| `argo-rollouts`| **Argo Rollouts** | Controlador de estratégias de deploy (Canary) | Helm Chart (`scripts/install-rollouts.sh`) |
| `gatekeeper-system` | **OPA Gatekeeper** | Validador de conformidade e políticas Rego | Helm Chart / ArgoCD App (`apps/opa.yaml`) |
| `kyverno` | **Kyverno v1.13+** | Validador de supply chain e assinaturas Cosign | Helm Chart / ArgoCD App (`apps/kyverno.yaml`) |
| `monitoring` | **kube-prometheus-stack** | Prometheus, Grafana, Alertmanager | Helm Chart / ArgoCD App (`apps/monitoring.yaml`) |
| `monitoring` | **loki-stack** | Loki e Promtail para agregação de logs | Helm Chart / ArgoCD App (`apps/loki.yaml`) |
| `default` | **Minha-App** | Aplicação web Go, HPA, IngressRoute, Rollout | Helm Chart / ArgoCD App (`apps/aplicacao.yaml`) |

---

## 🔒 6. Isolamento e Segurança Operacional

1. **Execução sem Root**: A aplicação roda no contêiner sob o usuário não privilegiado `nonroot:nonroot` do Google Distroless (`UID 65532`).
2. **Cluster Local Seguro**: Todo o tráfego do registry e dos runners trafega pela rede interna virtual do Docker (`k3d-poc-cluster`), sem expor portas sensíveis diretamente à rede externa.
3. **Imutabilidade e Rastreabilidade**: Cada versão entregue possui identificação única atrelada ao SHA do commit do Git, assinada criptograficamente via Cosign com chaves geradas sob demanda.
