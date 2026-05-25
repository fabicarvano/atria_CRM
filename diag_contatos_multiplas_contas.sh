#!/bin/bash

ENV_FILE="/opt/atria/.env"

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
echo "DIAGNÓSTICO — CONTATOS COM MÚLTIPLAS CONTAS ATIVAS"
echo "=================================================="

echo
echo "1. Total de contatos com mais de uma conta ativa"
mysql_exec "
SELECT COUNT(*) AS contatos_com_multiplas_contas
FROM (
  SELECT contact_id
  FROM account_contact
  WHERE deleted = 0
    AND IFNULL(is_inactive, 0) = 0
  GROUP BY contact_id
  HAVING COUNT(*) > 1
) x;
"

echo
echo "2. Lista de contatos com múltiplos vínculos ativos"
mysql_exec "
SELECT
  ac.contact_id,
  CONCAT(COALESCE(c.first_name,''),' ',COALESCE(c.last_name,'')) AS contato,
  c.account_id AS conta_principal_contact,
  COUNT(*) AS vinculos_ativos
FROM account_contact ac
LEFT JOIN contact c ON c.id = ac.contact_id
WHERE ac.deleted = 0
  AND IFNULL(ac.is_inactive, 0) = 0
GROUP BY ac.contact_id, contato, c.account_id
HAVING COUNT(*) > 1
ORDER BY vinculos_ativos DESC, contato;
"

echo
echo "3. Detalhe dos vínculos ativos duplicados"
mysql_exec "
SELECT
  ac.contact_id,
  CONCAT(COALESCE(c.first_name,''),' ',COALESCE(c.last_name,'')) AS contato,
  c.account_id AS conta_principal_contact,
  ac.id AS account_contact_id,
  ac.account_id AS conta_vinculada,
  a.name AS nome_conta,
  a.website,
  ac.role,
  ac.is_inactive,
  ac.deleted
FROM account_contact ac
LEFT JOIN contact c ON c.id = ac.contact_id
LEFT JOIN account a ON a.id = ac.account_id
WHERE ac.deleted = 0
  AND IFNULL(ac.is_inactive, 0) = 0
  AND ac.contact_id IN (
    SELECT contact_id
    FROM account_contact
    WHERE deleted = 0
      AND IFNULL(is_inactive, 0) = 0
    GROUP BY contact_id
    HAVING COUNT(*) > 1
  )
ORDER BY contato, ac.contact_id, a.name;
"

echo
echo "4. Caso específico Thiago"
mysql_exec "
SELECT
  c.id,
  CONCAT(COALESCE(c.first_name,''),' ',COALESCE(c.last_name,'')) AS contato,
  c.account_id AS conta_principal_contact,
  a.name AS nome_conta_principal,
  c.account_id_anterior,
  c.company_name_atual,
  c.company_linkedin,
  c.status_validacao_empresa,
  c.enriquecida_linkedin
FROM contact c
LEFT JOIN account a ON a.id = c.account_id
WHERE c.id='6a10e2d28d4292835';
"

echo
echo "5. Vínculos do Thiago em account_contact"
mysql_exec "
SELECT
  ac.id,
  ac.account_id,
  a.name,
  a.website,
  ac.contact_id,
  ac.role,
  ac.is_inactive,
  ac.deleted
FROM account_contact ac
LEFT JOIN account a ON a.id = ac.account_id
WHERE ac.contact_id='6a10e2d28d4292835'
ORDER BY ac.id;
"

echo
echo "6. Regra atual no backend que move contato"
grep -n -C 8 "set('accountId'\\|account_contact\\|validarEMoverEmpresaDoContato\\|registrarHistoricoEmpresa" \
/opt/atria/www/custom/Espo/Custom/Controllers/Contact.php \
/opt/atria/www/custom/Espo/Custom/Controllers/Account.php || true

echo
echo "=================================================="
echo "FIM DO DIAGNÓSTICO"
echo "=================================================="
