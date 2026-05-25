#!/bin/bash
set -e

JS="/opt/atria/www/client/custom/src/views/contact/detail.js"
TS=$(date +%Y%m%d_%H%M%S)

echo "=== Backup ==="
cp "$JS" "$JS.bak_remove_fallback_$TS"

echo
echo "=== Contexto antes ==="
grep -n -C 5 "contact-enrich-linkedin-fallback\|_injectEnrichButtonFallback\|setTimeout" "$JS" || true

python3 <<'PY'
from pathlib import Path
import re

p = Path("/opt/atria/www/client/custom/src/views/contact/detail.js")
s = p.read_text()

# Remove chamada direta no setup()
s = re.sub(
    r"\n\s*setTimeout\(\(\) => \{\s*this\._injectEnrichButtonFallback\(\);\s*\},\s*800\);\n",
    "\n",
    s,
    flags=re.S
)

# Remove chamada no after:render, se existir
s = s.replace("                this._injectEnrichButtonFallback();\n", "")

# Remove método fallback inteiro
s = re.sub(
    r"\n\s*_injectEnrichButtonFallback\(\)\s*\{.*?\n\s*\}\n(?=\s*_(control|action|wait|inject)|\s*\};)",
    "\n",
    s,
    flags=re.S
)

p.write_text(s)
print("OK: fallback removido")
PY

echo
echo "=== Contexto depois ==="
grep -n -C 5 "contact-enrich-linkedin-fallback\|_injectEnrichButtonFallback\|setTimeout" "$JS" || echo "OK: fallback não encontrado"

echo
echo "=== Garantindo botão nativo ==="
grep -n -C 4 "name: 'enriquecerLinkedin'\|name: 'enriquecidaLinkedin'" "$JS"

echo
echo "=== Rebuild ==="
cd /opt/atria/www
php command.php clear-cache
php command.php rebuild

echo
echo "=== Pronto ==="
echo "Faça CTRL+SHIFT+R."
