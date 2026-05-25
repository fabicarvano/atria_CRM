#!/bin/bash
set -e

BASE="/opt/atria/www"
TS=$(date +%Y%m%d_%H%M%S)

LAYOUT="$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json"

echo "=================================================="
echo "MOVER LINKEDIN URL PARA CARD SUPERIOR DO CONTATO"
echo "=================================================="

echo
echo "1. Backup..."
cp "$LAYOUT" "$LAYOUT.bak_linkedin_card_superior_$TS"
echo "OK: backup criado"

echo
echo "2. Ajustando layout..."
python3 <<PY
import json
from pathlib import Path

path = Path("$LAYOUT")

with path.open() as f:
    data = json.load(f)

if not isinstance(data, list):
    raise SystemExit("ERRO: layout não é lista")

# Remove linkedinUrl de qualquer seção para evitar duplicidade.
for section in data:
    rows = section.get("rows", []) if isinstance(section, dict) else []
    new_rows = []
    for row in rows:
        row_txt = json.dumps(row, ensure_ascii=False)
        if "linkedinUrl" in row_txt:
            # remove apenas o campo linkedinUrl da linha, mantendo outros campos se existirem
            if isinstance(row, list):
                cleaned = []
                for cell in row:
                    if isinstance(cell, dict) and cell.get("name") == "linkedinUrl":
                        continue
                    cleaned.append(cell)
                if any(cell not in (False, None, {}) for cell in cleaned):
                    new_rows.append(cleaned)
            continue
        new_rows.append(row)
    if isinstance(section, dict):
        section["rows"] = new_rows

# Adiciona linkedinUrl no primeiro card/seção, logo abaixo do Nome.
main = data[0]
rows = main.setdefault("rows", [])

if "linkedinUrl" not in json.dumps(rows, ensure_ascii=False):
    inserted = False
    for i, row in enumerate(rows):
        if "name" in json.dumps(row, ensure_ascii=False):
            rows.insert(i + 1, [{"name": "linkedinUrl", "fullWidth": True}])
            inserted = True
            break
    if not inserted:
        rows.insert(0, [{"name": "linkedinUrl", "fullWidth": True}])

with path.open("w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK: linkedinUrl movido para card superior")
PY

echo
echo "3. Validando JSON..."
python3 -m json.tool "$LAYOUT" >/dev/null
echo "OK: JSON válido"

echo
echo "4. Conferindo ocorrência do linkedinUrl no layout..."
grep -n -C 4 "linkedinUrl" "$LAYOUT"

echo
echo "5. Rebuild..."
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "=================================================="
echo "SUCESSO: LinkedIn URL movido para o card superior"
echo "Faça CTRL+SHIFT+R no contato."
echo "=================================================="
