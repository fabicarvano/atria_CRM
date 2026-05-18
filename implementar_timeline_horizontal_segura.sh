#!/bin/bash

set -e

APP_DIR="/opt/atria/www"
BACKUP_DIR="/opt/atria/backups/timeline_horizontal_segura_$(date +%Y%m%d_%H%M%S)"

CLIENT_DEF="$APP_DIR/custom/Espo/Custom/Resources/metadata/clientDefs/Opportunity.json"
VIEW_DIR="$APP_DIR/client/custom/src/views/opportunity/record"
VIEW_FILE="$VIEW_DIR/detail-timeline.js"

echo "======================================"
echo "1. Backup"
echo "======================================"

mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$CLIENT_DEF")"
mkdir -p "$VIEW_DIR"

[ -f "$CLIENT_DEF" ] && cp "$CLIENT_DEF" "$BACKUP_DIR/Opportunity.json"
[ -f "$VIEW_FILE" ] && cp "$VIEW_FILE" "$BACKUP_DIR/detail-timeline.js"

echo "Backup salvo em: $BACKUP_DIR"

echo ""
echo "======================================"
echo "2. Contexto antes da alteração"
echo "======================================"

echo "--- ClientDefs atual ---"
if [ -f "$CLIENT_DEF" ]; then
  grep -n -C 8 "recordViews\|dynamicHandler\|sidePanels\|registroFabricante\|defaultSidePanelFieldLists" "$CLIENT_DEF" || true
else
  echo "Arquivo não existe: $CLIENT_DEF"
fi

echo ""
echo "--- View detail-timeline atual, se existir ---"
if [ -f "$VIEW_FILE" ]; then
  grep -n -C 5 "atria-opportunity-timeline\|Espo.define\|afterRender" "$VIEW_FILE" || true
else
  echo "Arquivo ainda não existe: $VIEW_FILE"
fi

echo ""
echo "======================================"
echo "3. Atualizando Opportunity.json sem apagar regras existentes"
echo "======================================"

python3 - <<'PY'
import json
from pathlib import Path

path = Path("/opt/atria/www/custom/Espo/Custom/Resources/metadata/clientDefs/Opportunity.json")
path.parent.mkdir(parents=True, exist_ok=True)

if path.exists():
    data = json.loads(path.read_text(encoding="utf-8"))
else:
    data = {}

record_views = data.setdefault("recordViews", {})

# Preserva o kanban customizado existente e adiciona apenas a detail view.
record_views["detail"] = "custom:views/opportunity/record/detail-timeline"

path.write_text(json.dumps(data, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")

print("Opportunity.json atualizado preservando chaves existentes.")
print("recordViews atual:", data.get("recordViews"))
print("dynamicHandler preservado:", data.get("dynamicHandler"))
print("sidePanels preservado:", "sidePanels" in data)
PY

echo ""
echo "======================================"
echo "4. Criando view horizontal detail-timeline.js"
echo "======================================"

cat > "$VIEW_FILE" <<'JS'
Espo.define('custom:views/opportunity/record/detail-timeline', 'crm:views/opportunity/record/detail', function (Dep) {

    return Dep.extend({

        afterRender: function () {
            Dep.prototype.afterRender.call(this);

            this.injectAtriaOpportunityTimelineStyle();
            this.renderAtriaOpportunityTimeline();
        },

        injectAtriaOpportunityTimelineStyle: function () {
            if (document.getElementById('atria-opportunity-timeline-style')) {
                return;
            }

            const style = document.createElement('style');
            style.id = 'atria-opportunity-timeline-style';

            style.innerHTML = `
                .atria-opportunity-timeline-card {
                    width: 100%;
                    margin: 0 0 16px 0;
                    padding: 16px 18px 18px;
                    background: #fff;
                    border: 1px solid #dfe6ef;
                    border-radius: 6px;
                    box-shadow: 0 1px 2px rgba(15, 23, 42, 0.06);
                }

                .atria-opportunity-timeline-header {
                    display: flex;
                    align-items: flex-start;
                    justify-content: space-between;
                    gap: 14px;
                    margin-bottom: 16px;
                }

                .atria-opportunity-timeline-title {
                    margin: 0;
                    font-size: 15px;
                    font-weight: 600;
                    color: #2f3b4c;
                }

                .atria-opportunity-timeline-subtitle {
                    margin-top: 3px;
                    font-size: 12px;
                    color: #8a94a6;
                }

                .atria-opportunity-timeline-badges {
                    display: flex;
                    flex-wrap: wrap;
                    justify-content: flex-end;
                    gap: 8px;
                }

                .atria-opportunity-timeline-badge {
                    display: inline-flex;
                    align-items: center;
                    gap: 6px;
                    min-height: 28px;
                    padding: 5px 10px;
                    border-radius: 999px;
                    font-size: 12px;
                    font-weight: 600;
                    white-space: nowrap;
                    background: #f3f6fa;
                    color: #435166;
                }

                .atria-opportunity-timeline-badge:before {
                    content: "";
                    width: 7px;
                    height: 7px;
                    border-radius: 50%;
                    background: currentColor;
                }

                .atria-opportunity-timeline-badge.is-open {
                    background: #eef5ff;
                    color: #3b82f6;
                }

                .atria-opportunity-timeline-badge.is-won {
                    background: #edf9f1;
                    color: #2f9e44;
                }

                .atria-opportunity-timeline-badge.is-lost {
                    background: #fff1f1;
                    color: #d64545;
                }

                .atria-opportunity-timeline-scroll {
                    position: relative;
                    overflow-x: auto;
                    overflow-y: hidden;
                    padding: 12px 2px 4px;
                }

                .atria-opportunity-timeline {
                    position: relative;
                    display: grid;
                    grid-auto-flow: column;
                    grid-auto-columns: minmax(170px, 1fr);
                    gap: 12px;
                    min-width: 720px;
                    padding-top: 18px;
                }

                .atria-opportunity-timeline:before {
                    content: "";
                    position: absolute;
                    top: 27px;
                    left: 18px;
                    right: 18px;
                    height: 2px;
                    background: #d8e2ef;
                    border-radius: 999px;
                }

                .atria-opportunity-stage {
                    position: relative;
                    padding-top: 24px;
                }

                .atria-opportunity-stage-dot {
                    position: absolute;
                    top: 14px;
                    left: 15px;
                    z-index: 2;
                    width: 13px;
                    height: 13px;
                    border-radius: 50%;
                    border: 3px solid #fff;
                    background: #5d8fdc;
                    box-shadow: 0 0 0 3px rgba(93, 143, 220, 0.15);
                }

                .atria-opportunity-stage-card {
                    min-height: 112px;
                    padding: 13px 14px;
                    border: 1px solid #dfe6ef;
                    border-radius: 8px;
                    background: linear-gradient(180deg, #ffffff, #fbfcfe);
                }

                .atria-opportunity-stage-name {
                    display: flex;
                    align-items: center;
                    gap: 7px;
                    min-height: 32px;
                    margin: 0 0 8px;
                    font-size: 13px;
                    line-height: 1.25;
                    font-weight: 600;
                    color: #2f3b4c;
                }

                .atria-opportunity-stage-color {
                    flex: 0 0 auto;
                    width: 8px;
                    height: 8px;
                    border-radius: 2px;
                    background: #5d8fdc;
                }

                .atria-opportunity-stage-open-date {
                    margin-bottom: 8px;
                    color: #8a94a6;
                    font-size: 11px;
                    font-weight: 600;
                }

                .atria-opportunity-stage-days {
                    display: inline-flex;
                    align-items: baseline;
                    gap: 5px;
                    padding: 7px 10px;
                    border: 1px solid #dfe6ef;
                    border-radius: 7px;
                    background: #f8fafc;
                    color: #273244;
                    font-weight: 700;
                }

                .atria-opportunity-stage-days strong {
                    font-size: 18px;
                    letter-spacing: -0.02em;
                }

                .atria-opportunity-stage-days.is-less-than-day strong {
                    font-size: 13px;
                }

                .atria-opportunity-stage.is-final .atria-opportunity-stage-card {
                    background: #fbfcfe;
                    border-style: dashed;
                }

                .atria-opportunity-stage.is-final.is-won .atria-opportunity-stage-dot,
                .atria-opportunity-stage.is-final.is-won .atria-opportunity-stage-color {
                    background: #2f9e44;
                }

                .atria-opportunity-stage.is-final.is-lost .atria-opportunity-stage-dot,
                .atria-opportunity-stage.is-final.is-lost .atria-opportunity-stage-color {
                    background: #d64545;
                }

                .atria-opportunity-stage[data-stage="Prospecting"] .atria-opportunity-stage-dot,
                .atria-opportunity-stage[data-stage="Prospecting"] .atria-opportunity-stage-color {
                    background: #6b7280;
                }

                .atria-opportunity-stage[data-stage="Qualification"] .atria-opportunity-stage-dot,
                .atria-opportunity-stage[data-stage="Qualification"] .atria-opportunity-stage-color {
                    background: #5d8fdc;
                }

                .atria-opportunity-stage[data-stage="Desenvolvendo Solução"] .atria-opportunity-stage-dot,
                .atria-opportunity-stage[data-stage="Desenvolvendo Solução"] .atria-opportunity-stage-color {
                    background: #7c6ee6;
                }

                .atria-opportunity-stage[data-stage="Proposal"] .atria-opportunity-stage-dot,
                .atria-opportunity-stage[data-stage="Proposal"] .atria-opportunity-stage-color {
                    background: #e7a231;
                }

                .atria-opportunity-stage[data-stage="Negotiation"] .atria-opportunity-stage-dot,
                .atria-opportunity-stage[data-stage="Negotiation"] .atria-opportunity-stage-color {
                    background: #d66a9f;
                }

                .atria-opportunity-timeline-empty {
                    padding: 12px;
                    color: #8a94a6;
                    font-size: 13px;
                    border: 1px dashed #d8e2ef;
                    border-radius: 6px;
                    background: #fbfcfe;
                }

                @media (max-width: 768px) {
                    .atria-opportunity-timeline-header {
                        flex-direction: column;
                    }

                    .atria-opportunity-timeline-badges {
                        justify-content: flex-start;
                    }
                }
            `;

            document.head.appendChild(style);
        },

        renderAtriaOpportunityTimeline: function () {
            const entityId = this.model && this.model.id;

            if (!entityId) {
                return;
            }

            const $target = this.getAtriaTimelineTarget();

            if (!$target || !$target.length) {
                return;
            }

            $target.find('.atria-opportunity-timeline-card').remove();

            const html = `
                <div class="atria-opportunity-timeline-card">
                    <div class="atria-opportunity-timeline-header">
                        <div>
                            <h3 class="atria-opportunity-timeline-title">Timeline da Oportunidade</h3>
                            <div class="atria-opportunity-timeline-subtitle">Tempo arredondado em dias por estágio.</div>
                        </div>
                        <div class="atria-opportunity-timeline-badges">
                            <span class="atria-opportunity-timeline-badge is-open">Carregando</span>
                        </div>
                    </div>
                    <div class="atria-opportunity-timeline-empty">Carregando histórico de estágios...</div>
                </div>
            `;

            $target.prepend(html);

            this.loadAtriaOpportunityStageTimeline(entityId);
        },

        getAtriaTimelineTarget: function () {
            const selectors = [
                '.record',
                '.record-grid',
                '.detail',
                '.middle',
                '.main',
                '.container-fluid'
            ];

            for (let i = 0; i < selectors.length; i++) {
                const $candidate = this.$el.find(selectors[i]).first();

                if ($candidate.length) {
                    return $candidate;
                }
            }

            return this.$el;
        },

        loadAtriaOpportunityStageTimeline: function (entityId) {
            const self = this;

            Espo.Ajax.getRequest('Note', {
                maxSize: 200,
                orderBy: 'createdAt',
                order: 'asc',
                where: [
                    {
                        type: 'equals',
                        attribute: 'parentType',
                        value: 'Opportunity'
                    },
                    {
                        type: 'equals',
                        attribute: 'parentId',
                        value: entityId
                    }
                ]
            }).then(function (response) {
                const list = response && (response.list || response.collection || response);
                const notes = Array.isArray(list) ? list : [];
                const timeline = self.buildAtriaStageTimeline(notes);

                self.updateAtriaTimelineCard(timeline);
            }).catch(function () {
                self.showAtriaTimelineError();
            });
        },

        buildAtriaStageTimeline: function (notes) {
            const events = [];

            notes.forEach(note => {
                const data = this.parseAtriaNoteData(note.data);
                let stage = null;

                if (data && data.statusField === 'stage' && data.statusValue) {
                    stage = data.statusValue;
                } else if (data && data.value && typeof data.value === 'string') {
                    stage = data.value;
                }

                if (!stage) {
                    return;
                }

                const date = note.createdAt || note.created_at || note.createdAtDate;

                if (!date) {
                    return;
                }

                events.push({
                    stage: stage,
                    date: date
                });
            });

            events.sort((a, b) => new Date(a.date) - new Date(b.date));

            let result = null;
            let closedAt = null;

            events.forEach(event => {
                if (event.stage === 'Closed Won') {
                    result = 'Ganha';
                    closedAt = event.date;
                }

                if (event.stage === 'Closed Lost') {
                    result = 'Perdida';
                    closedAt = event.date;
                }
            });

            const stages = [];

            events.forEach((event, index) => {
                if (event.stage === 'Closed Won' || event.stage === 'Closed Lost') {
                    return;
                }

                const next = events[index + 1];
                const endDate = next ? next.date : (closedAt || new Date().toISOString());

                stages.push({
                    stage: event.stage,
                    enteredAt: event.date,
                    days: this.calculateAtriaRoundedDays(event.date, endDate)
                });
            });

            const openedAt = events[0] ? events[0].date : null;
            const totalEnd = closedAt || new Date().toISOString();

            return {
                stages: stages,
                result: result,
                openedAt: openedAt,
                totalDays: openedAt ? this.calculateAtriaRoundedDays(openedAt, totalEnd) : null
            };
        },

        parseAtriaNoteData: function (value) {
            if (!value) {
                return null;
            }

            if (typeof value === 'object') {
                return value;
            }

            try {
                return JSON.parse(value);
            } catch (e) {
                return null;
            }
        },

        calculateAtriaRoundedDays: function (start, end) {
            const startDate = new Date(start);
            const endDate = new Date(end);

            if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
                return {
                    raw: 0,
                    rounded: 0
                };
            }

            const diff = Math.max(0, endDate.getTime() - startDate.getTime());
            const days = diff / (1000 * 60 * 60 * 24);

            return {
                raw: days,
                rounded: Math.round(days)
            };
        },

        formatAtriaDays: function (daysInfo) {
            if (!daysInfo) {
                return '0 dias';
            }

            if (daysInfo.raw > 0 && daysInfo.raw < 1) {
                return 'menos de 1 dia';
            }

            if (daysInfo.rounded === 1) {
                return '1 dia';
            }

            return daysInfo.rounded + ' dias';
        },

        formatAtriaShortDate: function (value) {
            if (!value) {
                return '';
            }

            const datePart = String(value).split(' ')[0].split('T')[0];
            const parts = datePart.split('-');

            if (parts.length !== 3) {
                return value;
            }

            return parts[2] + '/' + parts[1] + '/' + parts[0];
        },

        updateAtriaTimelineCard: function (timeline) {
            const $card = this.$el.find('.atria-opportunity-timeline-card').first();

            if (!$card.length) {
                return;
            }

            const resultClass = timeline.result === 'Ganha'
                ? 'is-won'
                : timeline.result === 'Perdida'
                    ? 'is-lost'
                    : 'is-open';

            const resultLabel = timeline.result || 'Em andamento';
            const totalLabel = timeline.totalDays ? this.formatAtriaDays(timeline.totalDays) + ' no funil' : 'Sem histórico';

            $card.find('.atria-opportunity-timeline-badges').html(`
                <span class="atria-opportunity-timeline-badge is-open">${this.escapeAtriaHtml(totalLabel)}</span>
                <span class="atria-opportunity-timeline-badge ${resultClass}">${this.escapeAtriaHtml(resultLabel)}</span>
            `);

            if (!timeline.stages.length) {
                $card.find('.atria-opportunity-timeline-empty').replaceWith(
                    '<div class="atria-opportunity-timeline-empty">Ainda não há histórico suficiente de estágio para esta oportunidade.</div>'
                );

                return;
            }

            const stagesHtml = timeline.stages.map((item, index) => {
                const daysLabel = this.formatAtriaDays(item.days);
                const lessClass = daysLabel === 'menos de 1 dia' ? 'is-less-than-day' : '';
                const openedLabel = index === 0 && timeline.openedAt
                    ? `<div class="atria-opportunity-stage-open-date">Aberta em ${this.escapeAtriaHtml(this.formatAtriaShortDate(timeline.openedAt))}</div>`
                    : '';

                return `
                    <div class="atria-opportunity-stage" data-stage="${this.escapeAtriaHtml(item.stage)}">
                        <span class="atria-opportunity-stage-dot"></span>
                        <div class="atria-opportunity-stage-card">
                            <h4 class="atria-opportunity-stage-name">
                                <span class="atria-opportunity-stage-color"></span>
                                ${this.escapeAtriaHtml(this.translateAtriaStage(item.stage))}
                            </h4>
                            ${openedLabel}
                            <div class="atria-opportunity-stage-days ${lessClass}">
                                <strong>${this.escapeAtriaHtml(daysLabel)}</strong>
                            </div>
                        </div>
                    </div>
                `;
            }).join('');

            const finalHtml = timeline.result
                ? `
                    <div class="atria-opportunity-stage is-final ${timeline.result === 'Ganha' ? 'is-won' : 'is-lost'}">
                        <span class="atria-opportunity-stage-dot"></span>
                        <div class="atria-opportunity-stage-card">
                            <h4 class="atria-opportunity-stage-name">
                                <span class="atria-opportunity-stage-color"></span>
                                ${this.escapeAtriaHtml(timeline.result)}
                            </h4>
                            <div class="atria-opportunity-stage-days">
                                <strong>Status final</strong>
                            </div>
                        </div>
                    </div>
                `
                : '';

            $card.find('.atria-opportunity-timeline-empty').replaceWith(`
                <div class="atria-opportunity-timeline-scroll">
                    <div class="atria-opportunity-timeline">
                        ${stagesHtml}
                        ${finalHtml}
                    </div>
                </div>
            `);
        },

        showAtriaTimelineError: function () {
            const $card = this.$el.find('.atria-opportunity-timeline-card').first();

            if (!$card.length) {
                return;
            }

            $card.find('.atria-opportunity-timeline-badges').html(
                '<span class="atria-opportunity-timeline-badge is-lost">Erro ao carregar</span>'
            );

            $card.find('.atria-opportunity-timeline-empty').html(
                'Não foi possível carregar o histórico de estágios desta oportunidade.'
            );
        },

        translateAtriaStage: function (stage) {
            const map = {
                'Prospecting': 'Prospectando',
                'Qualification': 'Qualificação',
                'Desenvolvendo Solução': 'Desenvolvendo Solução',
                'Proposal': 'Proposta',
                'Negotiation': 'Negociação'
            };

            return map[stage] || stage;
        },

        escapeAtriaHtml: function (value) {
            if (value === null || value === undefined) {
                return '';
            }

            return String(value)
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#039;');
        }
    });
});
JS

echo "View criada em: $VIEW_FILE"

echo ""
echo "======================================"
echo "5. Limpando cache"
echo "======================================"

cd "$APP_DIR"
php command.php clear-cache || true

echo ""
echo "======================================"
echo "6. Contexto depois da alteração"
echo "======================================"

echo "--- ClientDefs depois ---"
grep -n -C 10 "recordViews\|dynamicHandler\|sidePanels\|registroFabricante" "$CLIENT_DEF" || true

echo ""
echo "--- View criada ---"
grep -n -C 5 "Espo.define\|atria-opportunity-timeline\|Status final\|Aberta em" "$VIEW_FILE" || true

echo ""
echo "======================================"
echo "Concluído"
echo "======================================"
echo "Abra a oportunidade e force refresh com CTRL + F5."
echo "Backup: $BACKUP_DIR"
