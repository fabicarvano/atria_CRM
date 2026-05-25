#!/bin/bash

BASE="/opt/atria/www"
CONTACT_CTRL="$BASE/custom/Espo/Custom/Controllers/Contact.php"
ACCOUNT_CTRL="$BASE/custom/Espo/Custom/Controllers/Account.php"

echo "=================================================="
echo "DIAGNÓSTICO — FASE 3 BACKEND CONTACT"
echo "=================================================="

echo
echo "1. Validando arquivos..."
for F in "$CONTACT_CTRL" "$ACCOUNT_CTRL"; do
  if [ ! -f "$F" ]; then
    echo "ERRO: arquivo não encontrado: $F"
    exit 1
  fi
  echo "OK: $F"
done

echo
echo "2. PHP LINT"
php -l "$CONTACT_CTRL"
php -l "$ACCOUNT_CTRL"

echo
echo "3. ACTION DE ENRIQUECIMENTO"
grep -n -C 8 "postActionEnriquecerLinkedin" "$CONTACT_CTRL" || true

echo
echo "4. CHAMADAS APIFY"
grep -n -C 5 "callApify\|ACTOR_ID\|run-sync-get-dataset-items\|curl" "$CONTACT_CTRL" || true

echo
echo "5. CAMPOS SALVOS ATUALMENTE"
grep -n -C 4 "set('headline'\|set('cargo'\|set('linkedin'\|set('location'\|set('email'\|set('linkedinPhotoUrl'" "$CONTACT_CTRL" || true

echo
echo "6. NORMALIZAÇÃO LINKEDIN"
grep -n -C 6 "normalizeLinkedinUrl" "$CONTACT_CTRL" "$ACCOUNT_CTRL" || true

echo
echo "7. ENTITY MANAGER / SAVE"
grep -n -C 4 "entityManager\|saveEntity\|getRepository\|getEntityManager" "$CONTACT_CTRL" || true

echo
echo "8. RESPOSTAS FRONTEND"
grep -n -C 4 "message\|success\|json_encode\|return" "$CONTACT_CTRL" || true

echo
echo "9. ACCOUNT.PHP — CRIAÇÃO DE CONTACT"
grep -n -C 6 "postActionCriarContatoExecutivo\|createEntity\|getNewEntity('Contact')" "$ACCOUNT_CTRL" || true

echo
echo "10. CONTEXTO COMPLETO FINAL CONTACT.PHP"
tail -120 "$CONTACT_CTRL"

echo
echo "11. MÉTODOS EXISTENTES"
grep -n "function " "$CONTACT_CTRL"

echo
echo "=================================================="
echo "FIM DIAGNÓSTICO"
echo "=================================================="
