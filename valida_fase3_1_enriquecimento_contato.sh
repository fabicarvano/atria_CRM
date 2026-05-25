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

echo "=================================================="
echo "VALIDAÇÃO FASE 3.1 — Enriquecimento Contato"
echo "=================================================="

echo
echo "1. Contact atualizado"
mysql_exec "
SELECT
 id,
 account_id,
 account_id_anterior,
 linkedin_url,
 company_name_atual,
 company_linkedin,
 company_website,
 email_corporativo,
 fonte_email,
 data_enriquecimento_email,
 status_validacao_empresa,
 headline,
 cargo,
 enriquecida_linkedin,
 data_enriquecimento_linkedin,
 fonte_enriquecimento
FROM contact
WHERE id='${CONTACT_ID}';
"

echo
echo "2. Conta atual vinculada ao contato"
mysql_exec "
SELECT
 a.id,
 a.name,
 a.website,
 a.company_website,
 a.enriquecida_linkedin,
 a.fonte_enriquecimento
FROM contact c
LEFT JOIN account a ON a.id = c.account_id
WHERE c.id='${CONTACT_ID}';
"

echo
echo "3. Histórico criado"
mysql_exec "
SELECT
 id,
 contact_id,
 account_id_anterior,
 account_id_novo,
 empresa_anterior,
 empresa_atual,
 linkedin_empresa_anterior,
 linkedin_empresa_atual,
 company_website,
 cargo,
 email,
 motivo,
 fonte,
 created_at
FROM contact_company_history
WHERE contact_id='${CONTACT_ID}'
ORDER BY created_at DESC
LIMIT 10;
"

echo
echo "4. Redis"
php <<PHP
<?php
\$host = '$(get_env "REDIS_HOST")' ?: '127.0.0.1';
\$port = (int) ('$(get_env "REDIS_PORT")' ?: 6379);
\$pass = '$(get_env "REDIS_PASS")';

try {
    \$r = new Redis();
    \$r->connect(\$host, \$port, 2.5);
    if (\$pass !== '') \$r->auth(\$pass);

    \$key = 'contact:linkedin-enrichment:$CONTACT_ID';
    \$value = \$r->get(\$key);

    echo \$key . ': ' . (\$value ? 'EXISTE' : 'NÃO EXISTE') . PHP_EOL;
    if (\$value) {
        echo 'TTL=' . \$r->ttl(\$key) . PHP_EOL;
        echo substr(\$value, 0, 500) . PHP_EOL;
    }

    \$r->close();
} catch (Throwable \$e) {
    echo 'ERRO Redis: ' . \$e->getMessage() . PHP_EOL;
}
PHP

echo
echo "5. Logs recentes EspoCRM"
find /opt/atria/www/data/logs -type f -maxdepth 1 -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -3 | awk '{print $2}' | while read LOG; do
  echo "--- $LOG ---"
  tail -80 "$LOG" | grep -i -C 4 "contact\\|enriquecer\\|apify\\|error\\|exception" || true
done

echo
echo "=================================================="
echo "FIM DA VALIDAÇÃO"
echo "=================================================="
