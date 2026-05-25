#!/bin/bash
set -e

BASE="/opt/atria/www"
TS=$(date +%Y%m%d_%H%M%S)

ACCOUNT_ENTITY="$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Account.json"
CONTACT_ENTITY="$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Contact.json"
ACCOUNT_LAYOUT="$BASE/custom/Espo/Custom/Resources/layouts/Account/detail.json"
CONTACT_LAYOUT="$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json"

echo "=================================================="
echo "FASE 2 — METADATA / LAYOUT"
echo "=================================================="
echo "Regra: não criar view nova; apenas incrementar JSON existente."
echo

echo "1. Validando arquivos..."
for F in "$ACCOUNT_ENTITY" "$CONTACT_ENTITY" "$ACCOUNT_LAYOUT" "$CONTACT_LAYOUT"; do
  if [ ! -f "$F" ]; then
    echo "ERRO: arquivo não encontrado: $F"
    exit 1
  fi
  echo "OK: $F"
done

echo
echo "2. Backups..."
cp "$ACCOUNT_ENTITY" "$ACCOUNT_ENTITY.bak_fase2_$TS"
cp "$CONTACT_ENTITY" "$CONTACT_ENTITY.bak_fase2_$TS"
cp "$ACCOUNT_LAYOUT" "$ACCOUNT_LAYOUT.bak_fase2_$TS"
cp "$CONTACT_LAYOUT" "$CONTACT_LAYOUT.bak_fase2_$TS"
echo "OK: backups criados com sufixo .bak_fase2_$TS"

echo
echo "3. Incrementando entityDefs..."
python3 <<PY
import json
from pathlib import Path

account_entity = Path("$ACCOUNT_ENTITY")
contact_entity = Path("$CONTACT_ENTITY")

def load(path):
    with path.open() as f:
        return json.load(f)

def save(path, data):
    with path.open("w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

acc = load(account_entity)
acc_fields = acc.setdefault("fields", {})

acc_fields.setdefault("companyWebsite", {
    "type": "varchar",
    "maxLength": 255,
    "readOnly": True,
    "layoutEditDisabled": True,
    "layoutMassUpdateDisabled": True,
    "importDisabled": True
})

save(account_entity, acc)

ct = load(contact_entity)
ct_fields = ct.setdefault("fields", {})

new_contact_fields = {
    "companyLinkedin": {
        "type": "varchar",
        "maxLength": 512,
        "readOnly": True,
        "layoutEditDisabled": True,
        "layoutMassUpdateDisabled": True,
        "importDisabled": True
    },
    "companyWebsite": {
        "type": "varchar",
        "maxLength": 255,
        "readOnly": True,
        "layoutEditDisabled": True,
        "layoutMassUpdateDisabled": True,
        "importDisabled": True
    },
    "companyNameAtual": {
        "type": "varchar",
        "maxLength": 255,
        "readOnly": True,
        "layoutEditDisabled": True,
        "layoutMassUpdateDisabled": True,
        "importDisabled": True
    },
    "emailCorporativo": {
        "type": "varchar",
        "maxLength": 255,
        "readOnly": True,
        "layoutEditDisabled": True,
        "layoutMassUpdateDisabled": True,
        "importDisabled": True
    },
    "fonteEmail": {
        "type": "varchar",
        "maxLength": 100,
        "readOnly": True,
        "layoutEditDisabled": True,
        "layoutMassUpdateDisabled": True,
        "importDisabled": True
    },
    "dataEnriquecimentoEmail": {
        "type": "datetime",
        "readOnly": True,
        "layoutEditDisabled": True,
        "layoutMassUpdateDisabled": True,
        "importDisabled": True
    },
    "accountIdAnterior": {
        "type": "varchar",
        "maxLength": 17,
        "readOnly": True,
        "layoutEditDisabled": True,
        "layoutMassUpdateDisabled": True,
        "importDisabled": True
    },
    "statusValidacaoEmpresa": {
        "type": "enum",
        "options": [
            "",
            "empresa_validada",
            "empresa_divergente_corrigida",
            "empresa_nao_identificada",
            "pendente_validacao"
        ],
        "readOnly": True,
        "layoutEditDisabled": True,
        "layoutMassUpdateDisabled": True,
        "importDisabled": True
    }
}

for k, v in new_contact_fields.items():
    ct_fields.setdefault(k, v)

save(contact_entity, ct)

print("OK: entityDefs incrementados")
PY

echo
echo "4. Incrementando layouts existentes..."
python3 <<PY
import json
from pathlib import Path

account_layout = Path("$ACCOUNT_LAYOUT")
contact_layout = Path("$CONTACT_LAYOUT")

def load(path):
    with path.open() as f:
        return json.load(f)

def save(path, data):
    with path.open("w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def layout_has(rows, field):
    return field in json.dumps(rows, ensure_ascii=False)

def append_row_if_missing(section, row, fields):
    rows = section.setdefault("rows", [])
    txt = json.dumps(rows, ensure_ascii=False)
    if not any(field in txt for field in fields):
        rows.append(row)

# Account layout: adicionar companyWebsite na seção já existente, sem criar view.
acc = load(account_layout)

if isinstance(acc, list) and acc:
    # tenta colocar na primeira seção após website, se possível
    section = acc[0]
    rows = section.setdefault("rows", [])

    if not layout_has(rows, "companyWebsite"):
        inserted = False
        for idx, row in enumerate(rows):
            if "website" in json.dumps(row, ensure_ascii=False):
                rows.insert(idx + 1, [{"name": "companyWebsite"}, False])
                inserted = True
                break
        if not inserted:
            rows.append([{"name": "companyWebsite"}, False])

save(account_layout, acc)

# Contact layout: usar seção LinkedIn existente.
ct = load(contact_layout)

if not isinstance(ct, list):
    raise SystemExit("ERRO: layout Contact não é lista")

linkedin_section = None
for section in ct:
    if isinstance(section, dict) and section.get("name") == "linkedin":
        linkedin_section = section
        break

if linkedin_section is None:
    # Não é view nova, é seção de layout. Só cria se realmente não existir.
    linkedin_section = {"label": "LinkedIn", "name": "linkedin", "rows": []}
    ct.append(linkedin_section)

rows = linkedin_section.setdefault("rows", [])

# Garante Linkedin URL no topo da seção.
if not layout_has(rows, "linkedinUrl"):
    rows.insert(0, [{"name": "linkedinUrl", "fullWidth": True}])

append_row_if_missing(linkedin_section, [{"name": "companyNameAtual"}, {"name": "companyLinkedin"}], ["companyNameAtual", "companyLinkedin"])
append_row_if_missing(linkedin_section, [{"name": "companyWebsite"}, {"name": "emailCorporativo"}], ["companyWebsite", "emailCorporativo"])
append_row_if_missing(linkedin_section, [{"name": "statusValidacaoEmpresa"}, {"name": "accountIdAnterior"}], ["statusValidacaoEmpresa", "accountIdAnterior"])
append_row_if_missing(linkedin_section, [{"name": "fonteEmail"}, {"name": "dataEnriquecimentoEmail"}], ["fonteEmail", "dataEnriquecimentoEmail"])

save(contact_layout, ct)

print("OK: layouts incrementados")
PY

echo
echo "5. Validando JSON..."
python3 -m json.tool "$ACCOUNT_ENTITY" >/dev/null
python3 -m json.tool "$CONTACT_ENTITY" >/dev/null
python3 -m json.tool "$ACCOUNT_LAYOUT" >/dev/null
python3 -m json.tool "$CONTACT_LAYOUT" >/dev/null
echo "OK: todos os JSON são válidos"

echo
echo "6. Conferindo campos adicionados..."
echo "--- Account entityDefs ---"
grep -n -C 3 "companyWebsite" "$ACCOUNT_ENTITY" || true

echo
echo "--- Contact entityDefs ---"
grep -n -C 3 "companyLinkedin\\|companyWebsite\\|companyNameAtual\\|emailCorporativo\\|fonteEmail\\|dataEnriquecimentoEmail\\|accountIdAnterior\\|statusValidacaoEmpresa" "$CONTACT_ENTITY" || true

echo
echo "--- Account layout ---"
grep -n -C 3 "companyWebsite\\|website" "$ACCOUNT_LAYOUT" || true

echo
echo "--- Contact layout ---"
grep -n -C 3 "companyLinkedin\\|companyWebsite\\|companyNameAtual\\|emailCorporativo\\|fonteEmail\\|dataEnriquecimentoEmail\\|accountIdAnterior\\|statusValidacaoEmpresa\\|linkedinUrl" "$CONTACT_LAYOUT" || true

echo
echo "7. Rebuild..."
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "8. Validação no cache..."
grep -RIn "companyWebsite\\|companyLinkedin\\|emailCorporativo\\|statusValidacaoEmpresa" "$BASE/data/cache/application" | head -40 || true

echo
echo "=================================================="
echo "SUCESSO: FASE 2 concluída"
echo "Metadata/layout incrementados sem criar view nova."
echo "=================================================="
