#!/bin/bash
set -e

BASE="/opt/atria/www"
TS=$(date +%Y%m%d_%H%M%S)
LAYOUT="$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json"

echo "=================================================="
echo "MOVER LINKEDIN URL AO LADO DE NÍVEL HIERÁRQUICO"
echo "=================================================="

echo
echo "1. Backup..."
cp "$LAYOUT" "$LAYOUT.bak_linkedin_ao_lado_nivel_$TS"
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

# Remove linkedinUrl de todas as posições atuais.
for section in data:
    if not isinstance(section, dict):
        continue

    rows = section.get("rows", [])
    new_rows = []

    for row in rows:
        if not isinstance(row, list):
            new_rows.append(row)
            continue

        cleaned = []
        for cell in row:
            if isinstance(cell, dict) and cell.get("name") == "linkedinUrl":
                continue
            cleaned.append(cell)

        if any(cell not in (False, None, {}) for cell in cleaned):
            new_rows.append(cleaned)

    section["rows"] = new_rows

# Adiciona linkedinUrl ao lado de nivelHierarquico na seção principal.
main = data[0]
rows = main.setdefault("rows", [])

inserted = False

for i, row in enumerate(rows):
    row_txt = json.dumps(row, ensure_ascii=False)

    if "nivelHierarquico" in row_txt:
        # Se a linha só tem nivelHierarquico, coloca linkedinUrl na segunda coluna.
        if isinstance(row, list):
            new_row = []
            has_nivel = False

            for cell in row:
                if isinstance(cell, dict) and cell.get("name") == "nivelHierarquico":
                    new_row.append(cell)
                    has_nivel = True
                elif cell not in (False, None, {}):
                    new_row.append(cell)

            if has_nivel:
                # garante no máximo duas colunas visuais
                if not any(isinstance(c, dict) and c.get("name") == "linkedinUrl" for c in new_row):
                    if len(new_row) == 1:
                        new_row.append({"name": "linkedinUrl"})
                    else:
                        # se já tiver segunda coluna, cria linha logo depois
                        rows.insert(i + 1, [{"name": "linkedinUrl"}, False])
                        inserted = True
                        break

                rows[i] = new_row
                inserted = True
                break

if not inserted:
    # fallback: coloca depois de E-mail
    for i, row in enumerate(rows):
        if "emailAddress" in json.dumps(row, ensure_ascii=False) or '"email"' in json.dumps(row, ensure_ascii=False):
            rows.insert(i + 1, [{"name": "nivelHierarquico"}, {"name": "linkedinUrl"}])
            inserted = True
            break

if not inserted:
    rows.insert(2, [{"name": "nivelHierarquico"}, {"name": "linkedinUrl"}])

with path.open("w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK: linkedinUrl posicionado ao lado de nivelHierarquico")
PY

echo
echo "3. Validando JSON..."
python3 -m json.tool "$LAYOUT" >/dev/null
echo "OK: JSON válido"

echo
echo "4. Conferindo contexto..."
grep -n -C 8 "nivelHierarquico\\|linkedinUrl" "$LAYOUT"

echo
echo "5. Rebuild..."
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "=================================================="
echo "SUCESSO: LinkedIn URL movido para o lado do Nível Hierárquico"
echo "Faça CTRL+SHIFT+R no contato."
echo "=================================================="
