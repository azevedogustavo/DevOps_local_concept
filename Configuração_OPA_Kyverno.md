Para instalar o OPA Gatekeeper e o Kyverno na sua PoC, o método recomendado para ambos é o Helm, pois simplifica o gerenciamento e a remoção. A boa notícia é que eles podem coexistir no mesmo cluster sem conflitos, cada um em seu próprio namespace.

🛡️ Instalando o Kyverno
O Helm é o método recomendado oficialmente pela documentação do Kyverno, mesmo para ambientes de não-produção .

Adicione o repositório e instale:

bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
Verifique a instalação:

bash
kubectl get pods -n kyverno
Você deverá ver os pods do Kyverno (admission controller, background controller, etc.) no estado Running.

⚖️ Instalando o OPA Gatekeeper
O processo é igualmente direto para o Gatekeeper, utilizando o repositório oficial de charts.

Adicione o repositório e instale:

bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm install gatekeeper gatekeeper/gatekeeper -n gatekeeper-system --create-namespace
Este comando instala o Gatekeeper e cria o namespace gatekeeper-system .

Verifique a instalação:

bash
kubectl get pods -n gatekeeper-system
Os pods do gatekeeper-controller-manager e do gatekeeper-audit devem estar rodando .

💡 Considerações para a PoC
Como você está montando um ambiente para testar políticas (como a de proibir :latest), ter as duas ferramentas instaladas permite comparar a abordagem de cada uma. A documentação oficial do Kyverno, inclusive, sugere que ele pode ser instalado junto com a stack do Prometheus, o que é útil para a sua PoC de observabilidade .

Após a instalação, você pode aplicar as políticas que já discutimos: um ConstraintTemplate + Constraint para o Gatekeeper e um ClusterPolicy para o Kyverno. Para testar, basta tentar criar um Pod com a imagem nginx:latest e observar a mensagem de bloqueio de cada ferramenta.