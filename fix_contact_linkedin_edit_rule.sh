#!/bin/bash
set -e

BASE="/opt/atria/www"
EDEFS="$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Contact.json"
LAYOUT="$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json"
JS="$BASE/client/custom/src/views/contact/detail.js"
TS=$(date +%Y%m%d_%H%M%S)

echo "=== Backups ==="
cp "$EDEFS" "$EDEFS.bak_linkedin_edit_$TS"
cp "$LAYOUT" "$LAYOUT.bak_linkedin_edit_$TS"
cp "$JS" "$JS.bak_linkedin_edit_$TS"

echo
echo "=== 1. Tornando linkedinUrl editável no metadata ==="
python3 <<PY
import json
path = "$EDEFS"

with open(path) as f:
    data = json.load(f)

fields = data.setdefault("fields", {})
linkedin = fields.setdefault("linkedinUrl", {"type": "varchar", "maxLength": 512})

# Permite edição normal do campo.
linkedin.pop("layoutEditDisabled", None)
linkedin["layoutMassUpdateDisabled"] = True
linkedin["maxLength"] = 512
linkedin["type"] = "varchar"

with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK: linkedinUrl não está mais layoutEditDisabled")
PY

echo
echo "=== 2. Garantindo linkedinUrl no layout LinkedIn ==="
python3 <<PY
import json
path = "$LAYOUT"

with open(path) as f:
    data = json.load(f)

if not isinstance(data, list):
    raise SystemExit("Layout não é lista")

linkedin_section = None
for section in data:
    if isinstance(section, dict) and section.get("name") == "linkedin":
        linkedin_section = section
        break

if linkedin_section is None:
    linkedin_section = {"label": "LinkedIn", "name": "linkedin", "rows": []}
    data.append(linkedin_section)

rows = linkedin_section.setdefault("rows", [])

txt = json.dumps(rows)
if "linkedinUrl" not in txt:
    rows.insert(0, [{"name": "linkedinUrl", "fullWidth": True}])

if "isInfluencer" not in json.dumps(rows):
    rows.append([{"name": "isInfluencer"}, False])

with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK: linkedinUrl adicionado ao layout")
PY

echo
echo "=== 3. Regra visual no JS: bloquear LinkedIn só após enriquecimento ==="
python3 <<'PY'
from pathlib import Path

p = Path("/opt/atria/www/client/custom/src/views/contact/detail.js")
s = p.read_text()

# Adiciona chamada no after:render existente.
old = """            this.listenTo(this, 'after:render', () => {
                this._waitAndInjectAvatar();
            });"""

new = """            this.listenTo(this, 'after:render', () => {
                this._waitAndInjectAvatar();
                this._applyLinkedinEditRule();
            });"""

if old in s and "_applyLinkedinEditRule();" not in s:
    s = s.replace(old, new, 1)

# Adiciona método se não existir.
if "_applyLinkedinEditRule()" not in s:
    marker = "\n        _waitAndInjectAvatar()"
    method = r'''
        _applyLinkedinEditRule() {
            const isEnriq = !!this.model.get('enriquecidaLinkedin');

            const cell = document.querySelector('.cell[data-name="linkedinUrl"]');

            if (!cell) {
                return;
            }

            if (isEnriq) {
                cell.classList.add('read-only');
                const input = cell.querySelector('input, textarea');
                if (input) {
                    input.setAttribute('readonly', 'readonly');
                    input.setAttribute('disabled', 'disabled');
                }
            } else {
                cell.classList.remove('read-only');
                const input = cell.querySelector('input, textarea');
                if (input) {
                    input.removeAttribute('readonly');
                    input.removeAttribute('disabled');
                }
            }
        }

'''
    s = s.replace(marker, method + marker, 1)

# Garante que ao enriquecer, aplica a regra depois do retorno.
if "this._applyLinkedinEditRule();" not in s.split("async _actionEnriquecerLinkedin", 1)[-1]:
    s = s.replace(
        "                this._controlEnriquecimentoButtons();",
        "                this._controlEnriquecimentoButtons();\n                this._applyLinkedinEditRule();",
        1
    )

p.write_text(s)
print("OK: regra JS aplicada")
PY

echo
echo "=== 4. Validações ==="
grep -n -C 3 "linkedinUrl" "$EDEFS"
echo
grep -n -C 4 "linkedinUrl" "$LAYOUT"
echo
grep -n -C 5 "_applyLinkedinEditRule\|linkedinUrl" "$JS"

echo
echo "=== 5. Rebuild ==="
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "=== FINALIZADO ==="
echo "Agora faça CTRL+SHIFT+R e abra o contato."
