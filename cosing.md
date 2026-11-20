Para configurar a assinatura e verificação de imagens na sua PoC, a abordagem mais direta é usar Cosign para assinar combinado com a política verifyImages do Kyverno para verificação. Isso ocorre porque o Kyverno possui suporte nativo ao Cosign, não requer componentes adicionais e se integra bem com o cluster k3d que você já possui.

🔐 Primeiro passo: Gerar chaves e assinar a imagem
Você precisa fazer isso na sua máquina local ou no pipeline de CI, não dentro do cluster.

Gerar par de chaves: Use o Cosign para gerar as chaves privada e pública.

bash
cosign generate-key-pair
Isso gerará dois arquivos: cosign.key (chave privada, nunca faça commit no repositório) e cosign.pub (chave pública, será usada na política).

Assinar a imagem: É recomendável usar o digest para assinar, não a tag, pois tags podem ser sobrescritas.

bash
# Obter o digest da imagem (assumindo que a imagem já foi enviada ao seu registry local)
IMAGE="seu-registry.local/sua-app:v1.0.0"
DIGEST=$(crane digest $IMAGE) # ou use docker inspect --format='{{index .RepoDigests 0}}' $IMAGE

# Assinar
cosign sign --key cosign.key $IMAGE@$DIGEST
⚙️ Segundo passo: Configurar a política de verificação do Kyverno
Crie uma política ClusterPolicy que force todos os Pods a usar apenas imagens assinadas com sua chave pública.

yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-signed-images
spec:
  validationFailureAction: Enforce  # Modo de bloqueio; use Audit para testar primeiro
  background: false
  rules:
    - name: check-image-signature
      match:
        any:
        - resources:
            kinds:
              - Pod
      verifyImages:
      - imageReferences:
        - "seu-registry.local/sua-app*"  # Substitua pelo seu registry e nome da imagem
        attestors:
        - entries:
          - keys:
              publicKeys: |-
                -----BEGIN PUBLIC KEY-----
                # Cole aqui o conteúdo do seu arquivo cosign.pub
                -----END PUBLIC KEY-----
Descrição dos pontos principais:

imageReferences: Define quais imagens serão verificadas, suporta wildcards.

publicKeys: A chave pública usada para verificação, que corresponde à chave privada usada na assinatura.

validationFailureAction: Enforce: Se a assinatura não corresponder ou não existir, o Pod será rejeitado.

📦 Terceiro passo: Aplicar e testar
Aplique a política: kubectl apply -f sua-politica.yaml

Teste:

Imagem assinada: kubectl run teste-ok --image=seu-registry.local/sua-app@<seu-digest>

Imagem não assinada: kubectl run teste-fail --image=seu-registry.local/sua-app:unssigned (deve ser rejeitada pelo Kyverno)

💡 Dicas para a PoC
Registry local: Se sua imagem estiver no Harbor ou em um registry privado local, o Kyverno precisará de permissão para acessar esse registry. Você pode criar um imagePullSecret no namespace kyverno e referenciá-lo nos parâmetros de inicialização do Kyverno, ou configurar imageRegistryCredentials na política.

Integração com CI/CD: A etapa cosign sign pode ser adicionada ao seu workflow do GitHub Actions, executada automaticamente após o build da imagem, com a chave privada armazenada nos Secrets do repositório.

