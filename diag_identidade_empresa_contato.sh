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
echo "DIAGNÓSTICO IDENTIDADE EMPRESARIAL"
echo "=================================================="

echo
echo "1. CONTATO COMPLETO"
mysql_exec "
SELECT
 id,
 first_name,
 last_name,
 title,
 cargo,
 nivel_hierarquico,
 account_id,
 account_id_anterior,
 linkedin_url,
 company_name_atual,
 company_linkedin,
 company_website,
 email_corporativo,
 status_validacao_empresa,
 enriquecida_linkedin,
 created_at,
 modified_at
FROM contact
WHERE id='${CONTACT_ID}';
"

echo
echo "2. CONTAS RELACIONADAS"
mysql_exec "
SELECT
 id,
 name,
 website,
 company_website,
 enriched_linkedin_url,
 enriched_company_name,
 enriquecida_linkedin,
 created_at
FROM account
WHERE id IN (
    SELECT account_id FROM contact WHERE id='${CONTACT_ID}'
    UNION
    SELECT account_id_anterior FROM contact WHERE id='${CONTACT_ID}'
);
"

echo
echo "3. RELACIONAMENTOS MANY-TO-MANY"
mysql_exec "
SELECT *
FROM account_contact
WHERE contact_id='${CONTACT_ID}';
"

echo
echo "4. HISTÓRICO EMPRESARIAL"
mysql_exec "
SELECT
 id,
 empresa_anterior,
 empresa_atual,
 linkedin_empresa_anterior,
 linkedin_empresa_atual,
 motivo,
 created_at
FROM contact_company_history
WHERE contact_id='${CONTACT_ID}'
ORDER BY created_at DESC;
"

echo
echo "5. DUPLICIDADE ALGAR"
mysql_exec "
SELECT
 id,
 name,
 website,
 company_website,
 enriquecida_linkedin,
 created_at
FROM account
WHERE
 name LIKE '%Algar%'
 OR website LIKE '%algar%'
ORDER BY name;
"

echo
echo "6. CAMPOS ACCOUNT CUSTOM"
mysql_exec "
SHOW COLUMNS FROM account;
" | grep -E "website|linkedin|company|domain|group|holding"

echo
echo "7. REDIS CONTATO"
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
        \$json = json_decode(\$value, true);
        print_r(array_keys((array)\$json));
    }

    \$r->close();
} catch (Throwable \$e) {
    echo 'ERRO Redis: ' . \$e->getMessage() . PHP_EOL;
}
PHP

echo
echo "=================================================="
echo "FIM DIAGNÓSTICO"
echo "=================================================="
