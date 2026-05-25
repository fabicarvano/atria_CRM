#!/bin/bash

JS="/opt/atria/www/client/custom/src/views/contact/detail.js"

echo "=================================================="
echo "DIAGNÓSTICO detail.js — MÉTODOS E ESTRUTURA"
echo "=================================================="

echo
echo "1. Arquivo existe?"
echo "--------------------------------------------------"
ls -lah "$JS"

echo
echo "2. Métodos encontrados"
echo "--------------------------------------------------"
grep -n "^[[:space:]]*[_a-zA-Z0-9].*() {" "$JS" || true

echo
echo "3. Procurando applyLinkedinEditRule"
echo "--------------------------------------------------"
grep -n -C 6 "_applyLinkedinEditRule" "$JS" || echo "NÃO EXISTE"

echo
echo "4. Procurando injectAvatar"
echo "--------------------------------------------------"
grep -n -C 6 "_injectAvatar" "$JS" || echo "NÃO EXISTE"

echo
echo "5. Procurando action enrich"
echo "--------------------------------------------------"
grep -n -C 6 "_actionEnriquecerLinkedin" "$JS" || echo "NÃO EXISTE"

echo
echo "6. Início do arquivo"
echo "--------------------------------------------------"
sed -n '1,140p' "$JS"

echo
echo "7. Final do arquivo"
echo "--------------------------------------------------"
tail -140 "$JS"

echo
echo "8. Verificando estrutura JS"
echo "--------------------------------------------------"
python3 <<'PY'
from pathlib import Path

p = Path("/opt/atria/www/client/custom/src/views/contact/detail.js")
s = p.read_text()

print("define(", s.count("define("))
print("return class", s.count("return class"))
print("setup()", s.count("setup()"))
print("_applyLinkedinEditRule()", s.count("_applyLinkedinEditRule()"))
print("_injectAvatar()", s.count("_injectAvatar()"))
print("_actionEnriquecerLinkedin()", s.count("_actionEnriquecerLinkedin()"))
print("};", s.count("};"))
print("});", s.count("});"))

if "_applyLinkedinEditRule()" in s:
    idx = s.index("_applyLinkedinEditRule()")
    print("\nContexto método:\n")
    print(s[max(0, idx-300):idx+700])
PY

echo
echo "=================================================="
echo "FIM"
echo "=================================================="
