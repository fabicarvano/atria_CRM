#!/bin/bash
set -e

JS="/opt/atria/www/client/custom/src/views/contact/detail.js"
TS=$(date +%Y%m%d_%H%M%S)

echo "=== Backup ==="
cp "$JS" "$JS.bak_direct_header_$TS"

echo
echo "=== Contexto antes ==="
grep -n -C 5 "_injectEnrichButtonFallback\|after:render\|super.setup" "$JS" || true

python3 <<'PY'
from pathlib import Path

p = Path("/opt/atria/www/client/custom/src/views/contact/detail.js")
s = p.read_text()

# 1. Garante chamada direta no setup, logo após super.setup()
needle = "            super.setup();"
insert = """            super.setup();

            setTimeout(() => {
                this._injectEnrichButtonFallback();
            }, 800);
"""

if insert not in s:
    s = s.replace(needle, insert, 1)

# 2. Substitui método fallback por um que usa exatamente o DOM enviado
start = s.find("        _injectEnrichButtonFallback() {")
if start != -1:
    end = s.find("\n        _controlEnriquecimentoButtons", start)
    if end == -1:
        end = s.find("\n        _controlEnriqButtons", start)
    if end == -1:
        end = s.find("\n    };\n});", start)
    s = s[:start] + s[end:]

method = r'''
        _injectEnrichButtonFallback() {
            const existing = document.getElementById('contact-enrich-linkedin-fallback');

            if (existing) {
                existing.remove();
            }

            const isEnriq = !!this.model.get('enriquecidaLinkedin');

            const headerButtons = document.querySelector('.header-buttons.btn-group.pull-right');

            if (!headerButtons) {
                setTimeout(() => this._injectEnrichButtonFallback(), 500);
                return;
            }

            const btn = document.createElement('a');
            btn.id = 'contact-enrich-linkedin-fallback';
            btn.setAttribute('role', 'button');
            btn.setAttribute('tabindex', '0');
            btn.className = 'btn btn-default btn-xs-wide main-header-manu-action action';
            btn.setAttribute('data-name', isEnriq ? 'enriquecidaLinkedinFallback' : 'enriquecerLinkedinFallback');
            btn.setAttribute('data-action', '');

            if (isEnriq) {
                btn.className += ' disabled';
                btn.innerHTML = '<span style="color:#64748b;font-weight:500">Enriquecido</span>';
            } else {
                btn.innerHTML = '<span style="font-weight:500">Enriquecer</span>';
                btn.addEventListener('click', (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    this._actionEnriquecerLinkedin();
                });
            }

            headerButtons.appendChild(btn);
        }

'''

marker = "\n        _control"
idx = s.find(marker)
if idx != -1:
    s = s[:idx] + method + s[idx:]
else:
    s = s.replace("\n    };\n});", method + "\n    };\n});")

p.write_text(s)
print("OK: fallback direto no header aplicado")
PY

echo
echo "=== Contexto depois ==="
grep -n -C 8 "_injectEnrichButtonFallback\|setTimeout\|header-buttons" "$JS"

echo
echo "=== Rebuild ==="
cd /opt/atria/www
php command.php clear-cache
php command.php rebuild

echo
echo "=== Ver JS servido ==="
curl -s http://localhost/client/custom/src/views/contact/detail.js \
| grep -n -C 5 "_injectEnrichButtonFallback\|contact-enrich-linkedin-fallback\|header-buttons" || true

echo
echo "=== Pronto ==="
echo "Abra em janela anônima nova ou CTRL+SHIFT+R."
