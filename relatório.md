Para gerar um relatório completo no output do workflow, a forma mais direta é usar o GitHub Actions Job Summary ($GITHUB_STEP_SUMMARY). Ele permite que você escreva conteúdo Markdown e o exiba na página de resumo da execução do workflow, sem precisar de serviços adicionais, e é possível agregar os resultados do SonarQube e do Trivy em uma única tabela ou em várias seções.

📊 SonarQube: Obter status do Quality Gate e escrever no Summary
O SonarQube em si não escreve automaticamente no $GITHUB_STEP_SUMMARY, mas você pode usar Actions da comunidade ou scripts para obter os resultados e escrevê-los.

Método 1: Usar a Action oficial (recomendado)
Use sonarsource/sonarqube-quality-gate-action, que irá verificar o status do Quality Gate e gerar o resultado. Em seguida, use um passo adicional para escrever esse resultado no Summary .

yaml
- name: SonarQube Quality Gate check
  id: sonar-gate
  uses: sonarsource/sonarqube-quality-gate-action@master
  with:
    pollingTimeoutSec: 600
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
    SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}

- name: Write SonarQube result to summary
  if: always()
  run: |
    echo "## 🔍 SonarQube Analysis" >> "$GITHUB_STEP_SUMMARY"
    echo "" >> "$GITHUB_STEP_SUMMARY"
    echo "| Item | Result |" >> "$GITHUB_STEP_SUMMARY"
    echo "|------|--------|" >> "$GITHUB_STEP_SUMMARY"
    echo "| Quality Gate | ${{ steps.sonar-gate.outputs.quality-gate-status }} |" >> "$GITHUB_STEP_SUMMARY"
    echo "| Project | ${{ github.repository }} |" >> "$GITHUB_STEP_SUMMARY"
Método 2: Usar Action da comunidade (com captura de JSON detalhado)
A Action phwt/sonarqube-quality-gate-action pode gerar diretamente o step summary e também fornecer o resultado completo do Quality Gate em formato JSON, adequado para relatórios mais detalhados .

yaml
- uses: phwt/sonarqube-quality-gate-action@v1
  id: quality-gate
  with:
    sonar-project-key: ${{ secrets.SONAR_PROJECT_KEY }}
    sonar-host-url: ${{ secrets.SONAR_HOST_URL }}
    sonar-token: ${{ secrets.SONAR_TOKEN }}
    disable-step-summary: false   # padrão é habilitado, escreve automaticamente no Summary
🛡️ Trivy: Salvar saída JSON e escrever tabela no Summary
A Action do Trivy suporta saída em formato JSON ou table, e você pode usar scripts para analisar e gerar uma tabela Markdown no Summary .

yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@0.33.1
  with:
    image-ref: 'sua-imagem:${{ github.sha }}'
    format: 'json'
    output: 'trivy-results.json'
    severity: 'CRITICAL,HIGH'
    exit-code: '0'   # Não falha primeiro, deixa o script julgar

- name: Write Trivy result to summary
  if: always()
  run: |
    if [ ! -f trivy-results.json ]; then
      echo "## 🛡️ Trivy Scan" >> "$GITHUB_STEP_SUMMARY"
      echo "Relatório do Trivy não encontrado." >> "$GITHUB_STEP_SUMMARY"
      exit 0
    fi
    CRITICAL=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' trivy-results.json)
    HIGH=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' trivy-results.json)
    echo "## 🛡️ Trivy Image Scan" >> "$GITHUB_STEP_SUMMARY"
    echo "" >> "$GITHUB_STEP_SUMMARY"
    echo "| Severity | Count |" >> "$GITHUB_STEP_SUMMARY"
    echo "|----------|-------|" >> "$GITHUB_STEP_SUMMARY"
    echo "| CRITICAL | $CRITICAL |" >> "$GITHUB_STEP_SUMMARY"
    echo "| HIGH | $HIGH |" >> "$GITHUB_STEP_SUMMARY"
    echo "" >> "$GITHUB_STEP_SUMMARY"
    echo "Relatório detalhado salvo como artifact." >> "$GITHUB_STEP_SUMMARY"
🔗 Sobre os resultados do Harbor
Se você já habilitou o Trivy como scanner no Harbor, os resultados da verificação de vulnerabilidades já estarão no Harbor, e não é necessário escaneá-los novamente no workflow. Mas se você quiser exibir os resultados do Harbor no Summary, pode usar a Action kyberorg/harbor-scan-report :

yaml
- name: Harbor Scan Report
  uses: kyberorg/harbor-scan-report@v0.1
  with:
    harbor-host: ${{ secrets.HARBOR_HOST }}
    image: 'seu-projeto/sua-imagem:${{ github.sha }}'
    harbor-robot: ${{ secrets.HARBOR_ROBOT }}
    harbor-token: ${{ secrets.HARBOR_TOKEN }}
    max-allowed-severity: high
    # Esta Action comenta principalmente em PR, não escreve diretamente no $GITHUB_STEP_SUMMARY
Recomendação: Para a PoC, o mais seguro é usar diretamente o Trivy no workflow para escanear e gerar o relatório, pois o controle é maior e a integração com o Summary é mais direta. Os resultados de verificação do Harbor podem servir como uma segunda camada de garantia (a política de assinatura de imagens do Harbor pode ser combinada com o Kyverno).

💡 Lembrete importante
$GITHUB_STEP_SUMMARY tem um limite de 1 MiB por step e no máximo 20 step summaries por job . Não coloque tabelas JSON enormes diretamente; resuma as contagens e detalhes principais no Summary, e salve o JSON completo como artifact.

Se o Trivy estiver configurado com exit-code: 1 para falhar no pipeline, os steps subsequentes podem ser ignorados. Use if: always() no step que escreve o Summary para garantir que o relatório seja gerado mesmo em caso de falha .

Resumindo: SonarQube use a Action oficial + script echo, Trivy use trivy-action para gerar JSON + jq para gerar tabela, ambos escrevendo em $GITHUB_STEP_SUMMARY. Dessa forma, ao abrir a página de resumo do workflow, você verá em uma única página o status do Quality Gate do SonarQube e a tabela de vulnerabilidades por severidade do Trivy.

