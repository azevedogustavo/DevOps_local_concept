# 🧠 Decisões Técnicas e Arquiteturais

Este documento consolida as justificativas técnicas, trade-offs analisados e decisões de engenharia adotadas na construção do projeto **DevOps Local Concept**, atendendo e superando os requisitos do edital da Prova de Conceito (POC).

---

## 1. Escolha do Cluster: k3d (K3s em Docker) vs. Kind vs. Minikube vs. RKE2

### 🔍 Cenário e Alternativas Avaliadas:
O edital permitia a escolha entre `kind`, `k3d`, `minikube` ou `RKE2 em VMs`.

| Critério | `k3d` (K3s em Docker) | `kind` (Kubernetes in Docker) | `minikube` | `RKE2` em VMs |
| :--- | :--- | :--- | :--- | :--- |
| **Ingress Controller** | **Nativo (Traefik v3)** pronto para uso | Requer deploy manual do ingress-nginx | Add-on manual | Requer configuração manual |
| **Consumo de Memória** | **Muito baixo (~1.2 GB)** | Médio (~2.0 GB) | Alto (~3.5 GB+) | Muito Alto (exige VMs dedicadas) |
| **Tempo de Startup** | **< 30 segundos** | ~60 segundos | 2 a 4 minutos | Vários minutos |
| **Suporte Multi-node** | Nativo e instantâneo via containers | Suportado | Pesado com driver docker/hypervisor | Complexo via Vagrant/Libvirt |
| **Deploy Progressivo** | Integração nativa TraefikService | Requer NGINX canários ou Istio | Requer Service Mesh | Requer Service Mesh |

### 🎯 Decisão e Justificativa:
Optou-se pelo **k3d**:
1. **Traefik Nativo Integrado**: O k3s já embute o **Traefik Ingress Controller** como provedor padrão, dispensando a instalação de ingress controllers externos propensos a incompatibilidades locais.
2. **Viabilização do Argo Rollouts Canary**: O Traefik v3 fornece suporte nativo ao Custom Resource `TraefikService` com roteamento ponderado (Weighted Round Robin - WRR). Isso permitiu implementar deploy Canary real com controle fino de percentual de tráfego (20% -> 100%) sem o consumo exorbitante de memória de uma Service Mesh como Istio ou Linkerd.
3. **Mapeamento de Portas Simples**: O k3d permite vincular o proxy loadbalancer diretamente às portas do host (`8080:80@loadbalancer`), viabilizando acesso limpo via DNS local no `/etc/hosts`.

---

## 2. Registro de Imagens Local: Harbor v2 vs. Nexus OSS vs. Docker Registry Simples

### 🔍 Cenário e Alternativas Avaliadas:
O edital sugeriu `Harbor ou Nexus`.

| Critério | Harbor v2 | Sonatype Nexus OSS | Docker Registry (V2) |
| :--- | :--- | :--- | :--- |
| **Foco de Uso** | **Nativo para contêineres e artefatos OCI** | Repositório genérico de binários (Maven, NPM) | Registry bare-metal mínimo |
| **Vulnerability Scanning** | **Scanner nativo integrado (Trivy)** | Requer Nexus Pro / plugins pagos | Sem suporte nativo |
| **Gestão de Identidade/RBAC**| Projetos públicos/privados e **Robot Accounts** | Permissões genéricas pesadas | Sem controle de acesso nativo |
| **Suporte a Assinaturas** | Suporte OCI nativo a artefatos **Cosign (.sig)** | Limitado | Apenas armazenamento genérico |
| **Consumo de Recursos** | Moderado (~1.5 GB com core/db/portal) | Alto (JVM / ~2.5 GB+) | Mínimo (< 100 MB) |

### 🎯 Decisão e Justificativa:
Optou-se pelo **Harbor v2**:
1. **Segurança de Supply Chain**: O Harbor oferece suporte de primeira classe a artefatos OCI, permitindo armazenar tanto a imagem Docker quanto a assinatura criptográfica gerada pelo Cosign no mesmo repositório (`poc/minha-app`).
2. **Robot Accounts Granulares**: Facilidade para criar credenciais de máquina dedicadas: uma para push (utilizada pelo GitHub Actions Runner) e outra para pull (`harbor-pull-secret` consumida pelo Kubernetes).
3. **Dupla Camada de Inspeção com Trivy**: O Harbor permite habilitar scan automático ao realizar o push, servindo como uma segunda barreira de proteção complementar ao scan realizado no pipeline de CI.

---

## 3. Aplicação Web: Go 1.26 + Distroless vs. Node.js / Python

### 🔍 Cenário e Alternativas Avaliadas:
O edital solicitava uma "aplicação web simples com endpoint `/healthz` e Dockerfile multi-stage".

### 🎯 Decisão e Justificativa:
Optou-se por **Go (Golang 1.26)** empacotado sobre **Google Distroless**:
1. **Binário Estático Puro**: Com `CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o app .`, o compilador gera um executável único sem qualquer dependência dinâmica de bibliotecas C (`glibc`/`musl`).
2. **Segurança com Distroless (`gcr.io/distroless/static-debian12:nonroot`)**:
   - Não possui shell (`/bin/sh`, `/bin/bash`), gerenciadores de pacote (`apt`, `apk`) ou utilitários GNU.
   - Reduz drasticamente a superfície de ataque: se um atacante comprometer a aplicação, não há interpretador de comandos nem ferramentas disponíveis para movimentação lateral.
   - **Zero vulnerabilidades triviais** no scan do Trivy.
   - Execução nativa como usuário não privilegiado (`USER nonroot:nonroot` - UID `65532`).
3. **Métricas Nativas**: Utilização da biblioteca oficial `github.com/prometheus/client_golang` para expor métricas reais da aplicação em `/metrics` (`http_requests_total`), permitindo integração imediata com o Prometheus sem necessidade de exporters adicionais.

---

## 4. Segurança de Políticas: OPA Gatekeeper E Kyverno (Uso Complementar)

### 🔍 O Dilema de Arquitetura:
O edital exigia: *"Políticas de segurança com Kyverno ou OPA (mínimo: proibir :latest)"*. A maioria dos projetos opta por apenas uma ferramenta. Nesta POC, optou-se por utilizar **ambas**, atribuindo a cada uma a responsabilidade na qual ela é o padrão da indústria.

### 🎯 Por que o OPA Gatekeeper para Bloqueio de `:latest`?
1. **Padrão da Indústria com Rego**: O OPA Gatekeeper é o padrão de fato da Cloud Native Computing Foundation (CNCF) para governança corporativa.
2. **Expressividade e Separação de Responsabilidade**: Implementado através de um `ConstraintTemplate` (`templates.gatekeeper.sh/v1`) e uma `Constraint` (`constraints.gatekeeper.sh/v1beta1`). O template define a lógica Rego para inspecionar `spec.containers[*].image`, validando tanto se termina com `:latest` quanto se a imagem omite a tag.
3. Isso demonstra domínio da linguagem **Rego** e do modelo de validação por admissão do Gatekeeper.

### 🎯 Por que o Kyverno para Verificação de Imagens com Cosign?
1. **Limitação Técnica Crítica do Gatekeeper**:
   - O projeto original `sigstore/cosign-gatekeeper-provider` foi oficialmente **arquivado e descontinuado** pela comunidade Sigstore.
   - A alternativa contemporânea para validar assinaturas no Gatekeeper seria o **Ratify**, o que exigiria instalar um servidor provider adicional, mais CRDs complexos e outro componente em memória, elevando o risco de falhas locais.
2. **Nativo no Kyverno**:
   - O Kyverno possui suporte embutido e de primeira classe a **Cosign** através da diretiva declarativa `verifyImages` em suas `ClusterPolicy`.
   - Lê diretamente a chave pública em formato PEM (`cosign.pub`) e valida a assinatura no registry OCI sem intermediários.
3. **Conclusão Técnica**:
   - **OPA Gatekeeper**: Governança e conformidade estrutural de manifestos (Rego).
   - **Kyverno**: Segurança de Supply Chain e validação criptográfica de imagens.

---

## 5. Motor de CI/CD: Actions Runner Controller (ARC) vs. Runner no Host vs. Jenkins

### 🔍 Cenário e Alternativas Avaliadas:
O edital permitia `Jenkins ou GitHub Actions self-hosted local`.

| Critério | ARC (Actions Runner Controller) | Runner GitHub no Host | Jenkins Local |
| :--- | :--- | :--- | :--- |
| **Local de Execução** | **Pods efêmeros dentro do k3d** | Processo solto na máquina host | Pod ou container independente |
| **Isolamento** | Alto (Docker-in-Docker isolado por job) | Baixo (risco de poluir o host) | Médio (plugins e workspace) |
| **Escala** | Dinâmica (0 a N pods sob demanda) | Estática (1 worker fixo) | Estática ou via plugin k8s |
| **Padrão Moderno** | **Padrão oficial do GitHub para K8s** | Legado | Legado |

### 🎯 Decisão e Justificativa:
Optou-se pelo **Actions Runner Controller (ARC)**:
1. **Modernidade Cloud Native**: O ARC transforma o cluster Kubernetes local em um pool elástico de executores de CI. Os jobs do workflow rodam dentro de Pods no namespace `arc-runners`.
2. **Ambiente Limpo e Reprodutível**: Evita instalar Docker CLI, Cosign, Trivy e binários de build diretamente no sistema operacional da máquina host do desenvolvedor.
3. **Resolução de Rede Interna**: O runner, estando dentro da rede do Kubernetes/Docker, consegue se comunicar com o Harbor (`harbor-core.harbor.svc.cluster.local`) e com o SonarQube com altíssima velocidade e sem necessidade de tunelamentos complexos.

---

## 6. Continuous Delivery & Deploy Progressivo: ArgoCD + Argo Rollouts (Canary)

### 🔍 Cenário e Alternativas Avaliadas:
O edital mencionou como diferenciais opcionais: *"GitOps com ArgoCD"* e *"Blue/Green ou Canary Deployment"*.

### 🎯 Decisão e Justificativa:
Ambos os diferenciais foram implementados em conjunto:
1. **ArgoCD (GitOps)**:
   - Elimina deploys manuais com `kubectl apply` ou `helm upgrade` a partir da máquina local.
   - O repositório Git atua como **Única Fonte da Verdade** (*Single Source of Truth*).
   - O pipeline de CI atualiza a tag da imagem em `charts/minha-app/values.yaml` e realiza o commit. O ArgoCD detecta a divergência e aplica a atualização de forma declarativa e automatizada.
2. **Argo Rollouts (Canary com TraefikService)**:
   - Substitui o Deployment tradicional por um recurso `Rollout`.
   - Utiliza a integração nativa com o **Traefik v3** através do `TraefikService` (`weighted`).
   - Não depende de Service Mesh (como Istio), economizando cerca de 2 GB de RAM no host.
   - Permite mitigar riscos em produção direcionando inicialmente 20% do tráfego para a nova versão antes de autorizar a substituição total.

---

## 7. Observabilidade: kube-prometheus-stack + loki-stack

### 🔍 Cenário e Alternativas Avaliadas:
O edital solicitava: *"Prometheus + Grafana para métricas e Loki/Promtail para logs"*.

### 🎯 Decisão e Justificativa:
1. **kube-prometheus-stack**:
   - Instala de forma orquestrada o **Prometheus Operator**, **Grafana**, **Alertmanager** e exporters essenciais.
   - Facilita a criação de regras de alerta através do CRD `PrometheusRule`.
   - O Grafana foi configurado com sidecar ativo (`grafana_datasource: "1"`), permitindo adicionar novas fontes de dados (como o Loki) via ConfigMaps versionados no Git.
2. **Loki + Promtail**:
   - O Loki atua no modo monolítico local com armazenamento em filesystem, consumindo pouquíssima CPU/memória.
   - O Promtail roda como DaemonSet lendo os arquivos de log do containerd no caminho `/var/log/pods`.
   - No Grafana, logs e métricas podem ser correlacionados de forma fluida usando labels como `namespace="default"` e `app="minha-app"`.

---

## 8. Assinatura Digital de Imagens: Sigstore Cosign por Digest SHA256

### 🔍 Cenário e Alternativas Avaliadas:
Assinatura de imagens por tag mutável (`app:1.0.0`) vs. assinatura por digest imutável (`app@sha256:...`).

### 🎯 Decisão e Justificativa:
1. **Imutabilidade e Segurança Criptográfica**:
   - Tags Docker são mutáveis (podem ser sobrescritas no registry).
   - O pipeline inspeciona a imagem gerada com `docker inspect --format='{{index .RepoDigests 0}}'` e executa `cosign sign` especificamente sobre o hash SHA256 imutável.
   - A política do Kyverno (`verifyImages`) valida o digest exato, garantindo que o contêiner executado no cluster é bit a bit idêntico ao artefato que passou com sucesso pelos testes e scanners de segurança.

---

## 📊 Matriz Comparativa Resumida

| Componente | Opção Escolhida | Principal Motivo da Escolha |
| :--- | :--- | :--- |
| **Cluster** | **k3d** | Traefik nativo, leveza, suporte direto a Canary via TraefikService |
| **Registry** | **Harbor v2** | Scanner Trivy integrado, Robot accounts, suporte a OCI Cosign |
| **Aplicação** | **Go + Distroless** | Binário estático puro, zero CVEs, endpoints `/healthz` e `/metrics` |
| **SAST** | **SonarQube Community** | Análise estática profunda de vulnerabilidades e qualidade de código |
| **Scan de Imagem**| **Trivy** | Scanner rápido, confiável e integrado ao pipeline e ao Harbor |
| **Assinatura** | **Cosign** | Assinatura OCI sem PKI complexa, chaves efêmeras ou pares PEM |
| **Políticas** | **OPA + Kyverno** | OPA para regras Rego (:latest) e Kyverno para validação Cosign |
| **GitOps** | **ArgoCD** | Reconciliação declarativa contínua a partir do repositório Git |
| **Deploy** | **Argo Rollouts** | Estratégia progressiva Canary com pesos reais no Traefik |
| **Métricas** | **Prometheus Operator**| Descoberta de serviços dinâmica e gerenciamento de alertas |
| **Logs** | **Loki + Promtail** | Agregação leve de logs sem overhead de Elasticsearch |
| **Visualização** | **Grafana** | Centralização de métricas e logs com dashboards integrados |
