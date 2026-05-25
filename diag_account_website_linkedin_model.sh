#!/bin/bash

ENV_FILE="/opt/atria/.env"
BASE="/opt/atria/www"
CONTACT_ID="6a10e2d28d4292835"

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
echo "DIAGNÓSTICO — MODELO ACCOUNT WEBSITE/LINKEDIN"
echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="

echo
echo "1. CONTEXTO DO PROBLEMA"
echo "--------------------------------------------------"
echo "Hoje o campo nativo account.website está sendo usado como LinkedIn URL da empresa."
echo "Precisamos avaliar criar campo separado para site/domínio real da empresa."
echo "Nada será alterado neste diagnóstico."

echo
echo "2. BANCO — COLUNAS ATUAIS DE ACCOUNT"
echo "--------------------------------------------------"
mysql_exec "SHOW COLUMNS FROM account;" | grep -E "Field|website|linkedin|site|domain|dominio|url|logo|industria|employee|enriquec|fonte|name|created_by|modified_by" || true

echo
echo "3. BANCO — AMOSTRA DE CONTAS"
echo "--------------------------------------------------"
mysql_exec "
SELECT
  id,
  name,
  website,
  industria_linkedin,
  employee_count_linkedin,
  logo_url,
  enriquecida_linkedin,
  fonte_enriquecimento
FROM account
WHERE deleted = 0
ORDER BY created_at DESC
LIMIT 15;
"

echo
echo "4. BANCO — VERIFICAR SE JÁ EXISTEM CAMPOS PARA SITE REAL"
echo "--------------------------------------------------"
for COL in site website_url site_url dominio domain_url company_website linkedin_url linkedin_company_url; do
  EXISTS=$(mysql_exec "SHOW COLUMNS FROM account LIKE '$COL';" | grep -c "$COL" || true)
  if [ "$EXISTS" -gt 0 ]; then
    echo "OK      account.$COL existe"
  else
    echo "AUSENTE account.$COL"
  fi
done

echo
echo "5. METADATA — ACCOUNT ENTITYDEFS"
echo "--------------------------------------------------"
ACC_EDEFS="$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Account.json"
if [ -f "$ACC_EDEFS" ]; then
  echo "Arquivo: $ACC_EDEFS"
  grep -n -C 4 "website\|site\|domain\|linkedin\|logoUrl\|industriaLinkedin\|employeeCountLinkedin\|enriquecidaLinkedin" "$ACC_EDEFS" || true
else
  echo "Account.json custom não encontrado"
fi

echo
echo "6. LAYOUT — ACCOUNT DETAIL"
echo "--------------------------------------------------"
ACC_LAYOUT="$BASE/custom/Espo/Custom/Resources/layouts/Account/detail.json"
if [ -f "$ACC_LAYOUT" ]; then
  grep -n -C 4 "website\|site\|domain\|linkedin\|logoUrl\|industriaLinkedin\|employeeCountLinkedin\|enriquecidaLinkedin" "$ACC_LAYOUT" || true
else
  echo "Account detail custom não encontrado"
fi

echo
echo "7. CONTROLLER ACCOUNT — ONDE WEBSITE É USADO COMO LINKEDIN"
echo "--------------------------------------------------"
ACC_CTRL="$BASE/custom/Espo/Custom/Controllers/Account.php"
if [ -f "$ACC_CTRL" ]; then
  php -l "$ACC_CTRL" || true
  grep -n -C 4 "get('website')\|set('website')\|websiteUrl\|companyWebsite\|linkedinUrl\|normalizeLinkedinUrl\|logoResolutionResult\|industry\|employeeCount" "$ACC_CTRL" || true
else
  echo "Account.php não encontrado"
fi

echo
echo "8. CONTROLLER CONTACT — CAMPOS QUE VÊM DO PROFILE"
echo "--------------------------------------------------"
CONTACT_CTRL="$BASE/custom/Espo/Custom/Controllers/Contact.php"
if [ -f "$CONTACT_CTRL" ]; then
  php -l "$CONTACT_CTRL" || true
  grep -n -C 5 "companyName\|companyLinkedin\|companyWebsite\|linkedinPublicUrl\|jobTitle\|headline\|email\|mobileNumber\|profilePicHighQuality\|ACTOR_ID\|callApify" "$CONTACT_CTRL" || true
else
  echo "Contact.php não encontrado"
fi

echo
echo "9. BANCO — CONTATO DE TESTE E CONTA ATUAL"
echo "--------------------------------------------------"
mysql_exec "
SELECT
  c.id AS contact_id,
  CONCAT(COALESCE(c.first_name,''),' ',COALESCE(c.last_name,'')) AS contato,
  c.linkedin_url AS contact_linkedin,
  c.account_id,
  a.name AS account_name,
  a.website AS account_website_linkedin,
  a.enriquecida_linkedin AS account_enriquecida,
  c.enriquecida_linkedin AS contact_enriquecida,
  c.headline,
  c.cargo
FROM contact c
LEFT JOIN account a ON a.id = c.account_id
WHERE c.id = '${CONTACT_ID}';
"

echo
echo "10. APIFY — TESTE PROFILE DO CONTATO"
echo "--------------------------------------------------"
CONTACT_LI=$(mysql_exec "SELECT linkedin_url FROM contact WHERE id='${CONTACT_ID}';" | tail -1)

echo "CONTACT_ID=$CONTACT_ID"
echo "CONTACT_LI=$CONTACT_LI"

if [ -z "$APIFY_TOKEN" ]; then
  echo "ERRO: APIFY_API_TOKEN ausente"
elif [ -z "$CONTACT_LI" ]; then
  echo "ERRO: contato sem linkedin_url"
else
  TMP="/tmp/apify_contact_profile_diag_$$.json"

  curl -s --max-time 180 -X POST \
    "https://api.apify.com/v2/acts/dev_fusion~linkedin-profile-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"profileUrls\":[\"$CONTACT_LI\"]}" > "$TMP"

  python3 <<PY
import json
path="$TMP"
raw=open(path).read()
print("bytes=", len(raw))
try:
    data=json.loads(raw)
    print("tipo=", type(data).__name__)
    print("itens=", len(data) if isinstance(data,list) else "n/a")
    if isinstance(data,list) and data:
        item=data[0]
        print("\\n--- Campos relevantes profile ---")
        for k in [
            "linkedinUrl","linkedinPublicUrl","publicIdentifier",
            "firstName","lastName","fullName",
            "headline","jobTitle",
            "email","mobileNumber",
            "companyName","companyLinkedin","companyWebsite","companyIndustry","companySize",
            "addressWithoutCountry","addressWithCountry",
            "profilePic","profilePicHighQuality",
            "isPremium","isCreator","isInfluencer",
            "about"
        ]:
            print(f"{k} = {item.get(k)}")
        print("\\n--- Todas as chaves top-level ---")
        print(", ".join(sorted(item.keys())))
except Exception as e:
    print("ERRO JSON:", e)
    print(raw[:1000])
PY

  rm -f "$TMP"
fi

echo
echo "11. APIFY — TESTE ENRIQUECIMENTO DA CONTA ATUAL"
echo "--------------------------------------------------"
ACCOUNT_LI=$(mysql_exec "
SELECT a.website
FROM contact c
JOIN account a ON a.id = c.account_id
WHERE c.id='${CONTACT_ID}'
LIMIT 1;
" | tail -1)

echo "ACCOUNT_LI=$ACCOUNT_LI"

if [ -z "$APIFY_TOKEN" ]; then
  echo "ERRO: APIFY_API_TOKEN ausente"
elif [ -z "$ACCOUNT_LI" ]; then
  echo "ERRO: conta sem website/linkedin"
else
  TMP="/tmp/apify_account_company_diag_$$.json"

  # Primeiro tenta actor atual visto no Account.php: AjfNXEI9qTA2IdaAX
  curl -s --max-time 180 -X POST \
    "https://api.apify.com/v2/acts/AjfNXEI9qTA2IdaAX/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"profileUrls\":[\"$ACCOUNT_LI\"]}" > "$TMP"

  python3 <<PY
import json
path="$TMP"
raw=open(path).read()
print("bytes=", len(raw))
try:
    data=json.loads(raw)
    print("tipo=", type(data).__name__)
    print("itens=", len(data) if isinstance(data,list) else "n/a")
    if isinstance(data,list) and data:
        item=data[0]
        print("\\n--- Campos relevantes company ---")
        for k in [
            "companyName","name","linkedinUrl","url","profileUrl","website","websiteUrl",
            "companyWebsite","domain","companyDomain",
            "industry","employeeCount","employeeCountRange",
            "description","tagline","logoResolutionResult","logoUrl","similarOrganizations"
        ]:
            print(f"{k} = {item.get(k)}")
        print("\\n--- Todas as chaves top-level ---")
        print(", ".join(sorted(item.keys())))
except Exception as e:
    print("ERRO JSON:", e)
    print(raw[:1000])
PY

  rm -f "$TMP"
fi

echo
echo "12. COMPARAÇÃO PROPOSTA — CONTA ATUAL VS EMPRESA ATUAL DO CONTATO"
echo "--------------------------------------------------"
echo "Objetivo do futuro patch:"
echo "- account.website continua temporariamente como LinkedIn da empresa."
echo "- criar novo campo em account para site real/domínio, se o retorno da API trouxer website/companyWebsite/domain."
echo "- no enriquecimento do contato, comparar companyLinkedin/companyName com a conta atual."
echo "- se companyLinkedin existir e for diferente:"
echo "  1) procurar Account por website = companyLinkedin normalizado;"
echo "  2) se existir, vincular contato nessa conta;"
echo "  3) se não existir, criar Account com website=companyLinkedin e site_real=companyWebsite/domain;"
echo "  4) contato fica na conta correta."
echo "- sem criar tabela contato_orfao."

echo
echo "13. ARQUIVOS SENSÍVEIS / BACKUPS"
echo "--------------------------------------------------"
echo "--- tokens hardcoded ---"
grep -RIn --exclude-dir=.git --exclude='*.zip' --exclude='*.tar.gz' \
  "ghp_\|github_pat_\|apify_api_" /opt/atria 2>/dev/null | head -60 || true

echo
echo "--- arquivos .bak no www que podem ir para git ---"
find "$BASE" -type f \( -name "*.bak" -o -name "*.bak.*" -o -name "*~" \) | head -80

echo
echo "=================================================="
echo "FIM DO DIAGNÓSTICO"
echo "=================================================="
