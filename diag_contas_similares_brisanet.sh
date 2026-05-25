#!/bin/bash

ENV_FILE="/opt/atria/.env"
BASE="/opt/atria/www"

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
echo "DIAGNÓSTICO — CONTAS SIMILARES BRISANET"
echo "=================================================="

echo
echo "1. Localizando conta Brisanet"
mysql_exec "
SELECT
 id,
 name,
 website,
 company_website,
 enriquecida_linkedin,
 fonte_enriquecimento,
 data_enriquecimento_linkedin
FROM account
WHERE deleted = 0
  AND name LIKE '%Brisanet%';
"

ACCOUNT_ID=$(mysql_exec "
SELECT id
FROM account
WHERE deleted = 0
  AND name LIKE '%Brisanet%'
LIMIT 1;
" | tail -1)

echo
echo "ACCOUNT_ID=$ACCOUNT_ID"

echo
echo "2. Verificando tabela conta_similar"
mysql_exec "SHOW TABLES LIKE 'conta_similar';"
mysql_exec "SHOW COLUMNS FROM conta_similar;"

echo
echo "3. Registros de contas similares para Brisanet"
mysql_exec "
SELECT
 id,
 account_id,
 name,
 linkedin_url,
 website_url,
 industry,
 employee_count,
 exists_in_crm,
 matched_account_id,
 match_reason,
 is_created,
 created_account_id,
 source,
 created_at,
 modified_at
FROM conta_similar
WHERE account_id = '${ACCOUNT_ID}'
ORDER BY created_at DESC
LIMIT 50;
"

echo
echo "4. Totais por account_id similares recentes"
mysql_exec "
SELECT
 account_id,
 COUNT(*) AS total,
 SUM(CASE WHEN deleted = 0 THEN 1 ELSE 0 END) AS ativos,
 SUM(CASE WHEN exists_in_crm = 1 THEN 1 ELSE 0 END) AS ja_existem,
 SUM(CASE WHEN is_created = 1 THEN 1 ELSE 0 END) AS ja_criados
FROM conta_similar
GROUP BY account_id
ORDER BY total DESC
LIMIT 20;
"

echo
echo "5. Controller Account — fluxo de similares"
grep -n -C 6 "conta_similar\\|similarOrganizations\\|processar.*Similar\\|postAction.*Similar\\|listar.*Similar" \
"$BASE/custom/Espo/Custom/Controllers/Account.php" || true

echo
echo "6. View painel Contas Similares"
grep -RIn -C 5 "Esta conta ainda não foi enriquecida\\|contas similares\\|conta_similar\\|contasSimilares\\|similar" \
"$BASE/client/custom/src/views/account" \
"$BASE/custom/Espo/Custom/Resources/metadata/clientDefs/Account.json" || true

echo
echo "7. Redis de enriquecimento da conta"
php <<PHP
<?php
\$host = '$(get_env "REDIS_HOST")' ?: '127.0.0.1';
\$port = (int) ('$(get_env "REDIS_PORT")' ?: 6379);
\$pass = '$(get_env "REDIS_PASS")';
\$accountId = '$ACCOUNT_ID';

try {
    \$r = new Redis();
    \$r->connect(\$host, \$port, 2.5);
    if (\$pass !== '') \$r->auth(\$pass);

    foreach ([
        'account:linkedin-enrichment:' . \$accountId,
        'account:linkedin-employees:' . \$accountId
    ] as \$key) {
        \$value = \$r->get(\$key);
        echo \$key . ': ' . (\$value ? 'EXISTE' : 'NÃO EXISTE') . PHP_EOL;
        if (\$value) {
            echo 'TTL=' . \$r->ttl(\$key) . ' bytes=' . strlen(\$value) . PHP_EOL;
            echo substr(\$value, 0, 800) . PHP_EOL;
        }
    }

    \$r->close();
} catch (Throwable \$e) {
    echo 'ERRO Redis: ' . \$e->getMessage() . PHP_EOL;
}
PHP

echo
echo "8. Logs recentes"
find "$BASE/data/logs" -type f -maxdepth 1 -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -3 | awk '{print $2}' | while read LOG; do
  echo "--- $LOG ---"
  tail -120 "$LOG" | grep -i -C 5 "similar\\|conta_similar\\|Brisanet\\|enriquecer\\|error\\|exception" || true
done

echo
echo "=================================================="
echo "FIM"
echo "=================================================="
