#!/bin/bash

set -e

BASE_DIR="/opt/atria"
SCRIPTS_DIR="$BASE_DIR/scripts"
DOCS_DIR="$BASE_DIR/docs"
BACKUP_DIR="$BASE_DIR/backups_limpeza/limpeza_final_$(date +%Y%m%d_%H%M%S)"

cd "$BASE_DIR"

echo "=================================================="
echo "Limpeza final da estrutura Atria CRM"
echo "=================================================="
echo "Base: $BASE_DIR"
echo "Backup: $BACKUP_DIR"
echo

mkdir -p "$SCRIPTS_DIR"
mkdir -p "$DOCS_DIR"
mkdir -p "$BACKUP_DIR"

echo "=================================================="
echo "1. Diagnóstico antes da limpeza"
echo "=================================================="

echo "=== Arquivos .bak/.bkp encontrados ==="
find "$BASE_DIR" -type f \
  \( -name "*.bak" -o -name "*.bak_*" -o -name "*.bak-*" -o -name "*.bkp" -o -name "*.bkp_*" -o -name "*.bkp-*" -o -name "*.bkp*" \) \
  ! -path "$BASE_DIR/backups_limpeza/*" \
  | sort | tee "$BACKUP_DIR/arquivos_bak_bkp_antes.txt"

echo
echo "=== Arquivos .sh encontrados ==="
find "$BASE_DIR" -type f -name "*.sh" \
  ! -path "$BASE_DIR/backups_limpeza/*" \
  | sort | tee "$BACKUP_DIR/arquivos_sh_antes.txt"

echo
echo "=== Pasta /opt/espocrm ==="
if [ -d "/opt/espocrm" ]; then
  find /opt/espocrm -maxdepth 2 -print | sort | tee "$BACKUP_DIR/estrutura_opt_espocrm_antes.txt"
else
  echo "/opt/espocrm não existe."
fi

echo
echo "=================================================="
echo "2. Garantindo scripts úteis em /opt/atria/scripts"
echo "=================================================="

SCRIPTS_UTEIS=(
  "atualiza_projeto_git.sh"
  "deploy_alvo_foco.sh"
  "diagnostico_profundo_funil_oportunidades.sh"
)

for script in "${SCRIPTS_UTEIS[@]}"; do
  if [ -f "$BASE_DIR/$script" ]; then
    echo "Movendo script útil da raiz para scripts/: $script"
    cp -a "$BASE_DIR/$script" "$BACKUP_DIR/$script"
    git mv "$BASE_DIR/$script" "$SCRIPTS_DIR/$script" 2>/dev/null || mv "$BASE_DIR/$script" "$SCRIPTS_DIR/$script"
  elif [ -f "$SCRIPTS_DIR/$script" ]; then
    echo "Script útil já está em scripts/: $script"
  else
    echo "Aviso: script útil não encontrado: $script"
  fi
done

chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true

echo
echo "=================================================="
echo "3. Corrigindo atualiza_projeto_git.sh para novo endereço"
echo "=================================================="

ATUALIZA="$SCRIPTS_DIR/atualiza_projeto_git.sh"

if [ -f "$ATUALIZA" ]; then
  cp -a "$ATUALIZA" "$BACKUP_DIR/atualiza_projeto_git.sh.antes"

  cat > "$ATUALIZA" <<'SCRIPT'
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEMA_DIR="$APP_DIR/schema_banco"
SCHEMA_FILE="$SCHEMA_DIR/atria_crm_schema.sql"

cd "$APP_DIR"

echo "======================================"
echo "Atualizando schema do banco atria_crm"
echo "======================================"

if [ ! -f "$APP_DIR/.env" ]; then
  echo "Erro: arquivo .env não encontrado em $APP_DIR"
  exit 1
fi

set -a
source "$APP_DIR/.env"
set +a

mkdir -p "$SCHEMA_DIR"

MYSQL_PWD="$DB_PASS" mysqldump \
  -u "$DB_USER" \
  -h "$DB_HOST" \
  --no-data \
  --routines \
  --triggers \
  --events \
  "$DB_NAME" > "$SCHEMA_FILE"

echo "Schema atualizado em:"
echo "$SCHEMA_FILE"

echo
echo "======================================"
echo "Verificando alterações no projeto"
echo "======================================"

git status

if git diff --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "Nenhuma alteração encontrada para enviar ao Git."
  exit 0
fi

echo
echo "======================================"
echo "Adicionando todos os arquivos alterados"
echo "======================================"

git add .

echo
echo "======================================"
echo "Criando commit"
echo "======================================"

DATA_ATUAL=$(date '+%Y-%m-%d %H:%M:%S')

git commit -m "Atualiza projeto e schema do banco - $DATA_ATUAL"

echo
echo "======================================"
echo "Enviando para o GitHub"
echo "======================================"

git push

echo
echo "======================================"
echo "Atualização concluída com sucesso"
echo "======================================"
echo "Script executado a partir de: $SCRIPT_DIR"
echo "Projeto atualizado em: $APP_DIR"
SCRIPT

  chmod +x "$ATUALIZA"
  echo "Script corrigido: $ATUALIZA"
else
  echo "Aviso: $ATUALIZA não encontrado. Não foi possível corrigir."
fi

echo
echo "=================================================="
echo "4. Removendo arquivos .bak/.bkp"
echo "=================================================="

find "$BASE_DIR" -type f \
  \( -name "*.bak" -o -name "*.bak_*" -o -name "*.bak-*" -o -name "*.bkp" -o -name "*.bkp_*" -o -name "*.bkp-*" -o -name "*.bkp*" \) \
  ! -path "$BASE_DIR/backups_limpeza/*" \
  | sort | while read -r arquivo; do
    rel="${arquivo#$BASE_DIR/}"
    destino="$BACKUP_DIR/$rel"

    echo "Removendo backup: $rel"
    mkdir -p "$(dirname "$destino")"
    cp -a "$arquivo" "$destino"

    git rm "$arquivo" 2>/dev/null || rm -f "$arquivo"
  done

echo
echo "=================================================="
echo "5. Removendo scripts .sh não utilizáveis"
echo "=================================================="

find "$BASE_DIR" -type f -name "*.sh" \
  ! -path "$BASE_DIR/backups_limpeza/*" \
  ! -path "$SCRIPTS_DIR/atualiza_projeto_git.sh" \
  ! -path "$SCRIPTS_DIR/deploy_alvo_foco.sh" \
  ! -path "$SCRIPTS_DIR/diagnostico_profundo_funil_oportunidades.sh" \
  ! -path "$BASE_DIR/limpeza_final_estrutura_atria.sh" \
  | sort | while read -r arquivo; do
    rel="${arquivo#$BASE_DIR/}"
    destino="$BACKUP_DIR/$rel"

    echo "Removendo script não utilizável: $rel"
    mkdir -p "$(dirname "$destino")"
    cp -a "$arquivo" "$destino"

    git rm "$arquivo" 2>/dev/null || rm -f "$arquivo"
  done

echo
echo "=================================================="
echo "6. Removendo pasta /opt/espocrm se estiver vazia"
echo "=================================================="

if [ -d "/opt/espocrm" ]; then
  if [ -z "$(find /opt/espocrm -mindepth 1 -print -quit)" ]; then
    echo "Removendo /opt/espocrm porque está vazia."
    rmdir /opt/espocrm
  else
    echo "A pasta /opt/espocrm NÃO está vazia. Não será removida."
    find /opt/espocrm -maxdepth 2 -print | sort
  fi
else
  echo "/opt/espocrm não existe. Nada a remover."
fi

echo
echo "=================================================="
echo "7. Limpando cache do EspoCRM"
echo "=================================================="

if [ -f "$BASE_DIR/www/command.php" ]; then
  php "$BASE_DIR/www/command.php" clear-cache
else
  echo "Aviso: command.php não encontrado em $BASE_DIR/www/command.php"
fi

echo
echo "=================================================="
echo "8. Diagnóstico final"
echo "=================================================="

echo "=== .bak/.bkp restantes ==="
find "$BASE_DIR" -type f \
  \( -name "*.bak" -o -name "*.bak_*" -o -name "*.bak-*" -o -name "*.bkp" -o -name "*.bkp_*" -o -name "*.bkp-*" -o -name "*.bkp*" \) \
  ! -path "$BASE_DIR/backups_limpeza/*" \
  | sort | tee "$BACKUP_DIR/arquivos_bak_bkp_depois.txt"

echo
echo "=== .sh restantes ==="
find "$BASE_DIR" -type f -name "*.sh" \
  ! -path "$BASE_DIR/backups_limpeza/*" \
  | sort | tee "$BACKUP_DIR/arquivos_sh_depois.txt"

echo
echo "=== Status Git ==="
git status | tee "$BACKUP_DIR/git_status_depois.txt"

echo
echo "=================================================="
echo "Limpeza concluída"
echo "=================================================="
echo "Backup salvo em:"
echo "$BACKUP_DIR"
echo
echo "Scripts úteis mantidos:"
echo "- $SCRIPTS_DIR/atualiza_projeto_git.sh"
echo "- $SCRIPTS_DIR/deploy_alvo_foco.sh"
echo "- $SCRIPTS_DIR/diagnostico_profundo_funil_oportunidades.sh"
echo
echo "Para atualizar o projeto daqui para frente, use:"
echo "cd /opt/atria && ./scripts/atualiza_projeto_git.sh"
