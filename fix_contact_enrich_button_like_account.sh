#!/bin/bash
set -e

JS="/opt/atria/www/client/custom/src/views/contact/detail.js"
TS=$(date +%Y%m%d_%H%M%S)

echo "=== Backup ==="
cp "$JS" "$JS.bak_button_account_style_$TS"

echo
echo "=== Contexto antes ==="
grep -n -C 4 "enriquecerLinkedin\|detailActions\|buttons\|after:render" "$JS" || true

echo
echo "=== Patch incremental ==="
python3 <<'PY'
from pathlib import Path

p = Path("/opt/atria/www/client/custom/src/views/contact/detail.js")
s = p.read_text()

# 1. Volta para o mesmo grupo usado em Account: buttons
s = s.replace("this.addMenuItem('detailActions', {", "this.addMenuItem('buttons', {")

# 2. Garante mesmo nome de método usado em Account
s = s.replace("_controlEnriqButtons", "_controlEnriquecimentoButtons")

# 3. Se ainda não existir fallback DOM, adiciona fallback após render
needle = """            this.listenTo(this, 'after:render', () => {
                this._waitAndInjectAvatar();
            });"""

replacement = """            this.listenTo(this, 'after:render', () => {
                this._waitAndInjectAvatar();
                this._injectEnrichButtonFallback();
            });"""

if needle in s:
    s = s.replace(needle, replacement, 1)

# 4. Adiciona método fallback antes do fechamento da classe
if "_injectEnrichButtonFallback()" not in s:
    marker = "    };\n});"
    method = r'''
        _injectEnrichButtonFallback() {
            if (document.getElementById('contact-enrich-linkedin-fallback')) {
                return;
            }

            const isEnriq = !!this.model.get('enriquecidaLinkedin');

            if (isEnriq) {
                return;
            }

            const headerButtons = document.querySelector('.header-buttons') ||
                document.querySelector('.page-header .btn-group') ||
                document.querySelector('.page-header');

            if (!headerButtons) {
                return;
            }

            const btn = document.createElement('button');
            btn.id = 'contact-enrich-linkedin-fallback';
            btn.type = 'button';
            btn.className = 'btn btn-default';
            btn.style.marginLeft = '6px';
            btn.innerHTML = 'Enriquecer';

            btn.addEventListener('click', () => {
                this._actionEnriquecerLinkedin();
            });

            headerButtons.appendChild(btn);
        }

'''
    s = s.replace(marker, method + marker, 1)

p.write_text(s)
print("OK: patch aplicado")
PY

echo
echo "=== Contexto depois ==="
grep -n -C 4 "enriquecerLinkedin\|_injectEnrichButtonFallback\|_controlEnriquecimentoButtons\|buttons\|after:render" "$JS"

echo
echo "=== Rebuild ==="
cd /opt/atria/www
php command.php clear-cache
php command.php rebuild

echo
echo "=== Pronto ==="
echo "Agora faça CTRL+SHIFT+R ou abra em janela anônima."
