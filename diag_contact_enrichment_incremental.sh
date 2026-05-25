#!/bin/bash

echo "=================================================="
echo "DIAGNÓSTICO INCREMENTAL — ENRIQUECIMENTO CONTATOS"
echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="

BASE="/opt/atria/www"
ENV_FILE="/opt/atria/.env"

echo
echo "1. AMBIENTE"
echo "--------------------------------------------------"
pwd
echo "BASE=$BASE"
test -d "$BASE" && echo "OK: pasta BASE existe" || echo "ERRO: pasta BASE não existe"
test -f "$ENV_FILE" && echo "OK: .env existe" || echo "ERRO: .env não existe"

DB_HOST=$(grep -oP '^DB_HOST=\K.*' "$ENV_FILE" 2>/dev/null | tr -d '"' | head -1)
DB_NAME=$(grep -oP '^DB_NAME=\K.*' "$ENV_FILE" 2>/dev/null | tr -d '"' | head -1)
DB_USER=$(grep -oP '^DB_USER=\K.*' "$ENV_FILE" 2>/dev/null | tr -d '"' | head -1)
DB_PASS=$(grep -oP '^DB_PASS=\K.*' "$ENV_FILE" 2>/dev/null | tr -d '"' | head -1)
DB_HOST=${DB_HOST:-localhost}

mysql_exec() {
  mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1" 2>/dev/null
}

echo "DB_HOST=$DB_HOST"
echo "DB_NAME=$DB_NAME"
echo "DB_USER=$DB_USER"

echo
echo "2. GIT — STATUS, COMMITS E ARQUIVOS SENSÍVEIS"
echo "--------------------------------------------------"
for DIR in "/opt/atria" "/opt/atria/www"; do
  echo
  echo ">>> Repositório: $DIR"
  if [ -d "$DIR/.git" ]; then
    cd "$DIR"
    echo "--- branch ---"
    git branch --show-current
    echo "--- status curto ---"
    git status --short
    echo "--- últimos commits ---"
    git log --oneline -5
    echo "--- remote sem token visível ---"
    git remote -v | sed -E 's#https://[^@]+@github.com#https://***TOKEN***@github.com#g'
    echo "--- commits locais não enviados ---"
    git log origin/main..HEAD --oneline 2>/dev/null || true
  else
    echo "NÃO É REPOSITÓRIO GIT"
  fi
done

echo
echo "3. BUSCA POR TOKENS HARDCODED"
echo "--------------------------------------------------"
cd /opt/atria
grep -RIn --exclude-dir=.git --exclude='*.zip' --exclude='*.tar.gz' \
  "ghp_\|github_pat_\|apify_api_" . 2>/dev/null | head -80 || true

echo
echo "4. ARQUIVOS-CHAVE — EXISTÊNCIA"
echo "--------------------------------------------------"
FILES=(
"$BASE/custom/Espo/Custom/Controllers/Account.php"
"$BASE/custom/Espo/Custom/Controllers/Contact.php"
"$BASE/client/custom/src/views/account/detail.js"
"$BASE/client/custom/src/views/contact/detail.js"
"$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Contact.json"
"$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json"
"$BASE/custom/Espo/Custom/Resources/metadata/clientDefs/Contact.json"
)

for F in "${FILES[@]}"; do
  if [ -f "$F" ]; then
    echo "OK: $F"
  else
    echo "AUSENTE: $F"
  fi
done

echo
echo "5. CONTACT DETAIL.JS — CONTEXTO ATUAL"
echo "--------------------------------------------------"
JS="$BASE/client/custom/src/views/contact/detail.js"
if [ -f "$JS" ]; then
  echo "--- grep avatar existente ---"
  grep -n -C 3 "_waitAndInjectAvatar\|_injectAvatar\|linkedinPhotoUrl\|hide-contact-photo-label" "$JS" || true

  echo
  echo "--- grep botão enriquecer ---"
  grep -n -C 3 "enriquecerLinkedin\|_actionEnriquecerLinkedin\|Contact/action/enriquecerLinkedin\|enriquecidaLinkedin" "$JS" || true

  echo
  echo "--- início do arquivo ---"
  sed -n '1,180p' "$JS"
else
  echo "ERRO: contact/detail.js não encontrado"
fi

echo
echo "6. ACCOUNT DETAIL.JS — MODELO DO BOTÃO QUE FUNCIONA"
echo "--------------------------------------------------"
ACCJS="$BASE/client/custom/src/views/account/detail.js"
if [ -f "$ACCJS" ]; then
  grep -n -C 4 "enriquecerLinkedin\|_actionEnriquecerLinkedin\|_controlEnriquecimentoButtons\|Account/action/enriquecerLinkedin" "$ACCJS" || true
else
  echo "ERRO: account/detail.js não encontrado"
fi

echo
echo "7. CONTROLLER ACCOUNT — FLUXO EXISTENTE"
echo "--------------------------------------------------"
ACC="$BASE/custom/Espo/Custom/Controllers/Account.php"
if [ -f "$ACC" ]; then
  echo "--- Syntax PHP ---"
  php -l "$ACC" || true

  echo
  echo "--- Enriquecimento conta / Redis / Apify ---"
  grep -n -C 3 "postActionEnriquecerLinkedin\|postActionGravarEnriquecimentoLinkedinRedis\|postActionProcessarEnriquecimentoLinkedinRedis\|saveRedisJson\|loadRedisJson\|callApifyActor" "$ACC" || true

  echo
  echo "--- Contatos executivos / proteção duplicidade ---"
  grep -n -C 4 "buscarESalvarContatosExecutivos\|processarESalvarContatosDoRedis\|buscarContatoExistenteNoCrm\|buscarContatoExecutivoExistente\|postActionCriarContatoExecutivo\|exists_in_crm\|matched_contact_id" "$ACC" || true
else
  echo "ERRO: Account.php não encontrado"
fi

echo
echo "8. CONTROLLER CONTACT — SE EXISTE, ANALISAR SEM ALTERAR"
echo "--------------------------------------------------"
CTRL="$BASE/custom/Espo/Custom/Controllers/Contact.php"
if [ -f "$CTRL" ]; then
  php -l "$CTRL" || true
  grep -n -C 4 "postActionEnriquecerLinkedin\|saveRedis\|Redis\|Apify\|enriquecidaLinkedin\|callApify" "$CTRL" || true
else
  echo "Contact.php AUSENTE — endpoint Contact/action/enriquecerLinkedin ainda não existe"
fi

echo
echo "9. ENTITYDEFS CONTACT.JSON — CAMPOS"
echo "--------------------------------------------------"
EDEFS="$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Contact.json"
if [ -f "$EDEFS" ]; then
  python3 - <<PY
import json
path="$EDEFS"
with open(path) as f:
    d=json.load(f)
fields=d.get("fields",{})
check=[
"opportunityRole","linkedinUrl","linkedinPhotoUrl","linkedinLastSync","nivelHierarquico",
"headline","locationLinkedin","isPremium","isCreator","isInfluencer",
"enriquecidaLinkedin","dataEnriquecimentoLinkedin","fonteEnriquecimento"
]
for c in check:
    print(("OK      " if c in fields else "AUSENTE ") + c)
PY
  echo
  echo "--- contexto textual ---"
  grep -n -C 3 "linkedinUrl\|linkedinPhotoUrl\|linkedinLastSync\|nivelHierarquico\|headline\|enriquecidaLinkedin\|isPremium\|locationLinkedin" "$EDEFS" || true
else
  echo "ERRO: entityDefs Contact.json não encontrado"
fi

echo
echo "10. LAYOUT CONTACT DETAIL.JSON — CAMPOS NA TELA"
echo "--------------------------------------------------"
LAYOUT="$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json"
if [ -f "$LAYOUT" ]; then
  python3 - <<PY
import json
path="$LAYOUT"
with open(path) as f:
    d=json.load(f)

wanted=[
"linkedinPhotoUrl","name","accounts","emailAddress","phoneNumber","nivelHierarquico",
"linkedinUrl","headline","cargo","locationLinkedin","linkedinLastSync",
"isPremium","isCreator","isInfluencer","enriquecidaLinkedin",
"dataEnriquecimentoLinkedin","fonteEnriquecimento"
]

txt=json.dumps(d, ensure_ascii=False)
for w in wanted:
    print(("OK      " if w in txt else "AUSENTE ") + w)

print("\\nTotal de seções:", len(d) if isinstance(d,list) else "layout não é lista")
for i,s in enumerate(d if isinstance(d,list) else []):
    print(f"Secao {i}: label={s.get('label')} name={s.get('name')}")
PY
  echo
  echo "--- conteúdo atual ---"
  cat "$LAYOUT"
else
  echo "ERRO: layout Contact/detail.json não encontrado"
fi

echo
echo "11. BANCO — COLUNAS CONTACT"
echo "--------------------------------------------------"
mysql_exec "SELECT 1;" >/dev/null && echo "OK: conexão MySQL" || echo "ERRO: sem conexão MySQL"

echo
echo "--- colunas atuais relevantes ---"
mysql_exec "
SHOW COLUMNS FROM contact;
" | grep -E "Field|linkedin|cargo|picture|nivel|headline|enriquecida|fonte|premium|creator|influencer|location|sync|description|first_name|last_name|account_id" || true

echo
echo "--- checklist colunas necessárias ---"
for COL in \
linkedin_url cargo picture_url linkedin_photo_url linkedin_last_sync nivel_hierarquico \
enriquecida_linkedin data_enriquecimento_linkedin fonte_enriquecimento headline \
location_linkedin is_premium is_creator is_influencer
do
  EXISTS=$(mysql_exec "SHOW COLUMNS FROM contact LIKE '$COL';" | grep -c "$COL" || true)
  if [ "$EXISTS" -gt 0 ]; then
    echo "OK      contact.$COL"
  else
    echo "AUSENTE contact.$COL"
  fi
done

echo
echo "12. BANCO — TABELAS DE LOG E CONTATOS EXECUTIVOS"
echo "--------------------------------------------------"
for T in contact_enrichment_usage contato_executivo contato_executivo_config account_enrichment_usage conta_similar; do
  EXISTS=$(mysql_exec "SHOW TABLES LIKE '$T';" | grep -c "$T" || true)
  if [ "$EXISTS" -gt 0 ]; then
    echo "OK      tabela $T"
    mysql_exec "SHOW COLUMNS FROM $T;" | head -60
    echo
  else
    echo "AUSENTE tabela $T"
  fi
done

echo
echo "13. BANCO — AMOSTRA CONTATOS COM LINKEDIN"
echo "--------------------------------------------------"
mysql_exec "
SELECT
  id,
  CONCAT(COALESCE(first_name,''),' ',COALESCE(last_name,'')) AS nome,
  account_id,
  linkedin_url,
  cargo,
  linkedin_photo_url,
  linkedin_last_sync
FROM contact
WHERE deleted = 0
ORDER BY created_at DESC
LIMIT 10;
"

echo
echo "--- totais ---"
mysql_exec "
SELECT
  COUNT(*) AS total_contatos,
  SUM(CASE WHEN linkedin_url IS NOT NULL AND linkedin_url <> '' THEN 1 ELSE 0 END) AS com_linkedin,
  SUM(CASE WHEN linkedin_url IS NULL OR linkedin_url = '' THEN 1 ELSE 0 END) AS sem_linkedin
FROM contact
WHERE deleted = 0;
"

echo
echo "14. REDIS — CONECTIVIDADE E CHAVES"
echo "--------------------------------------------------"
REDIS_HOST=$(grep -oP '^REDIS_HOST=\K.*' "$ENV_FILE" 2>/dev/null | tr -d '"' | head -1)
REDIS_PORT=$(grep -oP '^REDIS_PORT=\K.*' "$ENV_FILE" 2>/dev/null | tr -d '"' | head -1)
REDIS_PASS=$(grep -oP '^REDIS_PASS=\K.*' "$ENV_FILE" 2>/dev/null | tr -d '"' | head -1)
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}

export REDIS_HOST REDIS_PORT REDIS_PASS

php <<'PHP'
<?php
$host = getenv('REDIS_HOST') ?: '127.0.0.1';
$port = (int) (getenv('REDIS_PORT') ?: 6379);
$pass = getenv('REDIS_PASS') ?: '';

try {
    $r = new Redis();
    $r->connect($host, $port, 2.5);

    if ($pass !== '') {
        $r->auth($pass);
    }

    echo "OK: Redis conectado\n";

    $patterns = [
        'account:linkedin-enrichment:*',
        'account:linkedin-employees:*',
        'contact:linkedin-enrichment:*',
        'contact:linkedin-*',
    ];

    foreach ($patterns as $pattern) {
        $keys = $r->keys($pattern);
        echo "PADRAO {$pattern} = " . count($keys) . "\n";

        foreach (array_slice($keys, 0, 10) as $key) {
            echo "  {$key} TTL=" . $r->ttl($key) . "\n";
        }
    }

    $r->close();
} catch (Throwable $e) {
    echo "ERRO Redis: " . $e->getMessage() . "\n";
}
PHP

echo "15. APIFY — TOKEN E ACTOR"
echo "--------------------------------------------------"
APIFY_TOKEN=$(grep -oP '^APIFY_API_TOKEN=\K.*' "$ENV_FILE" 2>/dev/null | tr -d '"' | head -1)
if [ -n "$APIFY_TOKEN" ]; then
  echo "OK: APIFY_API_TOKEN encontrado (${APIFY_TOKEN:0:18}...)"

  echo "--- /users/me ---"
  curl -s --max-time 20 "https://api.apify.com/v2/users/me?token=$APIFY_TOKEN" | python3 -c "import sys,json; d=json.load(sys.stdin); print('username=', d.get('data',{}).get('username'))" 2>/dev/null || echo "ERRO ao validar token"

  TEST_URL=$(mysql_exec "SELECT linkedin_url FROM contact WHERE deleted=0 AND linkedin_url IS NOT NULL AND linkedin_url <> '' LIMIT 1;" | tail -1)
  echo "URL teste banco: $TEST_URL"

  if [ -n "$TEST_URL" ] && [ "$TEST_URL" != "linkedin_url" ]; then
    echo "--- chamada actor dev_fusion/linkedin-profile-scraper ---"
    TMP="/tmp/apify_contact_diag_$$.json"
    curl -s --max-time 180 -X POST \
      "https://api.apify.com/v2/acts/dev_fusion~linkedin-profile-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"profileUrls\":[\"$TEST_URL\"]}" > "$TMP"

    python3 - <<PY
import json, os
path="$TMP"
raw=open(path).read()
print("bytes=", len(raw))
try:
    d=json.loads(raw)
    print("tipo=", type(d).__name__)
    print("itens=", len(d) if isinstance(d,list) else "n/a")
    if isinstance(d,list) and d:
        item=d[0]
        for k in ["linkedinUrl","firstName","lastName","fullName","headline","email","mobileNumber","jobTitle","companyName","addressWithoutCountry","profilePic","profilePicHighQuality","isPremium","isCreator","isInfluencer","about","publicIdentifier","linkedinPublicUrl"]:
            print(f"{k}=", item.get(k))
except Exception as e:
    print("ERRO JSON:", e)
    print(raw[:500])
PY
    rm -f "$TMP"
  fi
else
  echo "ERRO: APIFY_API_TOKEN ausente"
fi

echo
echo "16. BACKUPS E ARQUIVOS .BAK QUE PODEM IR PARA GIT"
echo "--------------------------------------------------"
find /opt/atria -type f \( -name "*.bak" -o -name "*.bak.*" -o -name "*~" \) | head -100

echo
echo "17. CONFIGS SENSÍVEIS VERSIONADAS"
echo "--------------------------------------------------"
for F in \
"$BASE/data/config.php" \
"$BASE/data/config-internal.php" \
"/opt/atria/.env"
do
  if [ -f "$F" ]; then
    echo "EXISTE: $F"
    if [ -d /opt/atria/.git ]; then
      cd /opt/atria && git ls-files --error-unmatch "${F#/opt/atria/}" >/dev/null 2>&1 && echo "  ATENÇÃO: versionado em /opt/atria" || true
    fi
    if [ -d "$BASE/.git" ]; then
      cd "$BASE" && git ls-files --error-unmatch "${F#$BASE/}" >/dev/null 2>&1 && echo "  ATENÇÃO: versionado em /opt/atria/www" || true
    fi
  fi
done

echo
echo "18. RESUMO OBJETIVO"
echo "--------------------------------------------------"
echo "Se aparecer AUSENTE em Contact.php, campos contact.*, botão no detail.js ou metadata/layout,"
echo "a próxima etapa deve ser script incremental, sem sobrescrever arquivos inteiros."
echo "Cole todo este resultado para gerar o patch exato."

echo
echo "=================================================="
echo "FIM DO DIAGNÓSTICO"
echo "=================================================="
