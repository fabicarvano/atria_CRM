define('custom:views/account/record/panels/heat-map', ['views/record/panels/bottom'], function (Dep) {

    return Dep.extend({

        templateContent: `
            <div class="heatmap-account-wrapper">
                <div class="heatmap-summary">
                    <div class="heatmap-summary-card">
                        <div class="heatmap-summary-label">% Mapeado</div>
                        <div class="heatmap-summary-value heatmap-percent">0%</div>
                        <div class="heatmap-summary-sub heatmap-percent-sub">0 de 0 aplicáveis</div>
                    </div>

                    <div class="heatmap-summary-card">
                        <div class="heatmap-summary-label">Oportunidades</div>
                        <div class="heatmap-summary-value heatmap-oportunidades">0</div>
                        <div class="heatmap-summary-sub">em andamento</div>
                    </div>

                    <div class="heatmap-summary-card">
                        <div class="heatmap-summary-label">Ofertas da Base</div>
                        <div class="heatmap-summary-value heatmap-base">0</div>
                        <div class="heatmap-summary-sub">Base Atual</div>
                    </div>
                </div>

                <div class="heatmap-inner-tabs">
                    <button type="button" class="heatmap-inner-tab active" data-heatmap-tab="revenda">Revenda</button>
                    <button type="button" class="heatmap-inner-tab" data-heatmap-tab="servico">Serviço Gerenciado</button>
                </div>

                <div class="heatmap-tab-content heatmap-tab-revenda active">
                    <div class="heatmap-card heatmap-card-full">
                        <div class="heatmap-card-title">Revenda</div>
                        <div class="heatmap-table-wrap">
                            <table class="table table-condensed heatmap-table heatmap-revenda-table">
                                <thead>
                                    <tr>
                                        <th>Oferta</th>
                                        <th>Fornecedor Atual</th>
                                        <th>Status</th>
                                        <th>Concorrente</th>
                                        <th>Observação</th>
                                        <th>Ações</th>
                                    </tr>
                                </thead>
                                <tbody></tbody>
                            </table>
                        </div>
                    </div>
                </div>

                <div class="heatmap-tab-content heatmap-tab-servico">
                    <div class="heatmap-card heatmap-card-full">
                        <div class="heatmap-card-title">Serviço Gerenciado</div>
                        <div class="heatmap-table-wrap">
                            <table class="table table-condensed heatmap-table heatmap-servico-table">
                                <thead>
                                    <tr>
                                        <th>Oferta</th>
                                        <th>Fornecedor Atual</th>
                                        <th>Status</th>
                                        <th>Concorrente</th>
                                        <th>Observação</th>
                                        <th>Ações</th>
                                    </tr>
                                </thead>
                                <tbody></tbody>
                            </table>
                        </div>
                    </div>
                </div>

                <div class="heatmap-msg text-muted">Carregando Heat Map...</div>
            </div>
        `,

        setup: function () {
            Dep.prototype.setup.call(this);
            this.items = [];
            this.catalogoOrdem = {};
            this.activeHeatmapTab = 'revenda';
        },

        afterRender: function () {
            Dep.prototype.afterRender.call(this);
            this.injetarCss();
            this.bindSubAbas();
            this.bindEdicao();
            this.carregarHeatMap();
        },

        bindSubAbas: function () {
            var self = this;

            this.$el.off('click.heatmapTabs', '.heatmap-inner-tab');

            this.$el.on('click.heatmapTabs', '.heatmap-inner-tab', function () {
                var tab = $(this).attr('data-heatmap-tab');

                self.activeHeatmapTab = tab || 'revenda';

                self.$el.find('.heatmap-inner-tab').removeClass('active');
                $(this).addClass('active');

                self.$el.find('.heatmap-tab-content').removeClass('active');

                if (self.activeHeatmapTab === 'servico') {
                    self.$el.find('.heatmap-tab-servico').addClass('active');
                } else {
                    self.$el.find('.heatmap-tab-revenda').addClass('active');
                }
            });
        },

        bindEdicao: function () {
            var self = this;

            this.$el.off('click.heatmapEditRow', '.heatmap-edit-row');
            this.$el.off('click.heatmapCancelRow', '.heatmap-cancel-row');
            this.$el.off('click.heatmapSave', '.heatmap-save-row');
            this.$el.off('change.heatmapEdit', '.heatmap-edit');

            this.$el.on('click.heatmapEditRow', '.heatmap-edit-row', function () {
                var $row = $(this).closest('tr');
                self.entrarModoEdicao($row);
            });

            this.$el.on('click.heatmapCancelRow', '.heatmap-cancel-row', function () {
                var $row = $(this).closest('tr');
                self.sairModoEdicao($row, true);
            });

            this.$el.on('click.heatmapSave', '.heatmap-save-row', function () {
                var $row = $(this).closest('tr');
                self.salvarLinha($row);
            });

            this.$el.on('change.heatmapEdit', '.heatmap-edit', function () {
                var $row = $(this).closest('tr');
                self.controlarCampoConcorrente($row);

                if ($(this).hasClass('heatmap-status-select')) {
                    self.atualizarResumoLocal();
                }
            });
        },

        injetarCss: function () {
            if ($('#heatmap-account-style').length) {
                return;
            }

            $('head').append(`
                <style id="heatmap-account-style">
                    .heatmap-account-wrapper { padding: 4px 2px 8px; }

                    .heatmap-summary {
                        display: grid;
                        grid-template-columns: repeat(3, minmax(180px, 1fr));
                        gap: 12px;
                        margin-bottom: 16px;
                    }

                    .heatmap-summary-card {
                        border: 1px solid #e5e7eb;
                        border-radius: 12px;
                        padding: 14px 16px;
                        background: #fff;
                        box-shadow: 0 1px 3px rgba(15, 23, 42, 0.06);
                    }

                    .heatmap-summary-label {
                        font-size: 12px;
                        color: #64748b;
                        margin-bottom: 4px;
                    }

                    .heatmap-summary-value {
                        font-size: 24px;
                        font-weight: 700;
                        color: #0f172a;
                        line-height: 1.1;
                    }

                    .heatmap-summary-sub {
                        font-size: 11px;
                        color: #94a3b8;
                        margin-top: 4px;
                    }

                    .heatmap-inner-tabs {
                        display: flex;
                        gap: 8px;
                        margin: 4px 0 14px;
                        border-bottom: 1px solid #e5e7eb;
                    }

                    .heatmap-inner-tab {
                        border: 0;
                        background: transparent;
                        padding: 10px 14px;
                        font-size: 13px;
                        font-weight: 600;
                        color: #64748b;
                        border-bottom: 2px solid transparent;
                        cursor: pointer;
                    }

                    .heatmap-inner-tab:hover { color: #0f172a; }

                    .heatmap-inner-tab.active {
                        color: #0f172a;
                        border-bottom-color: #2563eb;
                    }

                    .heatmap-tab-content { display: none; }
                    .heatmap-tab-content.active { display: block; }

                    .heatmap-card {
                        border: 1px solid #e5e7eb;
                        border-radius: 12px;
                        background: #fff;
                        overflow: hidden;
                        box-shadow: 0 1px 3px rgba(15, 23, 42, 0.06);
                    }

                    .heatmap-card-full { width: 100%; }

                    .heatmap-card-title {
                        font-weight: 700;
                        padding: 12px 14px;
                        background: #f8fafc;
                        border-bottom: 1px solid #e5e7eb;
                        color: #0f172a;
                    }

                    .heatmap-table-wrap {
                        width: 100%;
                        overflow-x: auto;
                    }

                    .heatmap-table {
                        margin-bottom: 0;
                        font-size: 12px;
                        min-width: 1100px;
                    }

                    .heatmap-table th {
                        color: #64748b;
                        font-weight: 600;
                        white-space: nowrap;
                    }

                    .heatmap-table td {
                        vertical-align: middle !important;
                        white-space: nowrap;
                    }

                    .heatmap-table th:nth-child(1),
                    .heatmap-table td:nth-child(1) { min-width: 220px; }

                    .heatmap-table th:nth-child(2),
                    .heatmap-table td:nth-child(2) { min-width: 180px; }

                    .heatmap-table th:nth-child(3),
                    .heatmap-table td:nth-child(3) { min-width: 190px; }

                    .heatmap-table th:nth-child(4),
                    .heatmap-table td:nth-child(4) { min-width: 180px; }

                    .heatmap-table th:nth-child(5),
                    .heatmap-table td:nth-child(5) { min-width: 260px; }

                    .heatmap-table th:nth-child(6),
                    .heatmap-table td:nth-child(6) { min-width: 90px; text-align: center; }

                    .heatmap-input,
                    .heatmap-select {
                        width: 100%;
                        min-height: 30px;
                        border: 1px solid #dbe3ec;
                        border-radius: 6px;
                        padding: 4px 8px;
                        background: #fff;
                        font-size: 12px;
                    }

                    .heatmap-input:disabled {
                        background: #f8fafc;
                        color: #94a3b8;
                    }

                    .heatmap-action-btn {
                        border: 1px solid #cbd5e1;
                        background: #fff;
                        border-radius: 6px;
                        padding: 4px 8px;
                        font-size: 12px;
                        margin-right: 4px;
                    }

                    .heatmap-action-btn:hover {
                        background: #f8fafc;
                    }

                    .heatmap-edit-row {
                        min-width: 32px;
                    }

                    .heatmap-save-row {
                        color: #166534;
                        border-color: #bbf7d0;
                    }

                    .heatmap-cancel-row {
                        color: #991b1b;
                        border-color: #fecaca;
                    }

                    .heatmap-row-saving .heatmap-action-btn {
                        opacity: .6;
                        pointer-events: none;
                    }

                    .heatmap-row-saved {
                        background: #f0fdf4;
                    }

                    .heatmap-read-value {
                        display: inline-block;
                        min-height: 20px;
                        padding: 4px 0;
                    }

                    .heatmap-status-pill {
                        display: inline-block;
                        padding: 3px 8px;
                        border-radius: 999px;
                        font-size: 11px;
                        font-weight: 600;
                        background: #f1f5f9;
                        color: #64748b;
                    }

                    .heatmap-row-editing .heatmap-read-mode {
                        display: none;
                    }

                    .heatmap-row-viewing .heatmap-edit-mode {
                        display: none;
                    }

                    .heatmap-empty { color: #cbd5e1; }

                    .heatmap-msg {
                        margin-top: 10px;
                        font-size: 12px;
                    }

                    @media (max-width: 1100px) {
                        .heatmap-summary { grid-template-columns: 1fr; }
                        .heatmap-inner-tabs { overflow-x: auto; }
                    }
                </style>
            `);
        },

        carregarHeatMap: function () {
            var accountId = this.model.id;
            var self = this;

            if (!accountId) {
                this.setMensagem('Conta ainda não salva.');
                return;
            }

            Promise.all([
                Espo.Ajax.getRequest('CatalogoOferta', {
                    maxSize: 200,
                    orderBy: 'ordem',
                    order: 'asc'
                }),
                Espo.Ajax.getRequest('MapeamentoConta', {
                    where: [
                        {
                            type: 'equals',
                            attribute: 'accountId',
                            value: accountId
                        }
                    ],
                    maxSize: 200
                })
            ]).then(function (responses) {
                var catalogo = responses[0].list || [];
                var mapeamentos = responses[1].list || [];

                self.catalogoOrdem = {};

                catalogo.forEach(function (oferta) {
                    self.catalogoOrdem[oferta.id] = {
                        ordem: oferta.ordem || 9999,
                        nome: oferta.name || oferta.nome || ''
                    };
                });

                mapeamentos.sort(function (a, b) {
                    var ordemA = self.catalogoOrdem[a.catalogoOfertaId] ? self.catalogoOrdem[a.catalogoOfertaId].ordem : 9999;
                    var ordemB = self.catalogoOrdem[b.catalogoOfertaId] ? self.catalogoOrdem[b.catalogoOfertaId].ordem : 9999;

                    if (ordemA !== ordemB) {
                        return ordemA - ordemB;
                    }

                    return String(a.catalogoOfertaName || '').localeCompare(String(b.catalogoOfertaName || ''));
                });

                self.items = mapeamentos;
                self.renderizarHeatMap();
            }).catch(function () {
                self.setMensagem('Não foi possível carregar o Heat Map.');
            });
        },

        valorTexto: function (valor) {
            if (valor === null || valor === undefined) {
                return '';
            }

            return String(valor);
        },

        escapeAttr: function (valor) {
            return Handlebars.Utils.escapeExpression(this.valorTexto(valor));
        },

        labelStatus: function (status) {
            var labels = {
                '': 'Não mapeado',
                baseAtual: 'Base Atual',
                concorrente: 'Concorrente',
                oportunidadeEmAndamento: 'Oportunidade em andamento',
                semAderencia: 'Sem aderência',
                naoSeAplica: 'Não se aplica'
            };

            return labels[status || ''] || 'Não mapeado';
        },

        optionStatus: function (valorAtual, valor, label) {
            var selected = valorAtual === valor ? ' selected' : '';

            return '<option value="' + this.escapeAttr(valor) + '"' + selected + '>' +
                Handlebars.Utils.escapeExpression(label) +
            '</option>';
        },

        statusSelectHtml: function (status) {
            return `
                <select class="heatmap-select heatmap-edit heatmap-status-select" data-field="status">
                    ${this.optionStatus(status || '', '', 'Não mapeado')}
                    ${this.optionStatus(status || '', 'baseAtual', 'Base Atual')}
                    ${this.optionStatus(status || '', 'concorrente', 'Concorrente')}
                    ${this.optionStatus(status || '', 'oportunidadeEmAndamento', 'Oportunidade em andamento')}
                    ${this.optionStatus(status || '', 'semAderencia', 'Sem aderência')}
                    ${this.optionStatus(status || '', 'naoSeAplica', 'Não se aplica')}
                </select>
            `;
        },

        inputHtml: function (field, valor, disabled) {
            return '<input type="text" class="heatmap-input heatmap-edit" data-field="' + field + '" value="' +
                this.escapeAttr(valor) + '"' + (disabled ? ' disabled' : '') + '>';
        },

        readValueHtml: function (valor) {
            var texto = this.valorTexto(valor);

            if (!texto) {
                return '<span class="heatmap-read-value heatmap-empty">—</span>';
            }

            return '<span class="heatmap-read-value">' + Handlebars.Utils.escapeExpression(texto) + '</span>';
        },

        readStatusHtml: function (status) {
            return '<span class="heatmap-status-pill">' +
                Handlebars.Utils.escapeExpression(this.labelStatus(status)) +
            '</span>';
        },

        linhaHtml: function (item) {
            var oferta = item.catalogoOfertaName || item.name || 'Oferta';
            var status = item.status || '';
            var concorrenteDisabled = status !== 'concorrente';

            return `
                <tr class="heatmap-row-viewing" data-id="${this.escapeAttr(item.id)}">
                    <td>${Handlebars.Utils.escapeExpression(oferta)}</td>

                    <td>
                        <div class="heatmap-read-mode">${this.readValueHtml(item.fornecedorAtual)}</div>
                        <div class="heatmap-edit-mode">${this.inputHtml('fornecedorAtual', item.fornecedorAtual, false)}</div>
                    </td>

                    <td>
                        <div class="heatmap-read-mode">${this.readStatusHtml(status)}</div>
                        <div class="heatmap-edit-mode">${this.statusSelectHtml(status)}</div>
                    </td>

                    <td>
                        <div class="heatmap-read-mode">${this.readValueHtml(item.concorrenteIdentificado)}</div>
                        <div class="heatmap-edit-mode">${this.inputHtml('concorrenteIdentificado', item.concorrenteIdentificado, concorrenteDisabled)}</div>
                    </td>

                    <td>
                        <div class="heatmap-read-mode">${this.readValueHtml(item.observacao)}</div>
                        <div class="heatmap-edit-mode">${this.inputHtml('observacao', item.observacao, false)}</div>
                    </td>

                    <td>
                        <button type="button" class="heatmap-action-btn heatmap-edit-row" title="Editar">✏️</button>
                        <button type="button" class="heatmap-action-btn heatmap-save-row heatmap-edit-mode">Salvar</button>
                        <button type="button" class="heatmap-action-btn heatmap-cancel-row heatmap-edit-mode">Cancelar</button>
                    </td>
                </tr>
            `;
        },

        entrarModoEdicao: function ($row) {
            $row.removeClass('heatmap-row-viewing').addClass('heatmap-row-editing');
            this.controlarCampoConcorrente($row);
        },

        sairModoEdicao: function ($row, recarregar) {
            $row.removeClass('heatmap-row-editing').addClass('heatmap-row-viewing');

            if (recarregar) {
                this.carregarHeatMap();
            }
        },

        renderizarHeatMap: function () {
            var $revenda = this.$el.find('.heatmap-revenda-table tbody');
            var $servico = this.$el.find('.heatmap-servico-table tbody');

            $revenda.empty();
            $servico.empty();

            var self = this;

            (this.items || []).forEach(function (item) {
                if (item.categoria === 'servicoGerenciado') {
                    $servico.append(self.linhaHtml(item));
                } else {
                    $revenda.append(self.linhaHtml(item));
                }
            });

            if ($revenda.children().length === 0) {
                $revenda.append('<tr><td colspan="6" class="text-muted">Nenhuma oferta de Revenda encontrada.</td></tr>');
            }

            if ($servico.children().length === 0) {
                $servico.append('<tr><td colspan="6" class="text-muted">Nenhuma oferta de Serviço Gerenciado encontrada.</td></tr>');
            }

            this.atualizarResumoLocal();
            this.setMensagem('');
        },

        controlarCampoConcorrente: function ($row) {
            var status = $row.find('[data-field="status"]').val();
            var $concorrente = $row.find('[data-field="concorrenteIdentificado"]');

            if (status === 'concorrente') {
                $concorrente.prop('disabled', false);
            } else {
                $concorrente.val('');
                $concorrente.prop('disabled', true);
            }
        },

        coletarPayloadLinha: function ($row) {
            var status = $row.find('[data-field="status"]').val() || '';

            return {
                fornecedorAtual: $row.find('[data-field="fornecedorAtual"]').val() || '',
                status: status,
                concorrenteIdentificado: status === 'concorrente'
                    ? ($row.find('[data-field="concorrenteIdentificado"]').val() || '')
                    : '',
                observacao: $row.find('[data-field="observacao"]').val() || ''
            };
        },

        atualizarItemLocal: function (id, payload) {
            (this.items || []).forEach(function (item) {
                if (item.id === id) {
                    item.fornecedorAtual = payload.fornecedorAtual;
                    item.status = payload.status;
                    item.concorrenteIdentificado = payload.concorrenteIdentificado;
                    item.observacao = payload.observacao;
                }
            });
        },

        atualizarResumoLocal: function () {
            var totalAplicavel = 0;
            var totalMapeado = 0;
            var totalOportunidades = 0;
            var totalBase = 0;

            this.$el.find('tr[data-id]').each(function () {
                var status = $(this).find('[data-field="status"]').val() || '';

                if (status !== 'naoSeAplica') {
                    totalAplicavel++;

                    if (
                        status === 'baseAtual' ||
                        status === 'concorrente' ||
                        status === 'oportunidadeEmAndamento' ||
                        status === 'semAderencia'
                    ) {
                        totalMapeado++;
                    }
                }

                if (status === 'oportunidadeEmAndamento') {
                    totalOportunidades++;
                }

                if (status === 'baseAtual') {
                    totalBase++;
                }
            });

            var percentual = totalAplicavel > 0
                ? Math.round((totalMapeado / totalAplicavel) * 100)
                : 0;

            this.$el.find('.heatmap-percent').text(percentual + '%');
            this.$el.find('.heatmap-percent-sub').text(totalMapeado + ' de ' + totalAplicavel + ' aplicáveis');
            this.$el.find('.heatmap-oportunidades').text(totalOportunidades);
            this.$el.find('.heatmap-base').text(totalBase);
        },

        salvarLinha: function ($row) {
            var id = $row.attr('data-id');
            var payload = this.coletarPayloadLinha($row);
            var self = this;

            if (!id) {
                Espo.Ui.error('Registro do Heat Map sem ID.');
                return;
            }

            $row.addClass('heatmap-row-saving');

            Espo.Ajax.patchRequest('MapeamentoConta/' + id, payload)
                .then(function () {
                    self.atualizarItemLocal(id, payload);
                    self.atualizarResumoLocal();

                    $row.removeClass('heatmap-row-saving');
                    $row.addClass('heatmap-row-saved');

                    setTimeout(function () {
                        $row.removeClass('heatmap-row-saved');
                    }, 900);

                    self.carregarHeatMap();

                    Espo.Ui.success('Heat Map atualizado.');
                })
                .catch(function () {
                    $row.removeClass('heatmap-row-saving');
                    Espo.Ui.error('Não foi possível salvar o Heat Map.');
                });
        },

        setMensagem: function (msg) {
            this.$el.find('.heatmap-msg').text(msg || '');
        }
    });
});
