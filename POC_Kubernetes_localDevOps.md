### Prova de Conceito – Ambiente Kubernetes Local (DevOps)
Objetivo
Demonstrar conhecimento prático na criação, configuração e uso de um ambiente
Kubernetes local, sem dependência de provedores Cloud. A POC deve comprovar
domínio em CI/CD, segurança, observabilidade e práticas DevOps modernas, simulando
um cenário real de entrega de software.
Escopo Técnico
```
• Cluster Kubernetes local (kind, k3d, minikube ou RKE2 em VMs).
```
```
• Registro de imagens local (Harbor ou Nexus).
```
• Aplicação web simples com endpoint /healthz.
• Dockerfile multi-stage e testes automatizados.
• Chart Helm com Deployment, Service, Ingress, HPA, ConfigMap e Secret.
• Pipeline CI/CD com Jenkins ou GitHub Actions self-hosted local.
```
• Integração com SonarQube (SAST) e Trivy (scan de imagem).
```
• Prometheus + Grafana para métricas e Loki/Promtail para logs.
```
• Políticas de segurança com Kyverno ou OPA (mínimo: proibir :latest).
```
Entregáveis
```
• Repositório Git (ou .zip) com código, pipeline, chart e scripts.
```
• README.md com passo a passo, rollback e troubleshooting.
```
• Evidências (prints do pipeline, dashboards, comandos kubectl).
```
Critérios de Avaliação
• Cluster e Ingress funcionais.
```
• Pipeline ponta a ponta com validações (SAST, scan, deploy).
```
```
• Observabilidade implementada (métricas e logs).
```
• Documentação clara e reprodutível.
• Segurança básica e boas práticas de DevOps.
```
Diferenciais (Opcional)
```
```
• Assinatura e verificação de imagens (cosign).
```
• GitOps com ArgoCD.
• Blue/Green ou Canary Deployment.
• Alertas configurados no Grafana ou Prometheus.
Entrega
```
Enviar link do repositório (ou .zip) e um breve relatório descrevendo decisões técnicas,
```
dificuldades encontradas e melhorias que seriam aplicadas em uma versão futura. O
ambiente deve ser totalmente reprodutível em máquina local, sem dependências externas
Cloud.
Duração recomendada: até 16 horas úteis.