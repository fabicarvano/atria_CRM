#!/bin/bash
set -e

BASE="/opt/atria/www"
TS=$(date +%Y%m%d_%H%M%S)

ACCOUNT_CTRL="$BASE/custom/Espo/Custom/Controllers/Account.php"
CONTACT_CTRL="$BASE/custom/Espo/Custom/Controllers/Contact.php"
PATCH_FILE="$BASE/client/custom/src/views/account/record/panels/contas-similares-patch.js"

echo "=================================================="
echo "FASE 3.2 — Correções pós-diagnóstico"
echo "=================================================="

echo
echo "1. Backup dos arquivos relevantes..."
cp "$ACCOUNT_CTRL" "$ACCOUNT_CTRL.bak_fase3_2_$TS"
cp "$CONTACT_CTRL" "$CONTACT_CTRL.bak_fase3_2_$TS"

if [ -f "$PATCH_FILE" ]; then
  cp "$PATCH_FILE" "$PATCH_FILE.bak_fase3_2_$TS"
fi

echo "OK: backups criados"

echo
echo "2. Desativando patch conflitante de Contas Similares..."
if [ -f "$PATCH_FILE" ]; then
  mv "$PATCH_FILE" "$PATCH_FILE.disabled_$TS"
  echo "OK: patch conflitante desativado: $PATCH_FILE.disabled_$TS"
else
  echo "OK: patch conflitante não existe"
fi

echo
echo "3. Salvando companyWebsite no enriquecimento de Account..."
python3 <<'PY'
from pathlib import Path

p = Path("/opt/atria/www/custom/Espo/Custom/Controllers/Account.php")
s = p.read_text()

if "$websiteUrl" not in s:
    old = """        $description = trim((string) ($item->description ?? ''));
        $logoUrl = trim((string) ($item->logoResolutionResult ?? ''));"""

    new = """        $description = trim((string) ($item->description ?? ''));
        $logoUrl = trim((string) ($item->logoResolutionResult ?? ''));
        $websiteUrl = trim((string) ($item->websiteUrl ?? $item->website ?? $item->companyWebsite ?? ''));"""

    if old not in s:
        raise SystemExit("ERRO: bloco para extrair websiteUrl não encontrado")
    s = s.replace(old, new, 1)

if "set('companyWebsite'" not in s:
    old = """        if ($employeeCount !== null && $employeeCount > 0) {
            $account->set('employeeCountLinkedin', $employeeCount);
        }"""

    new = """        if ($employeeCount !== null && $employeeCount > 0) {
            $account->set('employeeCountLinkedin', $employeeCount);
        }

        if ($websiteUrl !== '') {
            $account->set('companyWebsite', $websiteUrl);
        }"""

    if old not in s:
        raise SystemExit("ERRO: bloco para set companyWebsite não encontrado")
    s = s.replace(old, new, 1)

p.write_text(s)
print("OK: Account.php incrementado para salvar companyWebsite")
PY

echo
echo "4. Validando actor do Contact.php..."
grep -n -C 3 "ACTOR_ID\|api.apify.com\|run-sync-get-dataset-items" "$CONTACT_CTRL"

echo
echo "5. PHP lint..."
php -l "$ACCOUNT_CTRL"
php -l "$CONTACT_CTRL"

echo
echo "6. Rebuild..."
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "7. Validações finais..."
echo "--- patch conflitante ---"
ls -lah "$BASE/client/custom/src/views/account/record/panels/" | grep "contas-similares-patch" || echo "OK: patch conflitante não está mais ativo"

echo
echo "--- painel correto ---"
test -f "$BASE/client/custom/src/views/account/record/panels/contas-similares.js" && echo "OK: contas-similares.js ativo"

echo
echo "--- companyWebsite no Account.php ---"
grep -n -C 3 "websiteUrl\|companyWebsite" "$ACCOUNT_CTRL" | head -60

echo
echo "=================================================="
echo "SUCESSO: FASE 3.2 aplicada"
echo "Agora abra Brisanet com CTRL+SHIFT+R e confira Contas Similares."
echo "=================================================="
