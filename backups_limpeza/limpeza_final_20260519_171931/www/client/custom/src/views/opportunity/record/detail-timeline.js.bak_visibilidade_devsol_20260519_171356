Espo.define('custom:views/opportunity/record/detail-timeline', 'views/record/detail', function (Dep) {

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
                    margin: 0 0 18px 0;
                    padding: 18px 20px 20px;
                    background: #fff;
                    border: 1px solid #dfe6ef;
                    border-radius: 8px;
                    box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
                    grid-column: 1 / -1;
                    clear: both;
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
                    grid-template-columns: repeat(6, minmax(0, 1fr));
                    gap: 14px;
                    width: 100%;
                    min-width: 980px;
                    padding-top: 18px;
                    align-items: stretch;
                }

                .atria-opportunity-timeline-scroll:before {
                    content: "";
                    position: absolute;
                    top: 39px;
                    left: 18px;
                    right: 18px;
                    height: 2px;
                    background: #d8e2ef;
                    border-radius: 999px;
                    pointer-events: none;
                }

                .atria-opportunity-timeline:before {
                    display: none;
                }

                .atria-opportunity-stage {
                    position: relative;
                    padding-top: 24px;
                }

                .atria-opportunity-stage-dot {
                    position: absolute;
                    top: 14px;
                    left: 50%;
                    transform: translateX(-50%);
                    z-index: 2;
                    width: 13px;
                    height: 13px;
                    border-radius: 50%;
                    border: 3px solid #fff;
                    background: #5d8fdc;
                    box-shadow: 0 0 0 3px rgba(93, 143, 220, 0.15);
                }

                .atria-opportunity-stage-card {
                    position: relative;
                    width: 100%;
                    height: 132px;
                    min-height: 132px;
                    padding: 14px 15px;
                    border: 1px solid #dfe6ef;
                    border-radius: 8px;
                    background: linear-gradient(180deg, #ffffff, #fbfcfe);
                    box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
                    display: flex;
                    flex-direction: column;
                    justify-content: space-between;
                    overflow: hidden;
                }

                .atria-opportunity-stage-name {
                    display: flex;
                    align-items: flex-start;
                    gap: 7px;
                    min-height: 34px;
                    margin: 0 0 6px;
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
                    margin-top: 4px;
                }

                .atria-opportunity-stage-name-text {
                    display: block;
                    min-width: 0;
                    overflow-wrap: anywhere;
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

                .atria-opportunity-final-date {
                    margin-top: 8px;
                    font-size: 11px;
                    line-height: 1.2;
                    font-weight: 600;
                    color: #2f9e44;
                }

                .atria-opportunity-stage.is-final.is-lost .atria-opportunity-final-date {
                    color: #d64545;
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


                .atria-opportunity-stage-top {
                    min-height: 64px;
                }

                .atria-opportunity-stage-meta {
                    display: flex;
                    align-items: center;
                    flex-wrap: wrap;
                    gap: 6px;
                    margin-top: 6px;
                }

                .atria-opportunity-stage-status {
                    display: inline-flex;
                    align-items: center;
                    gap: 5px;
                    padding: 3px 7px;
                    border-radius: 999px;
                    font-size: 10px;
                    line-height: 1;
                    font-weight: 700;
                    color: #3b82f6;
                    background: #eef5ff;
                }

                .atria-opportunity-stage-return {
                    position: absolute;
                    top: 10px;
                    right: 10px;
                    width: 22px;
                    height: 22px;
                    border-radius: 999px;
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    color: #d97706;
                    background: #fff7ed;
                    border: 1px solid #fed7aa;
                    font-size: 14px;
                    font-weight: 800;
                }

                .atria-opportunity-stage.is-current .atria-opportunity-stage-card {
                    border-color: #9dc2ff;
                    box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.08);
                }


                /* ATRIA_DEV_SOL_STYLE_V2_START */

                @media (max-width: 768px) {
                    .atria-devsol-row {
                        grid-template-columns: 1fr;
                        gap: 10px;
                    }
                }
                /* ATRIA_DEV_SOL_DYNAMIC_STYLE_END */

                @media (max-width: 768px) {
                    .atria-devsol-row {
                        grid-template-columns: 1fr;
                        gap: 10px;
                    }
                }
                /* ATRIA_DEV_SOL_STYLE_V2_END */

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
                '.record-grid',
                '.middle',
                '.detail',
                '.main',
                '.container-fluid',
                '.record'
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
            const stageOrder = [
                'Prospecting',
                'Qualification',
                'Desenvolvendo Solução',
                'Proposal',
                'Negotiation'
            ];

            const stageIndex = {};
            stageOrder.forEach((stage, index) => {
                stageIndex[stage] = index;
            });

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

            const operationalEvents = events.filter(event => {
                return event.stage !== 'Closed Won' && event.stage !== 'Closed Lost';
            });

            const currentStage = result ? null : (
                operationalEvents.length ? operationalEvents[operationalEvents.length - 1].stage : null
            );

            const aggregate = {};
            const visitedSequence = [];
            let previousOperationalStage = null;

            operationalEvents.forEach((event, index) => {
                const next = events[events.indexOf(event) + 1];
                const endDate = next ? next.date : (closedAt || new Date().toISOString());
                const daysInfo = this.calculateAtriaRoundedDays(event.date, endDate);

                if (!aggregate[event.stage]) {
                    aggregate[event.stage] = {
                        stage: event.stage,
                        enteredAt: event.date,
                        rawDays: 0,
                        passages: 0,
                        returned: false,
                        isCurrent: false
                    };
                }

                aggregate[event.stage].rawDays += daysInfo.raw || 0;
                aggregate[event.stage].passages += 1;

                if (new Date(event.date) < new Date(aggregate[event.stage].enteredAt)) {
                    aggregate[event.stage].enteredAt = event.date;
                }

                if (
                    previousOperationalStage &&
                    stageIndex[event.stage] !== undefined &&
                    stageIndex[previousOperationalStage] !== undefined &&
                    stageIndex[event.stage] < stageIndex[previousOperationalStage]
                ) {
                    aggregate[event.stage].returned = true;
                }

                visitedSequence.push(event.stage);
                previousOperationalStage = event.stage;
            });

            if (currentStage && aggregate[currentStage]) {
                aggregate[currentStage].isCurrent = true;
            }

            const stages = stageOrder
                .filter(stage => aggregate[stage])
                .map(stage => {
                    const item = aggregate[stage];

                    return {
                        stage: item.stage,
                        enteredAt: item.enteredAt,
                        passages: item.passages,
                        returned: item.returned,
                        isCurrent: item.isCurrent,
                        days: {
                            raw: item.rawDays,
                            rounded: Math.round(item.rawDays)
                        }
                    };
                });

            const openedAt = events[0] ? events[0].date : null;
            const totalEnd = closedAt || new Date().toISOString();

            return {
                stages: stages,
                result: result,
                closedAt: closedAt,
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

                const currentLabel = item.isCurrent
                    ? '<span class="atria-opportunity-stage-status">Estágio atual</span>'
                    : '';

                const returnIcon = item.returned
                    ? '<span class="atria-opportunity-stage-return" title="Retornou para fase anterior">↩</span>'
                    : '';

                const currentClass = item.isCurrent ? 'is-current' : '';

                const column = this.getAtriaStageColumn(item.stage);

                return `
                    <div class="atria-opportunity-stage ${currentClass}" data-stage="${this.escapeAtriaHtml(item.stage)}" style="grid-column: ${column};">
                        <span class="atria-opportunity-stage-dot"></span>
                        <div class="atria-opportunity-stage-card">
                            ${returnIcon}
                            <div class="atria-opportunity-stage-top">
                                <h4 class="atria-opportunity-stage-name">
                                    <span class="atria-opportunity-stage-color"></span>
                                    ${this.escapeAtriaHtml(this.translateAtriaStage(item.stage))}
                                </h4>
                                ${openedLabel}
                                <div class="atria-opportunity-stage-meta">
                                    ${currentLabel}
                                </div>
                            </div>
                            <div class="atria-opportunity-stage-days ${lessClass}">
                                <strong>${this.escapeAtriaHtml(daysLabel)}</strong>
                            </div>
                        </div>
                    </div>
                `;
            }).join('');

            const finalDateHtml = timeline.closedAt
                ? `<div class="atria-opportunity-final-date">${this.escapeAtriaHtml(this.formatAtriaShortDate(timeline.closedAt))}</div>`
                : '';

            const finalHtml = timeline.result
                ? `
                    <div class="atria-opportunity-stage is-final ${timeline.result === 'Ganha' ? 'is-won' : 'is-lost'}" style="grid-column: 6;">
                        <span class="atria-opportunity-stage-dot"></span>
                        <div class="atria-opportunity-stage-card">
                            <div class="atria-opportunity-stage-top">
                                <h4 class="atria-opportunity-stage-name">
                                    <span class="atria-opportunity-stage-color"></span>
                                    <span class="atria-opportunity-stage-name-text">${this.escapeAtriaHtml(timeline.result)}</span>
                                </h4>
                                ${finalDateHtml}
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

        getAtriaStageColumn: function (stage) {
            const map = {
                'Prospecting': 1,
                'Qualification': 2,
                'Desenvolvendo Solução': 3,
                'Proposal': 4,
                'Negotiation': 5
            };

            return map[stage] || 1;
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
