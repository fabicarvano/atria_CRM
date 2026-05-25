#!/bin/bash
set -e

ENV_FILE="/opt/atria/.env"
TS=$(date +%Y%m%d_%H%M%S)

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
echo "FASE 1 — BANCO | Enriquecimento Contatos"
echo "=================================================="

echo
echo "1. Validando conexão com banco..."
mysql_exec "SELECT DATABASE() AS banco;"
echo "OK: conexão com banco validada"

echo
echo "2. Backup estrutural antes da alteração..."
mysqldump -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" \
  --no-data "$DB_NAME" account contact contato_executivo \
  > "/opt/atria/backup_schema_enriquecimento_${TS}.sql"

echo "OK: backup criado em /opt/atria/backup_schema_enriquecimento_${TS}.sql"

echo
echo "3. Criando campos em account..."
mysql_exec "
ALTER TABLE account
  ADD COLUMN IF NOT EXISTS company_website VARCHAR(255) NULL AFTER website;
"

echo "OK: account.company_website validado/criado"

echo
echo "4. Criando campos em contact..."
mysql_exec "
ALTER TABLE contact
  ADD COLUMN IF NOT EXISTS company_linkedin VARCHAR(512) NULL AFTER linkedin_url,
  ADD COLUMN IF NOT EXISTS company_website VARCHAR(255) NULL AFTER company_linkedin,
  ADD COLUMN IF NOT EXISTS company_name_atual VARCHAR(255) NULL AFTER company_website,
  ADD COLUMN IF NOT EXISTS email_corporativo VARCHAR(255) NULL AFTER company_name_atual,
  ADD COLUMN IF NOT EXISTS fonte_email VARCHAR(100) NULL AFTER email_corporativo,
  ADD COLUMN IF NOT EXISTS data_enriquecimento_email DATETIME NULL AFTER fonte_email,
  ADD COLUMN IF NOT EXISTS account_id_anterior VARCHAR(17) NULL AFTER account_id,
  ADD COLUMN IF NOT EXISTS status_validacao_empresa VARCHAR(100) NULL AFTER account_id_anterior;
"

echo "OK: campos contact validados/criados"

echo
echo "5. Criando campos em contato_executivo..."
mysql_exec "
ALTER TABLE contato_executivo
  ADD COLUMN IF NOT EXISTS company_name VARCHAR(255) NULL AFTER email,
  ADD COLUMN IF NOT EXISTS company_linkedin VARCHAR(512) NULL AFTER company_name,
  ADD COLUMN IF NOT EXISTS company_website VARCHAR(255) NULL AFTER company_linkedin;
"

echo "OK: campos contato_executivo validados/criados"

echo
echo "6. Criando tabela contact_company_history..."
mysql_exec "
CREATE TABLE IF NOT EXISTS contact_company_history (
  id VARCHAR(17) NOT NULL,
  contact_id VARCHAR(17) NULL,
  account_id_anterior VARCHAR(17) NULL,
  account_id_novo VARCHAR(17) NULL,
  empresa_anterior VARCHAR(255) NULL,
  empresa_atual VARCHAR(255) NULL,
  linkedin_empresa_anterior VARCHAR(512) NULL,
  linkedin_empresa_atual VARCHAR(512) NULL,
  company_website VARCHAR(255) NULL,
  cargo VARCHAR(255) NULL,
  email VARCHAR(255) NULL,
  motivo VARCHAR(100) NULL,
  fonte VARCHAR(100) NULL,
  raw_json MEDIUMTEXT NULL,
  created_at DATETIME NULL,
  created_by_id VARCHAR(17) NULL,
  PRIMARY KEY (id),
  KEY IDX_CONTACT_COMPANY_HISTORY_CONTACT (contact_id),
  KEY IDX_CONTACT_COMPANY_HISTORY_ACCOUNT_ANTERIOR (account_id_anterior),
  KEY IDX_CONTACT_COMPANY_HISTORY_ACCOUNT_NOVO (account_id_novo),
  KEY IDX_CONTACT_COMPANY_HISTORY_CREATED_AT (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
"

echo "OK: tabela contact_company_history validada/criada"

echo
echo "7. Validação final dos campos..."
echo "--- account ---"
mysql_exec "SHOW COLUMNS FROM account LIKE 'company_website';"

echo "--- contact ---"
for COL in company_linkedin company_website company_name_atual email_corporativo fonte_email data_enriquecimento_email account_id_anterior status_validacao_empresa; do
  mysql_exec "SHOW COLUMNS FROM contact LIKE '$COL';"
done

echo "--- contato_executivo ---"
for COL in company_name company_linkedin company_website; do
  mysql_exec "SHOW COLUMNS FROM contato_executivo LIKE '$COL';"
done

echo "--- contact_company_history ---"
mysql_exec "SHOW TABLES LIKE 'contact_company_history';"
mysql_exec "SHOW COLUMNS FROM contact_company_history;"

echo
echo "=================================================="
echo "SUCESSO: FASE 1 concluída"
echo "Banco preparado para o novo fluxo de enriquecimento."
echo "=================================================="
