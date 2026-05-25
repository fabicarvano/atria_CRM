#!/bin/bash

ENV_FILE="/opt/atria/.env"
CONTACT_ID="6a10e2d28d4292835"

get_env() {
  grep -oP "^${1}=\K[^\r\n]+" "$ENV_FILE" 2>/dev/null | tr -d "\"'" | head -1
}

DB_HOST=$(get_env "DB_HOST"); DB_HOST=${DB_HOST:-localhost}
DB_NAME=$(get_env "DB_NAME")
DB_USER=$(get_env "DB_USER")
DB_PASS=$(get_env "DB_PASS")

mysql_exec() {
  mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1"
}

echo "=== 1. Status do contato no banco ==="
mysql_exec "
SELECT
 id,
 first_name,
 last_name,
 linkedin_url,
 enriquecida_linkedin,
 data_enriquecimento_linkedin,
 fonte_enriquecimento,
 headline,
 cargo
FROM contact
WHERE id='${CONTACT_ID}';
"

echo
echo "=== 2. Ver se JS tem botão no arquivo físico ==="
grep -n -C 4 "enriquecerLinkedin\|_actionEnriquecerLinkedin\|addMenuItem" \
/opt/atria/www/client/custom/src/views/contact/detail.js || true

echo
echo "=== 3. Ver se JS está acessível pela URL local ==="
curl -s http://localhost/client/custom/src/views/contact/detail.js \
| grep -n -C 4 "enriquecerLinkedin\|_actionEnriquecerLinkedin\|addMenuItem" || echo "NÃO encontrou no JS servido por HTTP"

echo
echo "=== 4. Headers/cache do JS ==="
curl -I http://localhost/client/custom/src/views/contact/detail.js

echo
echo "=== 5. ClientDefs Account e Contact ==="
echo "--- Account ---"
cat /opt/atria/www/custom/Espo/Custom/Resources/metadata/clientDefs/Account.json 2>/dev/null || true

echo
echo "--- Contact ---"
cat /opt/atria/www/custom/Espo/Custom/Resources/metadata/clientDefs/Contact.json

echo
echo "=== 6. Rebuild final ==="
cd /opt/atria/www
php command.php clear-cache
php command.php rebuild

echo
echo "=== FIM ==="
