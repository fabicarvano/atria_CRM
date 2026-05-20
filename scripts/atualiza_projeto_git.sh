#!/bin/bash

set -e

APP_DIR="/opt/atria"
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
