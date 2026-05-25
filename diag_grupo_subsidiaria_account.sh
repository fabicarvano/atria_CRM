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
  mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1"
}

echo "=================================================="
echo "DIAGNÓSTICO — GRUPO / SUBSIDIÁRIA EM ACCOUNT"
echo "=================================================="

echo
echo "1. Colunas atuais em account relacionadas a hierarquia"
mysql_exec "SHOW COLUMNS FROM account;" | grep -E "Field|parent|pai|grupo|subsidiaria|tipo|empresa|account|website|name|created_at" || true

echo
echo "2. Metadata Account — procurar parent/tipo existente"
grep -n -C 4 "parent\\|pai\\|grupo\\|subsidiaria\\|tipoEmpresa\\|tipo_empresa\\|account" \
"$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Account.json" || true

echo
echo "3. Layout Account — procurar campos hierárquicos existentes"
grep -n -C 4 "parent\\|pai\\|grupo\\|subsidiaria\\|tipoEmpresa\\|tipo_empresa" \
"$BASE/custom/Espo/Custom/Resources/layouts/Account/detail.json" || true

echo
echo "4. Tabelas de relacionamento com account"
mysql_exec "
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = '${DB_NAME}'
  AND TABLE_NAME LIKE '%account%';
"

echo
echo "5. Colunas com parent/group/tipo no banco inteiro"
mysql_exec "
SELECT
 TABLE_NAME,
 COLUMN_NAME,
 COLUMN_TYPE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = '${DB_NAME}'
  AND (
    COLUMN_NAME LIKE '%parent%'
    OR COLUMN_NAME LIKE '%pai%'
    OR COLUMN_NAME LIKE '%grupo%'
    OR COLUMN_NAME LIKE '%subsidi%'
    OR COLUMN_NAME LIKE '%tipo%'
  )
ORDER BY TABLE_NAME, COLUMN_NAME;
"

echo
echo "6. Contato Thiago — vínculos atuais"
mysql_exec "
SELECT
 c.id AS contact_id,
 CONCAT(COALESCE(c.first_name,''),' ',COALESCE(c.last_name,'')) AS contato,
 c.account_id AS account_id_principal,
 c.account_id_anterior,
 c.company_name_atual,
 c.company_linkedin,
 c.company_website,
 c.status_validacao_empresa,
 c.enriquecida_linkedin
FROM contact c
WHERE c.id='${CONTACT_ID}';
"

echo
echo "7. account_contact do Thiago"
mysql_exec "
SELECT
 ac.id,
 ac.account_id,
 a.name AS account_name,
 a.website,
 a.company_website,
 ac.contact_id,
 ac.role,
 ac.is_inactive,
 ac.deleted
FROM account_contact ac
LEFT JOIN account a ON a.id = ac.account_id
WHERE ac.contact_id='${CONTACT_ID}'
ORDER BY ac.id;
"

echo
echo "8. Contas Algar existentes"
mysql_exec "
SELECT
 id,
 name,
 website,
 company_website,
 enriquecida_linkedin,
 created_at,
 modified_at
FROM account
WHERE deleted = 0
  AND (
    name LIKE '%Algar%'
    OR website LIKE '%algar%'
    OR company_website LIKE '%algar%'
  )
ORDER BY created_at;
"

echo
echo "9. Histórico empresarial do contato"
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
 motivo,
 fonte,
 created_at
FROM contact_company_history
WHERE contact_id='${CONTACT_ID}'
ORDER BY created_at DESC;
"

echo
echo "10. Contact.php — regra atual de movimentação"
grep -n -C 8 "validarEMoverEmpresaDoContato\\|buscarContaPorLinkedin\\|criarContaPorEmpresaLinkedin\\|registrarHistoricoEmpresa\\|statusValidacaoEmpresa" \
"$BASE/custom/Espo/Custom/Controllers/Contact.php" || true

echo
echo "11. Account.php — helpers de normalização/match"
grep -n -C 6 "normalizeComparableUrl\\|normalizeLinkedinUrl\\|buscarContaExistenteParaSimilar\\|set('website'\\|companyWebsite" \
"$BASE/custom/Espo/Custom/Controllers/Account.php" || true

echo
echo "12. Verificar se Account tem relacionamentos no metadata global/cache"
grep -RIn "parentAccount\\|parent\\|children\\|accountParent\\|subsidi" \
"$BASE/custom/Espo/Custom/Resources/metadata" \
"$BASE/application/Espo/Resources/metadata" \
"$BASE/data/cache/application" 2>/dev/null | head -80 || true

echo
echo "13. Avaliação objetiva esperada"
echo "--------------------------------------------------"
echo "Se NÃO existir parent_account_id/tipo_empresa, próxima fase deve criar:"
echo "- account.parent_account_id"
echo "- account.tipo_empresa"
echo "- metadata/layout labels"
echo "- regra Contact.php: se conta atual e nova estiverem no mesmo grupo, NÃO mover"
echo "- correção manual/automática do caso Algar/Algar Telecom"

echo
echo "=================================================="
echo "FIM DO DIAGNÓSTICO"
echo "=================================================="
