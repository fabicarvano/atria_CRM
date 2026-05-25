#!/bin/bash

BASE="/opt/atria/www"

echo "=================================================="
echo "TESTE FASE 2 — Metadata/Layout"
echo "=================================================="

echo
echo "1. JSON válido"
python3 -m json.tool "$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Account.json" >/dev/null && echo "OK Account entityDefs"
python3 -m json.tool "$BASE/custom/Espo/Custom/Resources/metadata/entityDefs/Contact.json" >/dev/null && echo "OK Contact entityDefs"
python3 -m json.tool "$BASE/custom/Espo/Custom/Resources/layouts/Account/detail.json" >/dev/null && echo "OK Account layout"
python3 -m json.tool "$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json" >/dev/null && echo "OK Contact layout"

echo
echo "2. Campos no cache"
for FIELD in companyWebsite companyLinkedin companyNameAtual emailCorporativo statusValidacaoEmpresa accountIdAnterior fonteEmail dataEnriquecimentoEmail; do
  COUNT=$(grep -R "$FIELD" "$BASE/data/cache/application" 2>/dev/null | wc -l)
  echo "$FIELD => $COUNT ocorrência(s)"
done

echo
echo "3. Campos nos layouts"
echo "--- Account ---"
grep -n "companyWebsite" "$BASE/custom/Espo/Custom/Resources/layouts/Account/detail.json" || echo "ERRO: companyWebsite não está no layout Account"

echo "--- Contact ---"
for FIELD in linkedinUrl companyLinkedin companyWebsite companyNameAtual emailCorporativo statusValidacaoEmpresa accountIdAnterior fonteEmail dataEnriquecimentoEmail; do
  grep -n "$FIELD" "$BASE/custom/Espo/Custom/Resources/layouts/Contact/detail.json" || echo "ERRO: $FIELD não está no layout Contact"
done

echo
echo "4. HTTP metadata carregando"
curl -s http://localhost/api/v1/Metadata \
| grep -o "companyWebsite\|companyLinkedin\|emailCorporativo\|statusValidacaoEmpresa" \
| sort | uniq -c || true

echo
echo "=================================================="
echo "TESTE FINALIZADO"
echo "Agora abra uma Conta e um Contato no navegador com CTRL+SHIFT+R."
echo "=================================================="
