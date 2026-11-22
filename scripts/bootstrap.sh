chmod +x scripts/*.sh

./scripts/install-k3d.sh
./scripts/create-cluster.sh
./scripts/install-harbor.sh
./scripts/install-sonarqube.sh
./scripts/install-argocd.sh

# ARC (exporte as variáveis antes)
export GITHUB_APP_ID="..."
export GITHUB_APP_INSTALLATION_ID="..."
export GITHUB_APP_PRIVATE_KEY_PATH="/caminho/para/chave.pem"
export GITHUB_REPO_URL="https://github.com/SEU_USUARIO/SEU_REPO"
./scripts/install-arc.sh

# Colocar um input para que as instalações não atropelem as saídas para atividas manuais como guardar senhas no secret do github
