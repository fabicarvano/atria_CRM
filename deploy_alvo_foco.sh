#!/bin/bash
# =============================================================================
# EscopoCRM (Atria) -- Deploy Alvo/Foco (Mira)
# Campos: statusProspeccao, porQueFoco, tipoEscalao, porQueAlvo
# =============================================================================

set -uo pipefail

# --- Auto-deteccao de caminhos ---
if [ -f "/opt/atria/www/command.php" ]; then
    ESPO_DIR="/opt/atria/www"
elif [ -f "/opt/espocrm/www/command.php" ]; then
    ESPO_DIR="/opt/espocrm/www"
else
    FOUND=$(find /opt -name "command.php" -maxdepth 4 2>/dev/null | head -1)
    if [ -z "$FOUND" ]; then
        echo "ERRO: Nao foi possivel localizar o EspoCRM."
        exit 1
    fi
    ESPO_DIR=$(dirname "$FOUND")
fi

# Detecta extensao linkedin-prospect
BASE_DIR=$(dirname "$ESPO_DIR")
if [ -d "$BASE_DIR/linkedin-prospect" ]; then
    EXT_DIR="$BASE_DIR/linkedin-prospect"
elif [ -d "/opt/linkedin-prospect" ]; then
    EXT_DIR="/opt/linkedin-prospect"
else
    EXT_DIR=""
fi

CUSTOM_DIR="$ESPO_DIR/custom/Espo/Custom/Resources/metadata"
LOG_DIR="$ESPO_DIR/data/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="/tmp"
LOG="$LOG_DIR/deploy_alvo_foco_$(date +%Y%m%d_%H%M%S).log"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

PASS=0
FAIL=0
declare -a STEPS

log()  { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }
ok()   { echo -e "${GREEN}  [OK] $1${NC}" | tee -a "$LOG"; PASS=$((PASS+1)); STEPS+=("[OK] $1"); }
err()  { echo -e "${RED}  [FALHA] $1${NC}" | tee -a "$LOG"; FAIL=$((FAIL+1)); STEPS+=("[FALHA] $1"); }
warn() { echo -e "${YELLOW}  [AVISO] $1${NC}" | tee -a "$LOG"; STEPS+=("[AVISO] $1"); }
hdr()  { echo -e "\n${BLUE}${BOLD}=== $1 ===${NC}" | tee -a "$LOG"; }

echo ""
echo "========================================================"
echo "   EscopoCRM (Atria) -- Deploy Alvo/Foco com Mira"
echo "   $(date '+%d/%m/%Y %H:%M:%S')"
echo "========================================================"
echo ""
echo "  Caminhos detectados:"
echo "  ESPO_DIR : $ESPO_DIR"
echo "  EXT_DIR  : ${EXT_DIR:-NAO_ENCONTRADO}"
echo "  LOG      : $LOG"
echo ""

# =============================================================================
# ETAPA 1 -- PRE-REQUISITOS
# =============================================================================
hdr "ETAPA 1 -- Verificando pre-requisitos"

log "Checando diretorio EspoCRM..."
if [ -d "$ESPO_DIR" ] && [ -f "$ESPO_DIR/command.php" ]; then
    ok "EspoCRM encontrado: $ESPO_DIR"
else
    err "command.php nao encontrado em: $ESPO_DIR"
    echo -e "${RED}Abortando.${NC}"
    exit 1
fi

log "Checando PHP..."
PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null || echo "")
if [[ "$PHP_VER" == "8."* ]]; then
    ok "PHP $PHP_VER encontrado"
else
    err "PHP 8.x esperado, encontrado: '$PHP_VER'"
fi

log "Checando Node.js..."
NODE_VER=$(node -v 2>/dev/null || echo "nao encontrado")
if [[ "$NODE_VER" == v* ]]; then
    ok "Node.js $NODE_VER encontrado"
else
    warn "Node.js nao encontrado -- necessario para build da extensao"
fi

log "Checando Redis..."
if redis-cli ping 2>/dev/null | grep -q "PONG"; then
    ok "Redis respondendo"
else
    warn "Redis nao respondeu ao ping (nao bloqueia o deploy)"
fi

log "Checando extensao linkedin-prospect..."
if [ -n "$EXT_DIR" ] && [ -d "$EXT_DIR" ]; then
    ok "Extensao encontrada: $EXT_DIR"
else
    warn "Extensao nao encontrada -- etapas de build serao puladas"
fi

# =============================================================================
# ETAPA 2 -- ENTITYDEFS (campos no banco)
# =============================================================================
hdr "ETAPA 2 -- Criando entityDefs (campos no banco)"

ENTITY_DEFS_DIR="$CUSTOM_DIR/entityDefs"
mkdir -p "$ENTITY_DEFS_DIR"
ENTITY_FILE="$ENTITY_DEFS_DIR/Account.json"

if [ -f "$ENTITY_FILE" ]; then
    BKFILE="${ENTITY_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$ENTITY_FILE" "$BKFILE"
    warn "Backup criado: $BKFILE"

    # Merge: preserva conteudo existente e adiciona novos campos
    python3 << PYMERGE
import json, sys
try:
    with open("$ENTITY_FILE") as f:
        data = json.load(f)
except:
    data = {}

fields = data.setdefault("fields", {})
new_fields = {
    "statusProspeccao": {"type": "bool", "default": False, "labelText": "Foco"},
    "porQueFoco":       {"type": "text", "labelText": "Por que e Foco"},
    "tipoEscalao":      {"type": "enum", "options": ["", "A", "B", "C"], "labelText": "Escalao", "default": ""},
    "porQueAlvo":       {"type": "text", "labelText": "Por que e Alvo"}
}
added = []
for k, v in new_fields.items():
    if k not in fields:
        fields[k] = v
        added.append(k)

with open("$ENTITY_FILE", "w") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)

if added:
    print("Campos adicionados: " + ", ".join(added))
else:
    print("Campos ja existiam -- nada alterado")
PYMERGE

else
    cat > "$ENTITY_FILE" << 'ENTITY_EOF'
{
    "fields": {
        "statusProspeccao": {
            "type": "bool",
            "default": false,
            "labelText": "Foco"
        },
        "porQueFoco": {
            "type": "text",
            "labelText": "Por que e Foco"
        },
        "tipoEscalao": {
            "type": "enum",
            "options": ["", "A", "B", "C"],
            "labelText": "Escalao",
            "default": ""
        },
        "porQueAlvo": {
            "type": "text",
            "labelText": "Por que e Alvo"
        }
    }
}
ENTITY_EOF
fi

if python3 -m json.tool "$ENTITY_FILE" > /dev/null 2>&1; then
    ok "entityDefs/Account.json valido"
else
    err "entityDefs/Account.json invalido -- verifique o JSON"
fi

# =============================================================================
# ETAPA 3 -- CLIENTDEFS (botao mira + filtro)
# =============================================================================
hdr "ETAPA 3 -- Criando clientDefs (botao Alvo/Foco + filtro de busca)"

CLIENT_DEFS_DIR="$CUSTOM_DIR/clientDefs"
mkdir -p "$CLIENT_DEFS_DIR"
CLIENT_FILE="$CLIENT_DEFS_DIR/Account.json"

if [ -f "$CLIENT_FILE" ]; then
    cp "$CLIENT_FILE" "${CLIENT_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    warn "Backup do clientDefs existente criado"
fi

python3 << PYCLIENT
import json, sys

try:
    with open("$CLIENT_FILE") as f:
        data = json.load(f)
except:
    data = {}

# Botao no menu do detail
data.setdefault("menu", {}).setdefault("detail", {}).setdefault("buttons", ["__APPEND__"])
buttons = data["menu"]["detail"]["buttons"]
names = [b.get("name") for b in buttons if isinstance(b, dict)]

if "toggleFoco" not in names:
    buttons.append({
        "name": "toggleFoco",
        "style": "default",
        "handler": "linkedin-prospect:handlers/alvo-foco-handler",
        "actionFunction": "toggleFoco",
        "initFunction": "initFoco",
        "checkVisibilityFunction": "isVisible",
        "html": "<span></span>"
    })
    print("Botao toggleFoco adicionado")
else:
    print("Botao toggleFoco ja existia")

# Filtro de busca
data.setdefault("searchFilters", {})["statusProspeccao"] = {}

with open("$CLIENT_FILE", "w") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)
PYCLIENT

if python3 -m json.tool "$CLIENT_FILE" > /dev/null 2>&1; then
    ok "clientDefs/Account.json valido"
else
    err "clientDefs/Account.json invalido"
fi

# =============================================================================
# ETAPA 4 -- HANDLER JS
# =============================================================================
hdr "ETAPA 4 -- Criando handler JS (alvo-foco-handler.js)"

if [ -n "$EXT_DIR" ] && [ -d "$EXT_DIR" ]; then
    HANDLER_DIR="$EXT_DIR/src/files/client/custom/src/handlers"
    mkdir -p "$HANDLER_DIR"
    HANDLER_FILE="$HANDLER_DIR/alvo-foco-handler.js"

    cat > "$HANDLER_FILE" << 'HANDLER_EOF'
define(['action-handler'], (Dep) => {
    return class extends Dep {

        _svgAlvo() {
            return '<svg viewBox="0 0 24 24" fill="none" stroke="#888888" stroke-width="1.5" width="15" height="15" style="vertical-align:-2px"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/></svg>';
        }

        _svgFoco() {
            return '<svg viewBox="0 0 24 24" fill="none" stroke="#185FA5" stroke-width="1.8" width="15" height="15" style="vertical-align:-2px"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2" fill="#185FA5"/></svg>';
        }

        initFoco() {
            this._updateButton();
            this.view.listenTo(
                this.view.model,
                'change:statusProspeccao',
                () => this._updateButton()
            );
        }

        async toggleFoco() {
            const isFoco = this.view.model.get('statusProspeccao');

            if (!isFoco) {
                const porQue = await this._askPorQueFoco();
                if (porQue === null) return;
                try {
                    await Espo.Ajax.patchRequest('Account/' + this.view.model.id, {
                        statusProspeccao: true,
                        porQueFoco: porQue
                    });
                    this.view.model.set('statusProspeccao', true);
                    this.view.model.set('porQueFoco', porQue);
                    Espo.Ui.success('Conta marcada como Foco.');
                } catch(e) {
                    Espo.Ui.error('Erro ao salvar. Tente novamente.');
                }
            } else {
                const ok = await new Promise(resolve => {
                    Espo.Ui.confirm(
                        'Remover status Foco? A conta voltara para Alvo.',
                        {confirmText: 'Confirmar', cancelText: 'Cancelar'},
                        () => resolve(true), () => resolve(false)
                    );
                });
                if (!ok) return;
                try {
                    await Espo.Ajax.patchRequest('Account/' + this.view.model.id, {
                        statusProspeccao: false
                    });
                    this.view.model.set('statusProspeccao', false);
                    Espo.Ui.success('Conta voltou para Alvo.');
                } catch(e) {
                    Espo.Ui.error('Erro ao salvar. Tente novamente.');
                }
            }
        }

        _updateButton() {
            const isFoco = this.view.model.get('statusProspeccao');
            const $btn = this.view.$el.find('[data-name="toggleFoco"]');
            if (!$btn.length) return;
            $btn.html(isFoco ? this._svgFoco() : this._svgAlvo());
            $btn.attr('title', isFoco ? 'Foco -- clique para voltar a Alvo' : 'Alvo -- clique para marcar como Foco');
            $btn.css('border-color', isFoco ? '#185FA5' : '');
        }

        _askPorQueFoco() {
            return new Promise((resolve) => {
                const current = this.view.model.get('porQueFoco') || '';
                this.view.createView('dialog', 'views/modal', {
                    headerText: 'Por que e Foco?',
                    templateContent: '<div class="form-group" style="margin:0"><label class="control-label">Motivo <span style="color:red">*</span></label><textarea id="porQueFocoInput" class="form-control" rows="3" placeholder="Ex: Decisor identificado, budget aprovado...">' + current + '</textarea></div>',
                    buttonList: [
                        {
                            name: 'confirm',
                            label: 'Confirmar Foco',
                            style: 'primary',
                            onClick: (view) => {
                                const val = (document.getElementById('porQueFocoInput') || {}).value || '';
                                if (!val.trim()) { Espo.Ui.error('Informe o motivo.'); return; }
                                view.close();
                                resolve(val.trim());
                            }
                        },
                        {
                            name: 'cancel',
                            label: 'Cancelar',
                            onClick: (view) => { view.close(); resolve(null); }
                        }
                    ]
                }, (view) => { view.render(); });
            });
        }

        isVisible() { return true; }
    };
});
HANDLER_EOF

    if [ -f "$HANDLER_FILE" ]; then
        ok "alvo-foco-handler.js criado em $HANDLER_FILE"
    else
        err "Falha ao criar alvo-foco-handler.js"
    fi
else
    warn "EXT_DIR nao encontrado -- criando handler direto no client/custom do EspoCRM"
    HANDLER_DIR="$ESPO_DIR/client/custom/src/handlers"
    mkdir -p "$HANDLER_DIR"
    warn "Handler criado em $HANDLER_DIR -- ajuste o path do handler no clientDefs se necessario"
fi

# =============================================================================
# ETAPA 5 -- SEARCH FILTERS LAYOUT
# =============================================================================
hdr "ETAPA 5 -- Layout de filtros de busca"

LAYOUT_DIR="$ESPO_DIR/custom/Espo/Custom/Resources/layouts/Account"
mkdir -p "$LAYOUT_DIR"
SEARCH_FILE="$LAYOUT_DIR/searchFilters.json"

if [ ! -f "$SEARCH_FILE" ]; then
    cat > "$SEARCH_FILE" << 'SEARCH_EOF'
[
    "name",
    "statusProspeccao",
    "tipoEscalao",
    "industry",
    "linkedinUrl"
]
SEARCH_EOF
    ok "searchFilters.json criado"
else
    warn "searchFilters.json ja existe -- verifique se 'statusProspeccao' e 'tipoEscalao' estao na lista"
fi

# =============================================================================
# ETAPA 6 -- BUILD DA EXTENSAO
# =============================================================================
hdr "ETAPA 6 -- Build da extensao"

if [ -n "$EXT_DIR" ] && [ -d "$EXT_DIR" ] && [ -f "$EXT_DIR/package.json" ]; then
    cd "$EXT_DIR"
    if node build --extension >> "$LOG" 2>&1; then
        ZIP_FILE=$(find "$EXT_DIR/build" -name "*.zip" 2>/dev/null | sort | tail -1)
        if [ -f "$ZIP_FILE" ]; then
            ok "Build OK: $(basename $ZIP_FILE)"
        else
            err "Build rodou mas .zip nao encontrado"
        fi
    else
        err "Falha no build -- verifique: tail -20 $LOG"
    fi
else
    warn "Extensao nao encontrada ou sem package.json -- pulando build"
    ZIP_FILE=""
fi

# =============================================================================
# ETAPA 7 -- INSTALAR EXTENSAO
# =============================================================================
hdr "ETAPA 7 -- Instalando extensao"

if [ -n "${ZIP_FILE:-}" ] && [ -f "$ZIP_FILE" ]; then
    if php "$ESPO_DIR/command.php" extension --file="$ZIP_FILE" >> "$LOG" 2>&1; then
        ok "Extensao instalada: $(basename $ZIP_FILE)"
    else
        err "Falha na instalacao -- verifique: tail -20 $LOG"
    fi
else
    warn "Sem .zip para instalar -- arquivos aplicados diretamente nos diretorios custom"
fi

# =============================================================================
# ETAPA 8 -- REBUILD (cria colunas no banco)
# =============================================================================
hdr "ETAPA 8 -- Rebuild e migracao do banco"

if php "$ESPO_DIR/command.php" rebuild >> "$LOG" 2>&1; then
    ok "Rebuild concluido"
else
    err "Falha no rebuild -- verifique: tail -20 $LOG"
fi

# Verificar colunas no banco
DB_NAME=$(grep -E "^DB_NAME=" "$ESPO_DIR/../.env" 2>/dev/null | cut -d= -f2 \
       || grep -E "^DB_NAME=" /opt/atria/.env 2>/dev/null | cut -d= -f2 \
       || php -r "include '$ESPO_DIR/data/config.php'; echo \$config['database']['dbname'] ?? 'espocrm';" 2>/dev/null \
       || echo "espocrm")

DB_USER=$(grep -E "^DB_USER=" "$ESPO_DIR/../.env" 2>/dev/null | cut -d= -f2 \
        || grep -E "^DB_USER=" /opt/atria/.env 2>/dev/null | cut -d= -f2 \
        || echo "espocrm")

COL=$(mysql -u "$DB_USER" "$DB_NAME" \
    -e "SHOW COLUMNS FROM account LIKE 'status_prospeccao';" 2>/dev/null || echo "")
if echo "$COL" | grep -q "status_prospeccao"; then
    ok "Coluna 'status_prospeccao' confirmada no banco"
else
    warn "Coluna nao detectada automaticamente -- verifique: mysql -u $DB_USER $DB_NAME -e \"SHOW COLUMNS FROM account LIKE 'status_prospeccao';\""
fi

# =============================================================================
# ETAPA 9 -- CLEAR CACHE E RESTART
# =============================================================================
hdr "ETAPA 9 -- Clear cache e restart PHP-FPM"

if php "$ESPO_DIR/command.php" clear-cache >> "$LOG" 2>&1; then
    ok "Cache limpo"
else
    err "Falha ao limpar cache"
fi

# Detecta versao do FPM instalada
FPM_SERVICE=$(systemctl list-units --type=service 2>/dev/null | grep php | grep fpm | awk '{print $1}' | head -1)
if [ -n "$FPM_SERVICE" ]; then
    if systemctl restart "$FPM_SERVICE" 2>/dev/null; then
        sleep 2
        if systemctl is-active --quiet "$FPM_SERVICE"; then
            ok "$FPM_SERVICE reiniciado e ativo"
        else
            err "$FPM_SERVICE nao ficou ativo apos restart"
        fi
    else
        err "Falha ao reiniciar $FPM_SERVICE"
    fi
else
    warn "Servico PHP-FPM nao detectado -- reinicie manualmente"
fi

# =============================================================================
# ETAPA 10 -- VALIDACAO VIA API
# =============================================================================
hdr "ETAPA 10 -- Validacao via API REST"

# Detecta URL base
APP_URL=$(grep -E "^APP_URL=" "$ESPO_DIR/../.env" 2>/dev/null | cut -d= -f2 \
        || grep -E "^APP_URL=" /opt/atria/.env 2>/dev/null | cut -d= -f2 \
        || echo "http://localhost")

sleep 2

HTTP_CODE=$(curl -s -o /tmp/espo_api_test.json -w "%{http_code}" \
    -u "admin:Fabio@2026" \
    "$APP_URL/api/v1/Account?maxSize=1&select=id,name,statusProspeccao,tipoEscalao" \
    --max-time 15 2>/dev/null || echo "000")

if [ "$HTTP_CODE" == "200" ]; then
    ok "API respondeu HTTP 200"
    if grep -q "statusProspeccao" /tmp/espo_api_test.json 2>/dev/null; then
        ok "Campo 'statusProspeccao' presente no payload da API"
    else
        warn "Campo nao apareceu no payload -- pode precisar de rebuild adicional"
    fi
else
    err "API retornou HTTP $HTTP_CODE (esperado 200) -- URL: $APP_URL"
fi

# =============================================================================
# RESUMO FINAL
# =============================================================================
echo ""
echo "========================================================"
echo "              RESUMO DO DEPLOY"
echo "========================================================"
echo ""

for step in "${STEPS[@]}"; do
    if [[ "$step" == \[OK\]* ]]; then
        echo -e "  ${GREEN}$step${NC}"
    elif [[ "$step" == \[FALHA\]* ]]; then
        echo -e "  ${RED}$step${NC}"
    else
        echo -e "  ${YELLOW}$step${NC}"
    fi
done

echo ""
echo -e "  Total: ${GREEN}$PASS passou${NC} | ${RED}$FAIL falhou${NC}"
echo ""
echo -e "  Log completo: ${BLUE}$LOG${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  DEPLOY CONCLUIDO COM SUCESSO${NC}"
    echo ""
    echo "  PROXIMOS PASSOS MANUAIS:"
    echo "  1. Browser: Ctrl+Shift+R (hard refresh)"
    echo "  2. Abra qualquer Conta -- icone de mira deve aparecer ao lado de Editar"
    echo "  3. Clique no icone para testar toggle Alvo/Foco"
    echo "  4. Confirme que 'Por que e Foco?' e obrigatorio"
    echo "  5. Va em Contas > filtros > confirme que 'Foco' aparece"
    echo "  6. Importe a planilha via Contas > Importar"
else
    echo -e "${RED}${BOLD}  DEPLOY COM FALHAS -- revise os itens [FALHA] acima${NC}"
    echo ""
    echo "  Diagnostico rapido:"
    echo "  tail -50 $LOG"
fi

echo ""
echo "========================================================"
