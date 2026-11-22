Sim, você pode perfeitamente executar essa parte no seu cluster k3d. A chave é: o GitHub Runner não precisa ser instalado diretamente na máquina host, ele pode rodar como um Pod dentro do cluster k3d, através do Actions Runner Controller (ARC), e o SonarQube e o Trivy também rodam todos dentro do cluster.

🤖 Git Agent: Instalar ARC no k3d
ARC é um Operator do Kubernetes que gerencia e escala automaticamente os runners auto-hospedados do GitHub Actions dentro do cluster. Ele transforma seu cluster k3d em um "pool de executores" do GitHub Actions.

Instalar o Controller: Use o comando Helm oficial para instalar o controlador do ARC.

bash
helm install arc \
  --namespace arc-systems \
  --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
Configurar a Autenticação do GitHub: Recomenda-se usar o método GitHub App (mais seguro). Você precisa criar um GitHub App no GitHub e obter APP_ID, INSTALLATION_ID e a chave privada, então criar um Secret no cluster:

bash
kubectl create secret generic github-auth \
  --namespace arc-runners \
  --from-literal=github_app_id=SEU_APP_ID \
  --from-literal=github_app_installation_id=SEU_INSTALLATION_ID \
  --from-literal=github_app_private_key='-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----'

text
3.  **Implantar o Runner Scale Set**: Instale o chart do scale set, apontando para seu repositório.
```bash
helm install arc-runner-set \
  --namespace arc-runners \
  --create-namespace \
  --set githubConfigUrl="https://github.com/SEU_USUARIO/SEU_REPO" \
  --set githubConfigSecret="github-auth" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
Usar no Workflow: No arquivo .github/workflows/*.yml do GitHub, configure runs-on com o nome do scale set que você instalou (por exemplo arc-runner-set). Assim as tarefas serão executadas no Pod do seu cluster k3d.

📊 SonarQube (SAST): Implantar no k3d
O SonarQube precisa ser executado como um serviço primeiro. O método oficial também é Helm.

Adicionar o Repositório e Implantar:

bash
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
kubectl create namespace sonarqube
helm upgrade --install -n sonarqube sonarqube sonarqube/sonarqube \
  --set edition=developer \
  --set monitoringPasscode=SuaSenha
Nota: A edição developer requer uma licença. Para PoC, você pode primeiro testar a versão Community (se o chart suportar), ou considerar usar a edição developer em modo de avaliação. O SonarQube também precisa de um banco de dados, e o chart pode implantar um PostgreSQL para testes junto.

Chamar no Pipeline: Após a implantação, obtenha o endereço de serviço do SonarQube (por exemplo http://sonarqube.sonarqube.svc.cluster.local:9000), configure SONAR_HOST_URL e SONAR_TOKEN nos Secrets do GitHub, e chame o scanner do Sonar no workflow.

🛡️ Trivy (Scan de Imagem): Executar no Workflow
O Trivy não precisa ser implantado antecipadamente como um serviço, ele é executado como uma Action dentro do Pod do Runner. Como seu Runner está dentro do cluster k3d, o Trivy também roda no cluster.

No workflow do GitHub Actions, adicione o passo do Trivy (após o build da imagem, antes do push):

yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@0.33.1  # Recomenda-se fixar o SHA completo
  with:
    image-ref: 'sua-imagem:${{ github.sha }}'
    format: 'table'
    exit-code: '1'           # Interrompe o pipeline quando encontrar vulnerabilidades de alto risco
    severity: 'CRITICAL,HIGH'
    ignore-unfixed: true
💡 Um Lembrete
Como o Runner roda dentro do k3d, quando o workflow fizer docker build, ele na verdade estará usando o Docker dentro do Pod (requer suporte a Docker-in-Docker) ou usará ferramentas como Buildah. O chart do ARC pode configurar o container mode como kubernetes, usando diretamente o containerd do nó do cluster para build, evitando a complexidade do DinD. Na sua PoC, você pode escolher a solução mais simples que funcione primeiro e depois ajustar conforme necessário.

Resumindo: ARC transforma o k3d no executor do Actions, SonarQube roda como serviço dentro do cluster, Trivy é executado pelo Runner dentro do cluster. Assim os três são todos "executados no seu k3d".