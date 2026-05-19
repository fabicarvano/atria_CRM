#!/bin/bash

set -e

BASE_DIR="/opt/atria"
SCRIPT_REAL="$BASE_DIR/scripts/atualiza_projeto_git.sh"

cd "$BASE_DIR"

if [ ! -f "$SCRIPT_REAL" ]; then
  echo "ERRO: script real não encontrado em:"
  echo "$SCRIPT_REAL"
  exit 1
fi

chmod +x "$SCRIPT_REAL"

echo "======================================"
echo "Chamando atualizador oficial do projeto"
echo "======================================"
echo "Projeto: $BASE_DIR"
echo "Script:  $SCRIPT_REAL"
echo

exec "$SCRIPT_REAL"
