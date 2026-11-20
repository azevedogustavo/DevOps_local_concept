# Usar tanto o OPA quando o Kyverno

Porque escolhi o OPA
O núcleo do Gatekeeper é um webhook de admissão que pode validar qualquer recurso do Kubernetes contra políticas customizadas. Isso permite implementar controles como:

Exigir rótulos (labels) específicos em todos os Pods (ex: team, environment) .

Restringir imagens a registros aprovados, impedindo que imagens de fontes não confiáveis sejam executadas .

Exigir que imagens usem digest (hash) em vez de tags mutáveis, garantindo imutabilidade .

Prevenir a criação de Pods privilegiados ou que violem os Pod Security Standards .


Porqu escolhi Kyverno

Use o Kyverno exclusivamente para a verificação de assinatura de imagem.

## Para o uso do OPA para assinatura, eu tenho esse problema pra enfrentar

O projeto original sigstore/cosign-gatekeeper-provider está arquivado e não é recomendado para produção . A alternativa mantida atualmente é usar o Ratify como provider do Gatekeeper para o Cosign . Isso adiciona mais um componente (Ratify) para instalar, configurar e entender na sua PoC.