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
echo "FASE 4.1 — Unicidade de Conta Ativa por Contato"
echo "=================================================="

echo
echo "1. Backup..."
cp "$CTRL" "$CTRL.bak_fase4_1_$TS"
mysqldump -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" account_contact contact contact_company_history \
  > "/opt/atria/backup_fase4_1_account_contact_${TS}.sql"
echo "OK: backups criados"

echo
echo "2. Diagnóstico antes..."
mysql_exec "
SELECT
  ac.contact_id,
  CONCAT(COALESCE(c.first_name,''),' ',COALESCE(c.last_name,'')) AS contato,
  c.account_id AS conta_principal,
  COUNT(*) AS vinculos_ativos
FROM account_contact ac
LEFT JOIN contact c ON c.id = ac.contact_id
WHERE ac.deleted = 0
  AND IFNULL(ac.is_inactive,0)=0
GROUP BY ac.contact_id, contato, c.account_id
HAVING COUNT(*) > 1;
"

echo
echo "3. Aplicando patch no Contact.php..."
python3 <<'PY'
from pathlib import Path

p = Path("/opt/atria/www/custom/Espo/Custom/Controllers/Contact.php")
s = p.read_text()

old = """            $contact->set('accountIdAnterior', $accountIdAtual);
            $contact->set('accountId', $novaConta->getId());
            $contact->set('statusValidacaoEmpresa', 'empresa_divergente_corrigida');"""

new = """            $contact->set('accountIdAnterior', $accountIdAtual);
            $contact->set('accountId', $novaConta->getId());
            $contact->set('statusValidacaoEmpresa', 'empresa_divergente_corrigida');

            $this->garantirUnicaContaAtivaDoContato($contact->getId(), $novaConta->getId(), $cargo);"""

if old not in s:
    raise SystemExit("ERRO: bloco de movimentação não encontrado")

s = s.replace(old, new, 1)

marker = """    private function registrarHistoricoEmpresa($contact, $accountAnterior, $accountNovo, string $companyName, string $companyLinkedin, string $companyWebsite, string $cargo, string $email, string $motivo, string $fonte, object $raw): void
    {"""

method = r'''
    private function garantirUnicaContaAtivaDoContato(string $contactId, string $accountIdPrincipal, string $role = ''): void
    {
        try {
            $pdo = $this->getPdo();

            // Desativa todos os vínculos ativos do contato.
            $stmt = $pdo->prepare("
                UPDATE account_contact
                SET is_inactive = 1
                WHERE contact_id = :contactId
                  AND deleted = 0
            ");
            $stmt->execute([
                ':contactId' => $contactId,
            ]);

            // Verifica se já existe vínculo com a conta principal.
            $stmt = $pdo->prepare("
                SELECT id
                FROM account_contact
                WHERE contact_id = :contactId
                  AND account_id = :accountId
                  AND deleted = 0
                LIMIT 1
            ");
            $stmt->execute([
                ':contactId' => $contactId,
                ':accountId' => $accountIdPrincipal,
            ]);

            $row = $stmt->fetch(\PDO::FETCH_ASSOC);

            if ($row) {
                $stmt = $pdo->prepare("
                    UPDATE account_contact
                    SET is_inactive = 0,
                        role = COALESCE(NULLIF(:role, ''), role)
                    WHERE id = :id
                ");
                $stmt->execute([
                    ':id' => $row['id'],
                    ':role' => $role,
                ]);

                return;
            }

            $stmt = $pdo->prepare("
                INSERT INTO account_contact (
                    account_id,
                    contact_id,
                    role,
                    is_inactive,
                    deleted
                ) VALUES (
                    :accountId,
                    :contactId,
                    :role,
                    0,
                    0
                )
            ");
            $stmt->execute([
                ':accountId' => $accountIdPrincipal,
                ':contactId' => $contactId,
                ':role' => $role !== '' ? $role : null,
            ]);
        } catch (\Throwable $e) {
        }
    }

'''

if method.strip() not in s:
    if marker not in s:
        raise SystemExit("ERRO: marker para inserir método não encontrado")
    s = s.replace(marker, method + marker, 1)

p.write_text(s)
print("OK: Contact.php atualizado")
PY

echo
echo "4. Corrigindo caso atual do Thiago..."
CONTACT_ID="6a10e2d28d4292835"

mysql_exec "
UPDATE account_contact
SET is_inactive = 1
WHERE contact_id = '${CONTACT_ID}'
  AND deleted = 0;
"

mysql_exec "
UPDATE account_contact ac
JOIN contact c ON c.account_id = ac.account_id AND c.id = ac.contact_id
SET ac.is_inactive = 0
WHERE ac.contact_id = '${CONTACT_ID}'
  AND ac.deleted = 0;
"

echo "OK: Thiago ficou com apenas a conta principal ativa"

echo
echo "5. Validando PHP..."
php -l "$CTRL"

echo
echo "6. Rebuild..."
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "7. Validação depois — múltiplos vínculos ativos..."
mysql_exec "
SELECT
  ac.contact_id,
  CONCAT(COALESCE(c.first_name,''),' ',COALESCE(c.last_name,'')) AS contato,
  c.account_id AS conta_principal,
  COUNT(*) AS vinculos_ativos
FROM account_contact ac
LEFT JOIN contact c ON c.id = ac.contact_id
WHERE ac.deleted = 0
  AND IFNULL(ac.is_inactive,0)=0
GROUP BY ac.contact_id, contato, c.account_id
HAVING COUNT(*) > 1;
"

echo
echo "8. Vínculos do Thiago..."
mysql_exec "
SELECT
  ac.id,
  ac.account_id,
  a.name,
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
echo "9. Conta principal do Thiago..."
mysql_exec "
SELECT
  c.id,
  CONCAT(COALESCE(c.first_name,''),' ',COALESCE(c.last_name,'')) AS contato,
  c.account_id,
  a.name AS conta_principal,
  c.account_id_anterior,
  c.status_validacao_empresa
FROM contact c
LEFT JOIN account a ON a.id = c.account_id
WHERE c.id='${CONTACT_ID}';
"

echo
echo "=================================================="
echo "SUCESSO: FASE 4.1 concluída"
echo "Regra operacional aplicada: 1 contato = 1 conta ativa."
echo "=================================================="
