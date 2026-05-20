#!/bin/bash
set -e

ORIGEM="/opt/atria"
DESTINO="/opt/atria"
DATA=$(date +%Y%m%d_%H%M%S)
ARQUIVO="${DESTINO}/atria_sem_git_json_${DATA}.tar.gz"

echo "======================================"
echo "Compactando projeto Atria"
echo "Origem: ${ORIGEM}"
echo "Destino: ${ARQUIVO}"
echo "======================================"

tar -czf "${ARQUIVO}" \
  -C "${ORIGEM}" \
  --exclude='./.git' \
  --exclude='./www/.git' \
  --exclude='./**/.git' \
  --exclude='*.json' \
  --exclude='./.env' \
  --exclude='./*.env' \
  --exclude='./www/.env' \
  --exclude='./backups' \
  --exclude='./www/data/cache' \
  --exclude='./www/data/logs' \
  --exclude='*.dump' \
  --exclude='*.gz' \
  --exclude='*.zip' \
  --exclude='*.tar' \
  --exclude='*.tar.gz' \
  .

echo
echo "Arquivo criado:"
ls -lh "${ARQUIVO}"

echo
echo "Para conferir o conteúdo:"
echo "tar -tzf ${ARQUIVO} | head -100"
