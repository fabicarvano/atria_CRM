#!/bin/bash

ENV_FILE="/opt/atria/.env"
BASE="/opt/atria/www"
CONTACT_ID="6a10e2d28d4292835"
EMAIL_ACTOR_ID="bfH8Ermocz8oYKQVO"
EMAIL_RUN_ID="VkprJ4fHvOvd1awGB"

get_env() {
  grep -oP "^${1}=\K[^\r\n]+" "$ENV_FILE" 2>/dev/null | tr -d "\"'" | head -1
}

DB_HOST=$(get_env "DB_HOST"); DB_HOST=${DB_HOST:-localhost}
DB_NAME=$(get_env "DB_NAME")
DB_USER=$(get_env "DB_USER")
DB_PASS=$(get_env "DB_PASS")
APIFY_TOKEN=$(get_env "APIFY_API_TOKEN")

mysql_exec() {
  mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1" 2>/dev/null
}

echo "=================================================="
echo "DIAGNÓSTICO — FLUXO FINAL ENRIQUECIMENTO"
echo "=================================================="

echo
echo "1. CAMPOS ACCOUNT"
echo "--------------------------------------------------"
mysql_exec "SHOW COLUMNS FROM account;" | grep -E "Field|website|company|linkedin|site|email|created_by|modified_by|enriquec|fonte|logo|industria|employee" || true

echo
echo "2. CAMPOS CONTACT"
echo "--------------------------------------------------"
mysql_exec "SHOW COLUMNS FROM contact;" | grep -E "Field|linkedin|company|empresa|email|account|cargo|headline|enriquec|fonte|validacao|history|photo|location" || true

echo
echo "3. TABELA contact_company_history"
echo "--------------------------------------------------"
mysql_exec "SHOW TABLES LIKE 'contact_company_history';"
mysql_exec "SHOW COLUMNS FROM contact_company_history;" || echo "Tabela ainda não existe"

echo
echo "4. TABELA contato_executivo"
echo "--------------------------------------------------"
mysql_exec "SHOW COLUMNS FROM contato_executivo;" | grep -E "Field|linkedin|company|empresa|website|email|cargo|headline|picture|location|created" || true

echo
echo "5. CONTACT.PHP — CONTEXTO ATUAL"
echo "--------------------------------------------------"
php -l "$BASE/custom/Espo/Custom/Controllers/Contact.php" || true
grep -n -C 5 "postActionEnriquecerLinkedin\|companyName\|companyLinkedin\|companyWebsite\|email\|logUso\|callApify\|enriquecidaLinkedin" \
"$BASE/custom/Espo/Custom/Controllers/Contact.php" || true

echo
echo "6. ACCOUNT.PHP — CRIAÇÃO DE CONTATO EXECUTIVO E CONTA"
echo "--------------------------------------------------"
php -l "$BASE/custom/Espo/Custom/Controllers/Account.php" || true
grep -n -C 5 "postActionCriarContatoExecutivo\|getNewEntity('Contact')\|getNewEntity('Account')\|set('website'\|contato_executivo\|created_by_bot_user_id\|buscarContaExistente" \
"$BASE/custom/Espo/Custom/Controllers/Account.php" || true

echo
echo "7. METADATA ACCOUNT / CONTACT"
echo "--------------------------------------------------"
echo "--- Account entityDefs ---"
grep -n -C 3 "companyWebsite\|website\|linkedin\|enriquecidaLinkedin" \
"$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Account.json" || true

echo
echo "--- Contact entityDefs ---"
grep -n -C 3 "companyLinkedin\|companyWebsite\|companyNameAtual\|emailCorporativo\|accountIdAnterior\|statusValidacaoEmpresa\|linkedinUrl\|enriquecidaLinkedin" \
"$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Contact.json" || true

echo
echo "8. LAYOUTS ACCOUNT / CONTACT"
echo "--------------------------------------------------"
echo "--- Account detail ---"
grep -n -C 3 "companyWebsite\|website\|linkedin" \
"$BASE/custom/Espo/Custom/Resources/layouts/Account/detail.json" || true

echo
echo "--- Contact detail ---"
grep -n -C 3 "companyLinkedin\|companyWebsite\|companyNameAtual\|emailCorporativo\|accountIdAnterior\|statusValidacaoEmpresa\|linkedinUrl" \
"$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json" || true

echo
echo "9. DADOS DO CONTATO DE TESTE"
echo "--------------------------------------------------"
mysql_exec "
SELECT
 c.id,
 CONCAT(COALESCE(c.first_name,''),' ',COALESCE(c.last_name,'')) AS contato,
 c.linkedin_url,
 c.account_id,
 a.name AS conta_atual,
 a.website AS linkedin_conta_atual,
 c.enriquecida_linkedin,
 c.headline,
 c.cargo
FROM contact c
LEFT JOIN account a ON a.id = c.account_id
WHERE c.id='${CONTACT_ID}';
"

echo
echo "10. TESTE ACTOR PROFILE — CAMPOS DE EMPRESA/E-MAIL"
echo "--------------------------------------------------"
CONTACT_LI=$(mysql_exec "SELECT linkedin_url FROM contact WHERE id='${CONTACT_ID}';" | tail -1)

if [ -n "$APIFY_TOKEN" ] && [ -n "$CONTACT_LI" ]; then
  TMP="/tmp/contact_profile_diag_$$.json"
  curl -s --max-time 180 -X POST \
    "https://api.apify.com/v2/acts/dev_fusion~linkedin-profile-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"profileUrls\":[\"$CONTACT_LI\"]}" > "$TMP"

  python3 <<PY
import json
raw=open("$TMP").read()
print("bytes=", len(raw))
try:
    data=json.loads(raw)
    print("itens=", len(data) if isinstance(data,list) else "n/a")
    if isinstance(data,list) and data:
        item=data[0]
        for k in [
          "fullName","linkedinUrl","linkedinPublicUrl","headline","jobTitle",
          "email","mobileNumber","companyName","companyLinkedin","companyWebsite",
          "companyIndustry","companySize","profilePicHighQuality","addressWithoutCountry"
        ]:
            print(f"{k} = {item.get(k)}")
except Exception as e:
    print("ERRO JSON:", e)
    print(raw[:1000])
PY
  rm -f "$TMP"
else
  echo "Sem APIFY_TOKEN ou CONTACT_LI"
fi

echo
echo "11. TESTE ACTOR EMAIL — METADATA DO ACTOR"
echo "--------------------------------------------------"
if [ -n "$APIFY_TOKEN" ]; then
  curl -s --max-time 60 \
    "https://api.apify.com/v2/acts/${EMAIL_ACTOR_ID}?token=$APIFY_TOKEN" \
  | python3 - <<'PY'
import sys,json
raw=sys.stdin.read()
try:
    d=json.loads(raw)
    data=d.get("data",{})
    print("id=", data.get("id"))
    print("name=", data.get("name"))
    print("username=", data.get("username"))
    print("title=", data.get("title"))
    print("isPublic=", data.get("isPublic"))
except Exception as e:
    print("ERRO:", e)
    print(raw[:800])
PY
else
  echo "Sem APIFY_TOKEN"
fi

echo
echo "12. TESTE ACTOR EMAIL — ÚLTIMO RUN INFORMADO"
echo "--------------------------------------------------"
if [ -n "$APIFY_TOKEN" ]; then
  RUN_JSON="/tmp/email_run_diag_$$.json"
  curl -s --max-time 60 \
    "https://api.apify.com/v2/actor-runs/${EMAIL_RUN_ID}?token=$APIFY_TOKEN" > "$RUN_JSON"

  python3 <<PY
import json
raw=open("$RUN_JSON").read()
try:
    d=json.loads(raw)
    data=d.get("data",{})
    print("status=", data.get("status"))
    print("actorId=", data.get("actorId"))
    print("defaultDatasetId=", data.get("defaultDatasetId"))
    print("startedAt=", data.get("startedAt"))
    print("finishedAt=", data.get("finishedAt"))
except Exception as e:
    print("ERRO JSON run:", e)
    print(raw[:1000])
PY

  DATASET_ID=$(python3 - <<PY
import json
try:
    d=json.load(open("$RUN_JSON"))
    print(d.get("data",{}).get("defaultDatasetId",""))
except Exception:
    print("")
PY
)
  rm -f "$RUN_JSON"

  if [ -n "$DATASET_ID" ]; then
    echo "--- dataset sample: $DATASET_ID ---"
    curl -s --max-time 60 \
      "https://api.apify.com/v2/datasets/${DATASET_ID}/items?token=$APIFY_TOKEN&format=json&limit=3" \
    | python3 - <<'PY'
import sys,json
raw=sys.stdin.read()
try:
    data=json.loads(raw)
    print("items=", len(data) if isinstance(data,list) else "n/a")
    if isinstance(data,list):
        for i,item in enumerate(data[:3]):
            print("\nITEM", i+1)
            for k,v in item.items():
                if isinstance(v,(str,int,float,bool)) or v is None:
                    print(f"{k} = {v}")
except Exception as e:
    print("ERRO dataset:", e)
    print(raw[:1500])
PY
  fi
else
  echo "Sem APIFY_TOKEN"
fi

echo
echo "13. CLIENT DETAIL.JS — ERROS PENDENTES"
echo "--------------------------------------------------"
grep -n -C 4 "_applyLinkedinEditRule\|_injectAvatar\|enriquecerLinkedin" \
"$BASE/client/custom/src/views/contact/detail.js" || true

echo
echo "14. RESUMO DE AUSÊNCIAS ESPERADAS"
echo "--------------------------------------------------"
for COL in company_website; do
  mysql_exec "SHOW COLUMNS FROM account LIKE '$COL';" | grep "$COL" >/dev/null \
    && echo "OK account.$COL" || echo "AUSENTE account.$COL"
done

for COL in company_linkedin company_website company_name_atual email_corporativo fonte_email data_enriquecimento_email account_id_anterior status_validacao_empresa; do
  mysql_exec "SHOW COLUMNS FROM contact LIKE '$COL';" | grep "$COL" >/dev/null \
    && echo "OK contact.$COL" || echo "AUSENTE contact.$COL"
done

echo
echo "=================================================="
echo "FIM DO DIAGNÓSTICO"
echo "=================================================="
