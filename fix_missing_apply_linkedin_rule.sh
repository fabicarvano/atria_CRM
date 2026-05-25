#!/bin/bash
set -e

JS="/opt/atria/www/client/custom/src/views/contact/detail.js"
TS=$(date +%Y%m%d_%H%M%S)

echo "=== BACKUP ==="
cp "$JS" "$JS.bak_restore_apply_rule_$TS"

echo
echo "=== CONTEXTO ANTES ==="
grep -n -C 3 "_applyLinkedinEditRule" "$JS" || true

python3 <<'PY'
from pathlib import Path

p = Path("/opt/atria/www/client/custom/src/views/contact/detail.js")
s = p.read_text()

if "_applyLinkedinEditRule() {" in s:
    print("Método já existe, nada feito.")
    raise SystemExit(0)

method = r'''

        _applyLinkedinEditRule() {
            try {
                const isEnriq = !!this.model.get('enriquecidaLinkedin');

                const field =
                    document.querySelector('.cell[data-name="linkedinUrl"] input') ||
                    document.querySelector('[data-name="linkedinUrl"] input');

                if (!field) {
                    return;
                }

                if (isEnriq) {
                    field.setAttribute('readonly', 'readonly');
                    field.setAttribute('disabled', 'disabled');
                    field.style.backgroundColor = '#f5f5f5';
                    field.style.cursor = 'not-allowed';
                } else {
                    field.removeAttribute('readonly');
                    field.removeAttribute('disabled');
                    field.style.backgroundColor = '';
                    field.style.cursor = '';
                }

            } catch (e) {
                console.error('Erro _applyLinkedinEditRule', e);
            }
        }

'''

marker = "\n        _controlEnriquecimentoButtons()"

if marker not in s:
    raise SystemExit("ERRO: marker _controlEnriquecimentoButtons não encontrado")

s = s.replace(marker, method + marker, 1)

p.write_text(s)

print("OK: método restaurado")
PY

echo
echo "=== CONTEXTO DEPOIS ==="
grep -n -C 8 "_applyLinkedinEditRule" "$JS"

echo
echo "=== REBUILD ==="
cd /opt/atria/www

php command.php clear-cache
php command.php rebuild

echo
echo "=== FINALIZADO ==="
echo "Agora faça CTRL+SHIFT+R."
