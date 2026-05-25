#!/bin/bash
set -e

BASE="/opt/atria/www"
TS=$(date +%Y%m%d_%H%M%S)

CONTACT_LAYOUT="$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json"
CONTACT_I18N="$BASE/custom/Espo/Custom/Resources/i18n/pt_BR/Contact.json"

echo "=================================================="
echo "FINALIZAÇÃO VISUAL — CONTATO ENRIQUECIDO"
echo "=================================================="

echo
echo "1. Backup..."
cp "$CONTACT_LAYOUT" "$CONTACT_LAYOUT.bak_final_visual_$TS"
cp "$CONTACT_I18N" "$CONTACT_I18N.bak_final_visual_$TS"
echo "OK: backups criados"

echo
echo "2. Ajustando labels..."
python3 <<PY
import json
from pathlib import Path

path = Path("$CONTACT_I18N")

with path.open() as f:
    data = json.load(f)

fields = data.setdefault("fields", {})

fields.update({
    "linkedinUrl": "LinkedIn URL",
    "headline": "Título LinkedIn",
    "cargo": "Cargo LinkedIn",
    "companyNameAtual": "Empresa Identificada",
    "companyLinkedin": "LinkedIn da Empresa Identificada",
    "companyWebsite": "Website Identificado",
    "emailCorporativo": "E-mail Inferido",
    "statusValidacaoEmpresa": "Status da Validação",
    "linkedinLastSync": "Última Sincronização",
    "nivelHierarquico": "Nível Hierárquico",
    "linkedinPhotoUrl": "Foto LinkedIn"
})

data.setdefault("options", {})
data["options"].setdefault("statusValidacaoEmpresa", {})
data["options"]["statusValidacaoEmpresa"].update({
    "empresa_validada": "Empresa validada",
    "empresa_divergente_corrigida": "Empresa divergente corrigida",
    "empresa_nao_identificada": "Empresa não identificada",
    "pendente_validacao": "Pendente de validação"
})

with path.open("w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK: labels ajustados")
PY

echo
echo "3. Reorganizando layout LinkedIn sem apagar campos..."
python3 <<PY
import json
from pathlib import Path

path = Path("$CONTACT_LAYOUT")

with path.open() as f:
    data = json.load(f)

if not isinstance(data, list):
    raise SystemExit("ERRO: layout Contact não é lista")

linkedin = None
for section in data:
    if isinstance(section, dict) and section.get("name") == "linkedin":
        linkedin = section
        break

if linkedin is None:
    linkedin = {
        "label": "LinkedIn e Enriquecimento",
        "name": "linkedin",
        "rows": []
    }
    data.append(linkedin)

linkedin["label"] = "LinkedIn e Enriquecimento"

# Layout final: mantém só o que agrega visualmente.
# Nada é apagado do banco ou metadata.
linkedin["rows"] = [
    [
        {"name": "linkedinUrl", "fullWidth": True}
    ],
    [
        {"name": "headline"},
        {"name": "emailCorporativo"}
    ],
    [
        {"name": "companyWebsite"},
        {"name": "statusValidacaoEmpresa"}
    ],
    [
        {"name": "linkedinLastSync"},
        False
    ]
]

with path.open("w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK: layout LinkedIn finalizado")
PY

echo
echo "4. Validação JSON..."
python3 -m json.tool "$CONTACT_LAYOUT" >/dev/null
python3 -m json.tool "$CONTACT_I18N" >/dev/null
echo "OK: JSON válido"

echo
echo "5. Conferindo layout final..."
grep -n -C 3 "LinkedIn e Enriquecimento\\|linkedinUrl\\|headline\\|emailCorporativo\\|companyWebsite\\|statusValidacaoEmpresa\\|linkedinLastSync" "$CONTACT_LAYOUT"

echo
echo "6. Rebuild..."
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "7. Validação no cache..."
grep -RIn "Título LinkedIn\\|E-mail Inferido\\|Website Identificado\\|Status da Validação" "$BASE/data/cache/application" | head -50 || true

echo
echo "=================================================="
echo "SUCESSO: Visual de contato enriquecido finalizado"
echo "Faça CTRL+SHIFT+R na tela do contato."
echo "=================================================="
