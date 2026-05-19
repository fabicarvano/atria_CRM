#!/bin/bash

set -e

BASE_DIR="/opt/atria"
BACKUP_DIR="$BASE_DIR/backups_limpeza/backup_estrutura_$(date +%Y%m%d_%H%M%S)"

cd "$BASE_DIR"

echo "=================================================="
echo "Organização da estrutura do projeto Atria CRM"
echo "=================================================="
echo "Diretório base: $BASE_DIR"
echo "Backup em: $BACKUP_DIR"
echo

mkdir -p "$BACKUP_DIR"
mkdir -p "$BASE_DIR/scripts"
mkdir -p "$BASE_DIR/docs"

echo "=================================================="
echo "1. Conferindo estrutura principal"
echo "=================================================="

if [ ! -d "$BASE_DIR/www" ]; then
  echo "ERRO: pasta www não encontrada em $BASE_DIR"
  exit 1
fi

if [ ! -d "$BASE_DIR/www/custom/Espo/Custom" ]; then
  echo "ERRO: pasta www/custom/Espo/Custom não encontrada."
  exit 1
fi

echo "Estrutura principal encontrada com sucesso."
echo

echo "=================================================="
echo "2. Salvando lista de arquivos antes da limpeza"
echo "=================================================="

find "$BASE_DIR" -maxdepth 3 -type f | sort > "$BACKUP_DIR/lista_arquivos_antes.txt"
git status > "$BACKUP_DIR/git_status_antes.txt" 2>/dev/null || true

echo "Lista salva em:"
echo "$BACKUP_DIR/lista_arquivos_antes.txt"
echo

echo "=================================================="
echo "3. Movendo scripts úteis para /scripts"
echo "=================================================="

SCRIPTS_PARA_MOVER=(
  "atualiza_projeto_git.sh"
  "deploy_alvo_foco.sh"
  "diagnostico_profundo_funil_oportunidades.sh"
)

for arquivo in "${SCRIPTS_PARA_MOVER[@]}"; do
  if [ -f "$BASE_DIR/$arquivo" ]; then
    echo "Movendo $arquivo para scripts/"
    cp -a "$BASE_DIR/$arquivo" "$BACKUP_DIR/$arquivo"
    git mv "$BASE_DIR/$arquivo" "$BASE_DIR/scripts/$arquivo" 2>/dev/null || mv "$BASE_DIR/$arquivo" "$BASE_DIR/scripts/$arquivo"
  fi
done

chmod +x "$BASE_DIR"/scripts/*.sh 2>/dev/null || true

echo

echo "=================================================="
echo "4. Movendo documentações para /docs"
echo "=================================================="

DOCS_PARA_MOVER=(
  "DEPLOY_kanban_total.md"
  "verificacao_pos_deploy.md"
)

for arquivo in "${DOCS_PARA_MOVER[@]}"; do
  if [ -f "$BASE_DIR/$arquivo" ]; then
    echo "Movendo $arquivo para docs/"
    cp -a "$BASE_DIR/$arquivo" "$BACKUP_DIR/$arquivo"
    git mv "$BASE_DIR/$arquivo" "$BASE_DIR/docs/$arquivo" 2>/dev/null || mv "$BASE_DIR/$arquivo" "$BASE_DIR/docs/$arquivo"
  fi
done

echo

echo "=================================================="
echo "5. Removendo arquivos soltos duplicados da raiz"
echo "=================================================="

ARQUIVOS_SOLTOS_PARA_APAGAR=(
  "Opportunity.json"
  "kanban.js"
  "list.js"
  "clientDefs_Account_v2.json"
  "entityDefs_Account_v2.json"
)

for arquivo in "${ARQUIVOS_SOLTOS_PARA_APAGAR[@]}"; do
  if [ -f "$BASE_DIR/$arquivo" ]; then
    echo "Removendo arquivo solto: $arquivo"
    cp -a "$BASE_DIR/$arquivo" "$BACKUP_DIR/$arquivo"
    git rm "$BASE_DIR/$arquivo" 2>/dev/null || rm -f "$BASE_DIR/$arquivo"
  fi
done

echo

echo "=================================================="
echo "6. Removendo backups antigos dentro de www/custom/Espo/Custom"
echo "=================================================="

CUSTOM_DIR="$BASE_DIR/www/custom/Espo/Custom"

find "$CUSTOM_DIR" -type f \( \
  -name "*.bak" -o \
  -name "*.bak_*" -o \
  -name "*.bak-*" -o \
  -name "*.bkp" -o \
  -name "*.bkp_*" -o \
  -name "*.bkp-*" -o \
  -name "*.bkp*" \
\) | sort > "$BACKUP_DIR/backups_custom_encontrados.txt"

if [ -s "$BACKUP_DIR/backups_custom_encontrados.txt" ]; then
  echo "Backups encontrados dentro de Custom:"
  cat "$BACKUP_DIR/backups_custom_encontrados.txt"
  echo

  while IFS= read -r arquivo; do
    rel="${arquivo#$BASE_DIR/}"
    destino="$BACKUP_DIR/$rel"

    echo "Removendo backup interno: $rel"

    mkdir -p "$(dirname "$destino")"
    cp -a "$arquivo" "$destino"

    git rm "$arquivo" 2>/dev/null || rm -f "$arquivo"
  done < "$BACKUP_DIR/backups_custom_encontrados.txt"
else
  echo "Nenhum arquivo .bak/.bkp encontrado dentro de Custom."
fi

echo

echo "=================================================="
echo "7. Protegendo estrutura ativa do EspoCRM"
echo "=================================================="

echo "Mantidos:"
echo "- www/custom/Espo/Custom/.htaccess"
echo "- www/custom/Espo/Custom/Hooks"
echo "- www/custom/Espo/Custom/Resources"
echo "- www/client/custom"
echo "- schema_banco"
echo

echo "=================================================="
echo "8. Salvando lista de arquivos depois da limpeza"
echo "=================================================="

find "$BASE_DIR" -maxdepth 3 -type f | sort > "$BACKUP_DIR/lista_arquivos_depois.txt"
git status > "$BACKUP_DIR/git_status_depois.txt" 2>/dev/null || true

echo "Lista final salva em:"
echo "$BACKUP_DIR/lista_arquivos_depois.txt"
echo

echo "=================================================="
echo "9. Status final do Git"
echo "=================================================="

git status || true

echo
echo "=================================================="
echo "Limpeza concluída com segurança"
echo "=================================================="
echo "Backup completo dos arquivos removidos/movidos:"
echo "$BACKUP_DIR"
echo
echo "Próximos comandos sugeridos:"
echo "php /opt/atria/www/command.php clear-cache"
echo "git add ."
echo "git commit -m \"Organiza estrutura do projeto Atria CRM\""
echo "git push"
