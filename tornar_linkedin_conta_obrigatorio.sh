#!/bin/bash
set -e

BASE="/opt/atria/www"
ENV_FILE="/opt/atria/.env"
ENTITY="$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Account.json"
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
echo "TORNAR LINKEDIN DA CONTA OBRIGATÓRIO"
echo "=================================================="

echo
echo "1. Diagnóstico de contas sem LinkedIn..."
mysql_exec "
SELECT id, name, website
FROM account
WHERE deleted = 0
  AND (website IS NULL OR website = '')
ORDER BY name;
"

echo
echo "2. Backup do metadata..."
cp "$ENTITY" "$ENTITY.bak_required_website_$TS"
echo "OK: backup criado em $ENTITY.bak_required_website_$TS"

echo
echo "3. Contexto antes..."
grep -n -C 5 '"website"' "$ENTITY" || true

echo
echo "4. Aplicando required no campo website..."
python3 <<PY
import json
from pathlib import Path

path = Path("$ENTITY")

with path.open() as f:
    data = json.load(f)

fields = data.setdefault("fields", {})
website = fields.setdefault("website", {
    "type": "url",
    "maxLength": 255
})

website["required"] = True
website["tooltip"] = True

with path.open("w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK: Account.website agora está required=true")
PY

echo
echo "5. Validando JSON..."
python3 -m json.tool "$ENTITY" >/dev/null
echo "OK: JSON válido"

echo
echo "6. Contexto depois..."
grep -n -C 8 '"website"' "$ENTITY"

echo
echo "7. Rebuild..."
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "8. Validação no cache..."
grep -RIn "'website'.*required\\|\"website\".*required\\|website.*required" "$BASE/data/cache/application" | head -20 || true

echo
echo "=================================================="
echo "SUCESSO: LinkedIn da Conta obrigatório no metadata"
echo "Campo usado: Account.website"
echo "=================================================="
