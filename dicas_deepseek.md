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