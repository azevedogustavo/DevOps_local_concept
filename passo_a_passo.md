📝 Etapa 1: Instalação do Cluster k3d
Este documento descreve os passos executados para instalar e configurar o cluster Kubernetes local utilizando k3d para a PoC.

🎯 Objetivo da Etapa
Ter um cluster Kubernetes funcional no ambiente local, com o controlador de Ingress (Traefik) exposto para o host, servindo de base para todas as etapas seguintes da PoC.

📋 Pré-requisitos
Requisito	Versão Mínima	Verificação
Docker	v20.10.5	docker version
Sistema Operacional	Linux (amd64)	uname -m
Acesso à internet	Para download dos binários	—
⚙️ Passo 1: Instalação do kubectl
O kubectl é a CLI oficial do Kubernetes, necessária para interagir com o cluster.


# Baixar a versão estável mais recente
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```
# Instalar o binário
```
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```
# Verificar a instalação
```
kubectl version --client
```

🚀 Passo 2: Instalação do k3d
O k3d é um wrapper leve que executa o k3s (Kubernetes) dentro de containers Docker.

# Instalação via script oficial
```
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```
# Verificar a instalação
```
k3d version
``
🎯 Passo 3: Criação do Cluster
O comando abaixo cria um cluster com 1 server e 2 agents, mapeando as portas do host para o loadbalancer do cluster (onde o Traefik escuta).

```
k3d cluster create poc-cluster \
  --servers 1 \
  --agents 2 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer" \
  --kubeconfig-update-default
```

📌 Explicação dos Parâmetros
Parâmetro	Descrição
--servers 1	Número de nós do tipo server (control plane)
--agents 2	Número de nós do tipo agent (worker)
--port "8080:80@loadbalancer"	Mapeia a porta 8080 do host para a porta 80 do loadbalancer (Traefik HTTP)
--port "8443:443@loadbalancer"	Mapeia a porta 8443 do host para a porta 443 do loadbalancer (Traefik HTTPS)
--kubeconfig-update-default	Atualiza automaticamente o kubeconfig do usuário
✅ Passo 4: Verificação do Cluster
Após a criação, verifique se os nós estão prontos:

```
kubectl get nodes
```
Saída esperada (algo similar a):

text
NAME                       STATUS   ROLES                  AGE   VERSION
k3d-poc-cluster-server-0   Ready    control-plane,master   1m    v1.xx.x+k3s1
k3d-poc-cluster-agent-0    Ready    <none>                 1m    v1.xx.x+k3s1
k3d-poc-cluster-agent-1    Ready    <none>                 1m    v1.xx.x+k3s1
🧪 Passo 5: Teste do Ingress (Traefik)
O k3d já instala o Traefik como controlador de Ingress padrão. Para validar que ele está respondendo:
Antes de rodar o comando aguarde 2 minutos para que a imagem do Traefik esteja pronta ou veirfique através do cluste com o comando kubectl get pods -A

```
curl -I http://localhost:8080
```

Saída esperada: um HTTP/1.1 404 Not Found (do Traefik), o que indica que ele está ativo e pronto para receber regras de Ingress.

🛠️ Comandos Úteis de Gerenciamento
Ação	Comando
Listar clusters	k3d cluster list
Parar o cluster	k3d cluster stop poc-cluster
Iniciar o cluster	k3d cluster start poc-cluster
Deletar o cluster	k3d cluster delete poc-cluster
Ver logs do cluster	k3d cluster logs poc-cluster
⚠️ Troubleshooting
Problema	Causa Provável	Solução
docker: command not found	Docker não instalado	Instalar o Docker conforme documentação oficial
Cannot connect to the Docker daemon	Docker não está rodando	sudo systemctl start docker
Porta 8080 já em uso	Outro serviço usando a porta	Alterar o mapeamento (ex: -p "8081:80@loadbalancer") ou parar o serviço conflitante
Nós em status NotReady	Cluster ainda inicializando	Aguardar 30-60 segundos e verificar novamente

✅ Passo 5: instale o Helm na sua máquina

```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
``


✅ Passo 6: instale o ArgoCD (via Helm)
Com O ArgoCD você vai conseguir configurar todo o seu cluster apartir do seu repositório


Já que seu cluster k3d usa o Traefik como Ingress, ao instalar o ArgoCD você precisa desabilitar o TLS (deixar o Traefik cuidar disso) e configurar o rootpath:

bash
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --set configs.params."server\.insecure"=true \
  --set configs.params."server\.rootpath"=/argocd \
  --wait
Em seguida, crie o Ingress (apontando para a porta 8080 do host mapeada anteriormente):

bash
kubectl create ingress argocd --class=traefik \
  --rule=/argocd*=argocd-server:80 \
  --annotation ingress.kubernetes.io/ssl-redirect=false \
  -n argocd
Após isso, você poderá acessar http://localhost:8080/argocd (usuário admin, senha obtida via kubectl get secret).

