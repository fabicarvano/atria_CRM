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

mysql_exec() {
  mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1" 2>/dev/null
}

echo "=================================================="
echo "DIAGNÓSTICO ERRO API — Contact/enriquecerLinkedin"
echo "=================================================="

echo
echo "1. CONTATO NO BANCO"
echo "--------------------------------------------------"
mysql_exec "
SELECT
 id, first_name, last_name, linkedin_url,
 enriquecida_linkedin, data_enriquecimento_linkedin,
 fonte_enriquecimento, headline, cargo
FROM contact
WHERE id='${CONTACT_ID}';
"

echo
echo "2. CONTROLLER CONTACT — SYNTAX E TRECHOS"
echo "--------------------------------------------------"
php -l "$BASE/custom/Espo/Custom/Controllers/Contact.php" || true

grep -n -C 4 "postActionEnriquecerLinkedin\|callApify\|saveRedis\|logUso\|enriquecidaLinkedin\|locationLinkedin\|isPremium" \
"$BASE/custom/Espo/Custom/Controllers/Contact.php" || true

echo
echo "3. LOGS ESPOCRM — ÚLTIMAS LINHAS"
echo "--------------------------------------------------"
find "$BASE/data/logs" -type f -maxdepth 1 -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -5

echo
echo "--- últimos erros nos logs do EspoCRM ---"
for LOG in $(find "$BASE/data/logs" -type f -maxdepth 1 2>/dev/null | sort | tail -5); do
  echo
  echo "### $LOG"
  tail -120 "$LOG" | grep -i -C 5 "error\|exception\|critical\|Contact\|enriquecerLinkedin\|Apify\|Redis" || true
done

echo
echo "4. LOGS PHP-FPM / NGINX"
echo "--------------------------------------------------"
for LOG in \
/var/log/nginx/error.log \
/var/log/nginx/access.log \
/var/log/php8.3-fpm.log \
/var/log/php8.2-fpm.log \
/var/log/php8.1-fpm.log
do
  if [ -f "$LOG" ]; then
    echo
    echo "### $LOG"
    tail -80 "$LOG" | grep -i -C 3 "error\|fatal\|Contact\|enriquecer\|api/v1\|BadRequest" || true
  fi
done

echo
echo "5. ROTAS / URLS POSSÍVEIS — TESTE HTTP SEM TOKEN"
echo "--------------------------------------------------"
for URL in \
"http://localhost/api/v1/Contact/action/enriquecerLinkedin" \
"http://localhost/Contact/action/enriquecerLinkedin" \
"http://localhost/api/v1/Contact/action/enriquecerLinkedin?api=true"
do
  echo
  echo ">>> $URL"
  curl -s -i -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"$CONTACT_ID\"}" | head -80
done

echo
echo "6. VERIFICAR SE EXISTE API KEY NO .ENV"
echo "--------------------------------------------------"
grep -n "API" "$ENV_FILE" | sed -E 's/(=).+/\1***OCULTO***/' || true

echo
echo "7. ESTADO REDIS"
echo "--------------------------------------------------"
REDIS_HOST=$(get_env "REDIS_HOST"); REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=$(get_env "REDIS_PORT"); REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASS=$(get_env "REDIS_PASS")

export REDIS_HOST REDIS_PORT REDIS_PASS CONTACT_ID

php <<'PHP'
<?php
$host = getenv('REDIS_HOST') ?: '127.0.0.1';
$port = (int) (getenv('REDIS_PORT') ?: 6379);
$pass = getenv('REDIS_PASS') ?: '';
$contactId = getenv('CONTACT_ID');

try {
    $r = new Redis();
    $r->connect($host, $port, 2.5);
    if ($pass !== '') $r->auth($pass);

    $key = 'contact:linkedin-enrichment:' . $contactId;
    echo "KEY {$key}: ";
    $val = $r->get($key);
    if ($val) {
        echo "EXISTE TTL=" . $r->ttl($key) . " bytes=" . strlen($val) . PHP_EOL;
        echo substr($val, 0, 1000) . PHP_EOL;
    } else {
        echo "NÃO EXISTE" . PHP_EOL;
    }

    $r->close();
} catch (Throwable $e) {
    echo "ERRO Redis: " . $e->getMessage() . PHP_EOL;
}
PHP

echo
echo "8. TESTE DIRETO APIFY COM LINKEDIN DO CONTATO"
echo "--------------------------------------------------"
APIFY_TOKEN=$(get_env "APIFY_API_TOKEN")
LI_URL=$(mysql_exec "SELECT linkedin_url FROM contact WHERE id='${CONTACT_ID}';" | tail -1)

echo "LinkedIn URL: $LI_URL"

if [ -n "$APIFY_TOKEN" ] && [ -n "$LI_URL" ]; then
  TMP="/tmp/apify_contact_error_diag_$$.json"
  curl -s -w "\nHTTP_CODE:%{http_code}\n" --max-time 180 -X POST \
    "https://api.apify.com/v2/acts/dev_fusion~linkedin-profile-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"profileUrls\":[\"$LI_URL\"]}" > "$TMP"

  cat "$TMP" | head -80
  rm -f "$TMP"
else
  echo "APIFY_TOKEN ou LI_URL ausente"
fi

echo
echo "9. FIM"
echo "=================================================="
