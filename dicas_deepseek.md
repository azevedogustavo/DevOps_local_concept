📁 Estrutura Proposta do Repositório
text
devops-local-poc/
│
├── README.md                          # Documentação principal (passo a passo, rollback, troubleshooting)
├── .gitignore                         # Ignorar segredos, kubeconfig, binários
│
├── docs/                              # Documentação complementar e evidências
│   ├── arquitetura.md                 # Diagrama e descrição da arquitetura
│   ├── decisoes-tecnicas.md           # Justificativas (k3d, OPA+Kyverno, Alloy, etc.)
│   ├── relatorio-final.md             # Relatório final (decisões, dificuldades, melhorias)
│   ├── troubleshooting.md             # Problemas comuns e soluções
│   └── evidencias/                    # Prints, saídas de comandos, dashboards
│       ├── pipeline-sonar-trivy.png
│       ├── argocd-sync.png
│       ├── grafana-dashboard.png
│       ├── kyverno-bloqueio.png
│       └── ...
│
├── apps/                              # Applications do ArgoCD (App of Apps)
│   ├── root-app.yaml                  # Application raiz (a única aplicada manualmente)
│   ├── aplicacao.yaml                 # Application filha: chart Helm da app
│   ├── monitoring.yaml                # Application filha: kube-prometheus-stack
│   ├── loki.yaml                      # Application filha: Loki + Alloy
│   ├── opa.yaml                       # Application filha: OPA Gatekeeper + políticas
│   └── kyverno.yaml                   # Application filha: Kyverno + política verifyImages
│
├── charts/                            # Charts Helm
│   └── minha-app/                     # Chart Helm da aplicação
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── hpa.yaml
│           ├── configmap.yaml
│           └── secret.yaml
│
├── manifests/                         # Manifestos Kubernetes "puros" (não-Helm)
│   ├── policies/
│   │   ├── opa/
│   │   │   ├── disallow-latest-template.yaml
│   │   │   └── disallow-latest-constraint.yaml
│   │   └── kyverno/
│   │       └── verify-signed-images.yaml
│   ├── ingress/
│   │   └── argocd-ingress.yaml
│   └── monitoring/
│       ├── grafana-loki-datasource.yaml
│       └── prometheus-alert-rule.yaml
│
├── src/                               # Código da aplicação
│   ├── frontend/
│   │   ├── Dockerfile
│   │   └── ...
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── app.py (ou equivalente)
│   │   └── ...
│   └── database/
│       ├── Dockerfile
│       └── init.sql
│
├── .github/                           # Pipeline CI/CD (GitHub Actions)
│   └── workflows/
│       ├── build-apps.yml             # Matrix: frontend, backend, database
│       ├── build-image.yml            # Workflow reutilizável (teste + SAST + build + scan + push + sign)
│       ├── deploy-monitoring.yml      # Pipeline de infraestrutura (observabilidade)
│       └── deploy-policies.yml        # Pipeline de infraestrutura (políticas de segurança)
│
├── scripts/                           # Scripts auxiliares
│   ├── install-k3d.sh                 # Instala k3d + kubectl
│   ├── create-cluster.sh              # Cria o cluster com portas mapeadas
│   ├── install-harbor.sh              # Instala o Harbor
│   ├── install-argocd.sh              # Instala o ArgoCD
│   ├── install-arc.sh                 # Instala o ARC (GitHub Runner)
│   ├── cosign-sign.sh                 # Assina a imagem
│   └── cleanup.sh                     # Remove o cluster e recursos
│
└── kubeconfig/                        # (Ignorado no .gitignore) kubeconfig local
🏷️ Nome do Repositório
Sugiro devops-local-poc ou k3d-devops-poc. Ambos são descritivos e seguem a convenção kebab-case comum em repositórios. Evite nomes genéricos como poc ou teste.

📄 Papel de Cada Pasta
Pasta	Papel
docs/	Toda a documentação e evidências. Os prints ficam em docs/evidencias/ para serem referenciados no README.
apps/	As Applications do ArgoCD. A root-app.yaml é a única aplicada manualmente; as demais são criadas por ela.
charts/	O chart Helm da aplicação. Mantido separado de manifests/ porque é um artefato versionado e reutilizável.
manifests/	Manifestos Kubernetes que não fazem parte do chart Helm (políticas, data sources, Ingress do ArgoCD).
src/	Código-fonte da aplicação (frontend, backend, database). Separado do chart para deixar claro o que é código e o que é infraestrutura.
.github/workflows/	Pipelines do GitHub Actions. O build-image.yml é reutilizável; os demais o chamam ou fazem deploy de infra.
scripts/	Scripts de automação para reprodutibilidade. O PDF exige "ambiente totalmente reprodutível", e scripts ajudam nisso.


Sim, essa é uma boa síntese. Sua PoC tem quatro pilares principais, e o restante são ferramentas que se encaixam dentro deles.

🧱 Os quatro pilares da sua PoC
Pilar	O que inclui	Onde fica no repositório
1. Cluster	k3d, Traefik (Ingress), mapeamento de portas, /etc/hosts	scripts/install-k3d.sh, scripts/create-cluster.sh
2. Bootstrap	Harbor, SonarQube, ArgoCD, ARC (GitHub Runner)	infra/ + scripts/bootstrap.sh
3. Pipeline (CI/CD)	GitHub Actions, build multi-stage, testes, SonarQube (SAST), Trivy (scan), push Harbor, cosign sign, commit da tag	.github/workflows/
4. Monitoramento	Prometheus + Grafana (métricas), Loki + Alloy (logs)	apps/monitoring.yaml, apps/loki.yaml
🧩 O que fica "em volta" desses pilares
Segurança de admissão (OPA Gatekeeper + Kyverno): não é um pilar separado, é uma camada de política que se aplica ao cluster e às imagens que o pipeline produz. Fica em apps/opa.yaml e apps/kyverno.yaml, gerenciada pelo ArgoCD.

GitOps (ArgoCD + Argo Rollouts): é o mecanismo de entrega que conecta o pipeline ao cluster. O ArgoCD é bootstrap, mas as Applications que ele gerencia ficam em apps/.

Aplicação (front/back/db): é o artefato que o pipeline constrói e o ArgoCD entrega. Fica em src/ e charts/.

🎯 Uma forma mais precisa de descrever
Sua PoC é, na verdade, um fluxo de entrega de software com quatro estágios:

text
Cluster → Bootstrap → Pipeline (CI) → GitOps (CD) → Monitoramento
Cluster: a base onde tudo roda.

Bootstrap: as ferramentas que precisam existir antes do fluxo (Harbor, SonarQube, ArgoCD, ARC).

Pipeline: o que constrói, verifica e assina a imagem.

GitOps: o que entrega a imagem no cluster (ArgoCD + Argo Rollouts).

Monitoramento: o que observa o que foi entregue (Prometheus, Loki, Grafana, Alloy).

A segurança (OPA + Kyverno) atravessa o pipeline e o GitOps: o pipeline assina a imagem, o Kyverno verifica a assinatura na admissão, e o OPA aplica as demais políticas.

Resumindo: você está certa em dizer que a PoC é "cluster, bootstrap, pipeline e monitoramento". O GitOps e a segurança são camadas que conectam e protegem esses pilares, e a aplicação é o que tudo isso entrega.

