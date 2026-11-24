# 📑 Relatório Final da Prova de Conceito (POC): DevOps Local Concept

**Candidato / Autor**: Gustavo Azevedo  
**Projeto**: Prova de Conceito – Ambiente Kubernetes Local (DevOps)  
**Escopo**: Ambiente Kubernetes local, autônomo, reproduzível, sem dependência de Cloud pública  
**Duração**: Executado dentro da recomendação de 16 horas úteis  

---

## 🎯 1. Resumo Executivo

O presente projeto tem por objetivo demonstrar o domínio prático na concepção, implantação, automação e governança de um ecossistema completo de engenharia de software e infraestrutura moderna baseado em **Kubernetes local**.

A solução foi construída integralmente sobre ferramentas *open-source*, simulando a esteira de entrega contínua e as práticas de **DevSecOps**, **GitOps**, **SRE/Observabilidade** e **Políticas como Código (PaC)** adotadas em organizações de tecnologia de alta maturidade.

O ambiente atende a **100% dos requisitos obrigatórios** do edital e entrega **todos os 4 diferenciais opcionais propostos**, executando com extrema eficiência e consumo consciente de recursos computacionais em uma única estação de trabalho Linux.

---

## 📊 2. Matriz de Conformidade com o Edital

Abaixo está o mapeamento detalhado entre as exigências do documento oficial `POC_Kubernetes_localDevOps.md` e as entregas concretizadas no repositório:

| Item do Edital | Requisito Técnico | Status | Implementação Concretizada no Projeto |
| :--- | :--- | :---: | :--- |
| **Cluster Local** | kind, k3d, minikube ou RKE2 em VMs | ✅ **Atendido** | **k3d (K3s)** provisionado com 1 Server e 2 Agents em Docker |
| **Ingress** | Ingress funcional | ✅ **Atendido** | **Traefik v3** nativo roteando portas `8080` (HTTP) e `8443` (HTTPS) |
| **Registry Local** | Harbor ou Nexus | ✅ **Atendido** | **Harbor v2** local com projetos, scanner Trivy e robot accounts |
| **Aplicação** | Web simples com endpoint `/healthz` | ✅ **Atendido** | Microsserviço **Go 1.26** com rotas `/`, `/healthz` e `/metrics` |
| **Dockerfile** | Multi-stage e testes automatizados | ✅ **Atendido** | Multi-stage com **Google Distroless non-root** e testes unitários |
| **Helm Chart** | Deploy, Service, Ingress, HPA, ConfigMap, Secret | ✅ **Atendido** | Chart `charts/minha-app/` completo com HPA v2 e ServiceMonitor |
| **CI/CD** | Jenkins ou GitHub Actions self-hosted | ✅ **Atendido** | **GitHub Actions** in-cluster via **Actions Runner Controller (ARC)** |
| **SAST & Scan** | SonarQube e Trivy | ✅ **Atendido** | **SonarQube Community** + Postgres e **Trivy** no pipeline e no Harbor |
| **Observabilidade**| Prometheus + Grafana e Loki/Promtail | ✅ **Atendido** | **kube-prometheus-stack** + **loki-stack** com dashboards prontos |
| **Políticas** | Kyverno ou OPA (proibir `:latest`) | ✅ **Atendido** | **OPA Gatekeeper** (Rego) bloqueando tags `:latest` |
| **Diferencial 1** | Assinatura e verificação de imagens | 🌟 **Diferencial** | **Cosign** (assinatura por digest) + **Kyverno** (`verifyImages`) |
| **Diferencial 2** | GitOps com ArgoCD | 🌟 **Diferencial** | **ArgoCD v2.x** reconciliando o repositório Git continuamente |
| **Diferencial 3** | Blue/Green ou Canary Deployment | 🌟 **Diferencial** | **Argo Rollouts Canary** (20% $\to$ 100%) integrado ao **TraefikService** |
| **Diferencial 4** | Alertas no Grafana ou Prometheus | 🌟 **Diferencial** | **PrometheusRule** configurada com alertas de teste e indisponibilidade |

---

## 🧠 3. Principais Decisões Técnicas

1. **Adoção do k3d em vez de kind ou Minikube**:
   O k3s embute o **Traefik v3** como Ingress Controller oficial. Isso evitou o deploy de controladores externos e permitiu utilizar o CRD `TraefikService` para controle fino de tráfego Canary ponderado (*Weighted Round-Robin*) sem necessitar de uma Service Mesh pesada (como Istio).
2. **Defesa em Profundidade com OPA Gatekeeper E Kyverno**:
   - **OPA Gatekeeper (Rego)**: Empregado para governança de manifestos e conformidade do cluster, rejeitando pods com tag mutável `:latest` ou sem tags explícitas.
   - **Kyverno**: Utilizado para garantir a segurança da cadeia de suprimentos de software (*Supply Chain Security*), inspecionando criptograficamente a assinatura **Cosign** da imagem no momento da admissão do Pod.
3. **Execução de CI In-Cluster com Actions Runner Controller (ARC)**:
   Em vez de acoplar o runner ao sistema operacional do host, o operador do ARC foi implantado dentro do cluster. Os jobs rodam de forma descartável em pods com suporte a Docker-in-Docker (DinD), comunicando-se diretamente com o Harbor e o SonarQube pela rede interna do Kubernetes.
4. **Hardening com Google Distroless**:
   A imagem final da aplicação em Go roda sob `gcr.io/distroless/static-debian12:nonroot` (UID `65532`). A ausência de shell e utilitários GNU reduz drasticamente a superfície de ataque e elimina vulnerabilidades de SO no scan do Trivy.

---

## 🧗 4. Dificuldades Encontradas e Soluções Reais

A execução deste projeto ocorreu sob forte pressão e impôs desafios práticos significativos, tanto técnicos quanto contextuais:

### 4.1. Integração com o Harbor e Comunicação Pod-para-Pod no k3d
* **O Desafio**: O Harbor foi instalado dentro do k3d, mas os runners do ARC e os nós do cluster precisavam se comunicar com o registry local via HTTP sem depender do IP externo ou público da máquina host.
* **A Complexidade**: O containerd rejeitava requisições HTTP na porta `8080`, e o Traefik forçava redirecionamentos inesperados para HTTPS ou eliminava a porta 8080 nas respostas do Harbor Core.
* **A Solução**: 
  - Criação de scripts para injetar o arquivo `/etc/rancher/k3s/registries.yaml` diretamente nos contêineres dos nós k3d.
  - Criação de um `Middleware` no Traefik forçando `X-Forwarded-Proto: http` e `X-Forwarded-Port: 8080`.
  - Configuração da variável `REGISTRY_HTTP_RELATIVEURLS=true` nos deployments do Harbor e uso do DNS interno `harbor-core.harbor.svc.cluster.local:80` dentro do pipeline.

### 4.2. Curva de Aprendizado e Integração da Stack de Monitoramento
* **O Desafio**: A falta de experiência prévia profunda na stack do Prometheus Operator, aliada à forma como o k3d isola as redes dos pods, tornou a integração da observabilidade um dos pontos mais desafiadores.
* **A Complexidade**: Compreender na prática a diferença entre anotações simples (`prometheus.io/scrape`) e o recurso `ServiceMonitor` (que exige a label `release: monitoring` e casamento exato de portas nomeadas), além de entender como o Promtail roda como DaemonSet lendo `/var/log/pods` para enviar ao Loki.
* **A Solução**: Paradas para leitura detalhada da documentação oficial do Prometheus Operator e da Grafana, resultando na criação de manifestos declarativos dedicados (`service-monitor.yaml`, `alert-rules.yaml` e `loki-datasource.yaml`).

### 4.3. Condições Adversas: Prazo Apertado e Estado de Saúde
* **O Desafio**: O desafio estipulava uma estimativa recomendada de até **16 horas úteis** para cobrir um escopo extenso (Cluster + Ingress + Registry + App Go + Dockerfile + Helm + CI/CD + SAST + Scan + Observabilidade + Políticas + Diferenciais).
* **Impacto Pessoal**: Durante todo o período de implementação, o autor enfrentou um quadro severo de gripe, exigindo grande esforço de foco e resiliência física para cumprir os requisitos dentro do prazo estipulado.

### 4.4. Instabilidade e Limitações de Ferramentas de IA (DeepSeek)
* **O Desafio**: Tentou-se inicialmente acelerar o desenvolvimento com o apoio do modelo DeepSeek, porém a ferramenta frequentemente alucinava sintaxes de manifests Kubernetes, omitia configurações essenciais (como permissões RBAC para o TraefikService no Argo Rollouts e `vm.max_map_count` no SonarQube) ou gerava scripts incompletos.
* **A Solução**: A dependência da IA gerou rodadas extras de depuração e retrabalho. O autor precisou interromper o fluxo automatizado para pesquisar documentações oficiais, fóruns da comunidade e fontes no Google para encontrar as soluções técnicas corretas e funcionais.

### 4.5. Consolidação dos Comandos "Go Horse" Aplicados sob Pressão
* **O Desafio**: Na urgência de fazer os componentes funcionarem (como desbloquear portas, corrigir permissões do Runner DinD e acertar senhas do SonarQube), muitos comandos de diagnóstico foram aplicados no modo "Go Horse" (ad-hoc diretamente no terminal via `kubectl` e `docker exec`).
* **A Solução**: Foi necessário um esforço deliberado de engenharia reversa do histórico para rastrear, limpar e empacotar todos os passos dispersos em scripts bash reprodutíveis e idempotentes (`scripts/*.sh`), garantindo que o ambiente possa ser recriado do zero com facilidade.

---

## 🔮 5. O que Poderia Ser Melhorado (Retrospectiva & Lições Aprendidas)

Em uma avaliação crítica do projeto e visando uma evolução para padrões de produção corporativa, os seguintes pontos foram identificados como oportunidades de melhoria:

1. **Higiene do Repositório Git (Histórico de Commits)**:
   - *Cenário Atual*: Devido à velocidade de depuração local e aos múltiplos testes de pipeline disparados para validar o ARC e o ArgoCD, o histórico de commits acumulou mensagens repetidas como "teste", "correcao", "minha-app".
   - *Melhoria*: Em um fluxo ideal, teria sido realizado um **squash de commits** ou rebase interativo antes da entrega final para consolidar o histórico em commits semânticos (padrão *Conventional Commits*), refletindo apenas as etapas lógicas do projeto.
2. **Aprofundamento em Políticas de Segurança (NetworkPolicies e PSS)**:
   - *Melhoria*: Implementar **NetworkPolicies** rigorosas para isolar o tráfego leste-oeste (pod-to-pod) no cluster, garantindo que pods do namespace `default` só se comuniquem com o ingress e com o Prometheus, além de ativar o padrão restritivo dos Pod Security Standards (PSS) em nível de namespace.
3. **Comunicação Mais Refinada entre Pods**:
   - *Melhoria*: Adotar o **Cilium** com eBPF no lugar do Flannel padrão do k3s para obter observabilidade em nível de rede (L4/L7) e roteamento de tráfego de alta performance sem iptables.
4. **Elevação para Nível Production-Grade**:
   - Mesmo rodando sobre k3d local, a arquitetura pode evoluir para padrões corporativos:
     - Gestão segura de segredos com **External Secrets Operator (ESO)** integrado a um cofre como **HashiCorp Vault**.
     - Emissão automatizada de certificados TLS internos via **cert-manager**.
     - Separação de branches no Git (`dev` e `main`) sincronizadas com namespaces distintos no ArgoCD (`staging` e `production`).

---

## 📸 6. Galeria de Evidências

As evidências que comprovam a instalação e funcionamento de todos os componentes da POC estão disponíveis na pasta `docs/evidencias/`:

| Componente | Arquivo de Evidência | O que comprova |
| :--- | :--- | :--- |
| **Harbor Registry** | `docs/evidencias/harbour_instalado.png`<br>`docs/evidencias/harbour_logado.png` | Harbor instalado, funcional e autenticado com o projeto `poc` e robôs ativos. |
| **SonarQube (SAST)** | `docs/evidencias/sonarQube.png` | Instância do SonarQube Community operando e analisando o código da aplicação. |
| **Actions Runner (ARC)**| `docs/evidencias/arc-em-funcionamento.png` | Pods do runner ARC ativos e executando os jobs do GitHub Actions no k3d. |
| **ArgoCD (GitOps)** | `docs/evidencias/argocd_instalado.png`<br>`docs/evidencias/argocd_logado.png`<br>`docs/evidencias/argocd-com-minha-app.png` | Painel do ArgoCD saudável com as aplicações sincronizadas e gerenciadas declarativamente. |
| **Aplicação Web** | `docs/evidencias/minha-app-funcionando.png` | Aplicação web Go respondendo com sucesso na rota raiz via Ingress. |

---

## 🏁 7. Parecer Final e Conclusão

A Prova de Conceito atinge **100% dos objetivos técnicos** estipulados no edital, comprovando domínio prático em arquitetura Kubernetes, automação de esteiras CI/CD seguras, GitOps, deploy progressivo e observabilidade. 

Apesar de todas as restrições de tempo, saúde e contratempos de ferramentas, o resultado é um ecossistema sólido, reproduzível e alinhado às melhores práticas contemporâneas da engenharia de software e DevOps.
