#!/bin/bash
set -e

JS="/opt/atria/www/client/custom/src/views/contact/detail.js"
CTRL="/opt/atria/www/custom/Espo/Custom/Controllers/Contact.php"

TS=$(date +%Y%m%d_%H%M%S)

echo "=== BACKUP ==="
cp "$JS"   "$JS.bak_fix_avatar_$TS"
cp "$CTRL" "$CTRL.bak_fix_apify_$TS"

echo
echo "=== 1. Corrigindo actorId Apify ==="

sed -i \
"s#dev_fusion/linkedin-profile-scraper#dev_fusion~linkedin-profile-scraper#g" \
"$CTRL"

grep -n -C 2 "linkedin-profile-scraper" "$CTRL"

echo
echo "=== 2. Corrigindo _injectAvatar ==="

python3 <<'PY'
from pathlib import Path
import re

p = Path("/opt/atria/www/client/custom/src/views/contact/detail.js")
s = p.read_text()

pattern = r'''
\s*_injectAvatar\(\)\s*\{
.*?
\s*\}
(?=
\s*_control|
\s*_wait|
\s*_action|
\s*\};)
'''

replacement = r'''
        _injectAvatar() {
            try {
                const photoUrl = this.model.get('linkedinPhotoUrl');

                if (!photoUrl) {
                    return;
                }

                const img = document.querySelector('.record[data-scope="Contact"] img.avatar');

                if (!img) {
                    return;
                }

                if (img.dataset.linkedinInjected === '1') {
                    return;
                }

                img.src = photoUrl;
                img.dataset.linkedinInjected = '1';

            } catch (e) {
                console.error('Erro _injectAvatar', e);
            }
        }
'''

s = re.sub(pattern, replacement, s, flags=re.S)

p.write_text(s)

print("OK: _injectAvatar corrigido")
PY

echo
echo "=== 3. Validando ==="

echo
echo "--- Contact.php ---"
grep -n -C 2 "linkedin-profile-scraper" "$CTRL"

echo
echo "--- detail.js ---"
grep -n -C 5 "_injectAvatar" "$JS"

echo
echo "=== 4. Rebuild ==="

cd /opt/atria/www

php command.php clear-cache
php command.php rebuild

echo
echo "=== FINALIZADO ==="
echo "Faça CTRL+SHIFT+R e teste novamente."
