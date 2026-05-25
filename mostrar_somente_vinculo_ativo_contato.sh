#!/bin/bash
set -e

BASE="/opt/atria/www"
ENV_FILE="/opt/atria/.env"
CTRL="$BASE/custom/Espo/Custom/Controllers/Contact.php"
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
echo "MOSTRAR SOMENTE VÍNCULO ATIVO DO CONTATO"
echo "=================================================="

echo
echo "1. Backup..."
cp "$CTRL" "$CTRL.bak_soft_delete_account_contact_$TS"
mysqldump -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" account_contact \
  > "/opt/atria/backup_account_contact_${TS}.sql"
echo "OK: backup criado"

echo
echo "2. Antes — vínculos do Thiago..."
mysql_exec "
SELECT ac.id, ac.account_id, a.name, ac.contact_id, ac.role, ac.is_inactive, ac.deleted
FROM account_contact ac
LEFT JOIN account a ON a.id = ac.account_id
WHERE ac.contact_id='6a10e2d28d4292835'
ORDER BY ac.id;
"

echo
echo "3. Ajustando backend para ocultar vínculos antigos..."
python3 <<'PY'
from pathlib import Path

p = Path("/opt/atria/www/custom/Espo/Custom/Controllers/Contact.php")
s = p.read_text()

s = s.replace(
"""                UPDATE account_contact
                SET is_inactive = 1
                WHERE contact_id = :contactId
                  AND deleted = 0""",
"""                UPDATE account_contact
                SET is_inactive = 1,
                    deleted = 1
                WHERE contact_id = :contactId"""
)

s = s.replace(
"""                    UPDATE account_contact
                    SET is_inactive = 0,
                        role = COALESCE(NULLIF(:role, ''), role)
                    WHERE id = :id""",
"""                    UPDATE account_contact
                    SET is_inactive = 0,
                        deleted = 0,
                        role = COALESCE(NULLIF(:role, ''), role)
                    WHERE id = :id"""
)

p.write_text(s)
print("OK: Contact.php ajustado para soft delete dos vínculos antigos")
PY

echo
echo "4. Corrigindo caso atual do Thiago..."
mysql_exec "
UPDATE account_contact
SET is_inactive = 1,
    deleted = 1
WHERE contact_id = '6a10e2d28d4292835';
"

mysql_exec "
UPDATE account_contact ac
JOIN contact c ON c.account_id = ac.account_id AND c.id = ac.contact_id
SET ac.is_inactive = 0,
    ac.deleted = 0
WHERE ac.contact_id = '6a10e2d28d4292835';
"

echo
echo "5. Validando PHP..."
php -l "$CTRL"

echo
echo "6. Rebuild..."
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "7. Depois — vínculos do Thiago..."
mysql_exec "
SELECT ac.id, ac.account_id, a.name, ac.contact_id, ac.role, ac.is_inactive, ac.deleted
FROM account_contact ac
LEFT JOIN account a ON a.id = ac.account_id
WHERE ac.contact_id='6a10e2d28d4292835'
ORDER BY ac.id;
"

echo
echo "8. Verificando vínculos ativos visíveis..."
mysql_exec "
SELECT ac.id, ac.account_id, a.name, ac.contact_id, ac.role, ac.is_inactive, ac.deleted
FROM account_contact ac
LEFT JOIN account a ON a.id = ac.account_id
WHERE ac.contact_id='6a10e2d28d4292835'
  AND ac.deleted = 0
ORDER BY ac.id;
"

echo
echo "=================================================="
echo "SUCESSO: agora a tela deve mostrar somente o vínculo ativo"
echo "Faça CTRL+SHIFT+R no contato."
echo "=================================================="
