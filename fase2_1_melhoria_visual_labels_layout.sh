#!/bin/bash
set -e

BASE="/opt/atria/www"
TS=$(date +%Y%m%d_%H%M%S)

CONTACT_LAYOUT="$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json"
ACCOUNT_LAYOUT="$BASE/custom/Espo/Custom/Resources/layouts/Account/detail.json"
CONTACT_I18N="$BASE/custom/Espo/Custom/Resources/i18n/pt_BR/Contact.json"
ACCOUNT_I18N="$BASE/custom/Espo/Custom/Resources/i18n/pt_BR/Account.json"

echo "=================================================="
echo "FASE 2.1 — Melhoria visual sem perda de campos"
echo "=================================================="

echo
echo "1. Validando arquivos..."
for F in "$CONTACT_LAYOUT" "$ACCOUNT_LAYOUT" "$CONTACT_I18N" "$ACCOUNT_I18N"; do
  if [ ! -f "$F" ]; then
    echo "ERRO: arquivo não encontrado: $F"
    exit 1
  fi
  echo "OK: $F"
done

echo
echo "2. Backup..."
cp "$CONTACT_LAYOUT" "$CONTACT_LAYOUT.bak_fase2_1_$TS"
cp "$ACCOUNT_LAYOUT" "$ACCOUNT_LAYOUT.bak_fase2_1_$TS"
cp "$CONTACT_I18N" "$CONTACT_I18N.bak_fase2_1_$TS"
cp "$ACCOUNT_I18N" "$ACCOUNT_I18N.bak_fase2_1_$TS"
echo "OK: backups criados"

echo
echo "3. Labels pt_BR..."
python3 <<PY
import json
from pathlib import Path

def load(path):
    with open(path) as f:
        return json.load(f)

def save(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

contact_path = Path("$CONTACT_I18N")
account_path = Path("$ACCOUNT_I18N")

contact = load(contact_path)
contact_labels = contact.setdefault("fields", {})

contact_labels.update({
    "linkedinUrl": "LinkedIn URL",
    "headline": "Headline",
    "cargo": "Cargo",
    "companyNameAtual": "Empresa Atual",
    "companyLinkedin": "LinkedIn da Empresa Atual",
    "companyWebsite": "Website da Empresa",
    "emailCorporativo": "E-mail Corporativo",
    "statusValidacaoEmpresa": "Status da Validação",
    "linkedinLastSync": "Última Sincronização",
    "locationLinkedin": "Localização LinkedIn",
    "nivelHierarquico": "Nível Hierárquico",
    "enriquecidaLinkedin": "Contato Enriquecido",
    "dataEnriquecimentoLinkedin": "Data do Enriquecimento",
    "fonteEnriquecimento": "Fonte do Enriquecimento",
    "fonteEmail": "Fonte do E-mail",
    "dataEnriquecimentoEmail": "Data do Enriquecimento do E-mail",
    "accountIdAnterior": "Conta Anterior",
    "isPremium": "Premium",
    "isCreator": "Creator",
    "isInfluencer": "Influencer"
})

save(contact_path, contact)

account = load(account_path)
account_labels = account.setdefault("fields", {})

account_labels.update({
    "website": "LinkedIn da Empresa",
    "companyWebsite": "Website Oficial",
    "industriaLinkedin": "Indústria LinkedIn",
    "employeeCountLinkedin": "Funcionários LinkedIn",
    "enriquecidaLinkedin": "Conta Enriquecida",
    "dataEnriquecimentoLinkedin": "Data do Enriquecimento",
    "fonteEnriquecimento": "Fonte do Enriquecimento"
})

save(account_path, account)

print("OK: labels atualizados")
PY

echo
echo "4. Reorganizando layout Contact sem remover metadata..."
python3 <<PY
import json
from pathlib import Path

path = Path("$CONTACT_LAYOUT")

with open(path) as f:
    data = json.load(f)

if not isinstance(data, list):
    raise SystemExit("ERRO: layout Contact não é lista")

linkedin = None
for section in data:
    if isinstance(section, dict) and section.get("name") == "linkedin":
        linkedin = section
        break

if linkedin is None:
    linkedin = {"label": "LinkedIn", "name": "linkedin", "rows": []}
    data.append(linkedin)

# Layout limpo: só remove da TELA principal campos técnicos, sem remover dos arquivos de metadata.
linkedin["label"] = "LinkedIn e Enriquecimento"
linkedin["rows"] = [
    [
        {"name": "linkedinUrl", "fullWidth": True}
    ],
    [
        {"name": "headline"},
        {"name": "cargo"}
    ],
    [
        {"name": "companyNameAtual"},
        {"name": "companyWebsite"}
    ],
    [
        {"name": "companyLinkedin"},
        {"name": "emailCorporativo"}
    ],
    [
        {"name": "statusValidacaoEmpresa"},
        {"name": "linkedinLastSync"}
    ]
]

with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK: layout Contact reorganizado")
PY

echo
echo "5. Ajustando Account sem perder campos..."
python3 <<PY
import json
from pathlib import Path

path = Path("$ACCOUNT_LAYOUT")

with open(path) as f:
    data = json.load(f)

if not isinstance(data, list):
    raise SystemExit("ERRO: layout Account não é lista")

# Apenas garante companyWebsite próximo de website.
section = data[0]
rows = section.setdefault("rows", [])

txt = json.dumps(rows, ensure_ascii=False)
if "companyWebsite" not in txt:
    inserted = False
    for i, row in enumerate(rows):
        if "website" in json.dumps(row, ensure_ascii=False):
            rows.insert(i + 1, [{"name": "companyWebsite"}, False])
            inserted = True
            break
    if not inserted:
        rows.append([{"name": "companyWebsite"}, False])

with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK: layout Account preservado e validado")
PY

echo
echo "6. Validando JSON..."
python3 -m json.tool "$CONTACT_LAYOUT" >/dev/null
python3 -m json.tool "$ACCOUNT_LAYOUT" >/dev/null
python3 -m json.tool "$CONTACT_I18N" >/dev/null
python3 -m json.tool "$ACCOUNT_I18N" >/dev/null
echo "OK: JSON válido"

echo
echo "7. Conferindo campos visíveis no Contact layout..."
grep -n -C 2 "LinkedIn e Enriquecimento\\|linkedinUrl\\|headline\\|cargo\\|companyNameAtual\\|companyWebsite\\|companyLinkedin\\|emailCorporativo\\|statusValidacaoEmpresa\\|linkedinLastSync" "$CONTACT_LAYOUT"

echo
echo "8. Conferindo labels..."
grep -n -C 2 "Empresa Atual\\|LinkedIn da Empresa Atual\\|Website da Empresa\\|E-mail Corporativo\\|Status da Validação\\|Website Oficial" "$CONTACT_I18N" "$ACCOUNT_I18N" || true

echo
echo "9. Rebuild..."
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "10. Validação no cache..."
grep -RIn "Empresa Atual\\|Website da Empresa\\|E-mail Corporativo\\|Status da Validação\\|Website Oficial" "$BASE/data/cache/application" | head -50 || true

echo
echo "=================================================="
echo "SUCESSO: FASE 2.1 concluída"
echo "Campos preservados. Apenas layout/labels foram melhorados."
echo "=================================================="
