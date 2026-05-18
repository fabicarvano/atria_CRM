define('custom:views/opportunity/record/panels/registro-fabricante-v8', ['view'], function (View) {

    return View.extend({

        templateContent: `
            <div class="registro-fabricante-content ro-card-clean">
                <style>
                    .ro-card-clean .ro-field {
                        margin-bottom: 14px;
                    }

                    .ro-card-clean .ro-label {
                        color: #8f99a3;
                        font-size: 14px;
                        margin-bottom: 2px;
                    }

                    .ro-card-clean .ro-value-row {
                        display: flex;
                        align-items: center;
                        justify-content: space-between;
                        gap: 8px;
                    }

                    .ro-card-clean .ro-value {
                        color: #1f2933;
                        font-size: 14px;
                        line-height: 20px;
                        word-break: break-word;
                    }

                    .ro-card-clean .ro-empty {
                        color: #9aa3ad;
                    }

                    .ro-card-clean .ro-edit-icon {
                        color: #8f99a3;
                        cursor: pointer;
                        font-size: 13px;
                        text-decoration: none;
                        padding-left: 6px;
                    }

                    .ro-card-clean .ro-edit-icon:hover {
                        color: #4f79c7;
                        text-decoration: none;
                    }

                    .ro-card-clean .ro-edit-area {
                        margin-top: 6px;
                        display: none;
                    }

                    .ro-card-clean .ro-edit-actions {
                        margin-top: 6px;
                        text-align: right;
                    }

                    .ro-card-clean .ro-msg {
                        margin-top: 8px;
                        color: #8f99a3;
                        font-size: 12px;
                    }

                    .ro-card-clean input.form-control {
                        height: 32px;
                        font-size: 13px;
                    }
                </style>

                <div class="ro-field">
                    <div class="ro-label">Número do RO</div>
                    <div class="ro-value-row ro-read-numero">
                        <div class="ro-value numero-ro-text ro-empty">Nenhum</div>
                        <a href="javascript:" class="ro-edit-icon editar-numero-ro" title="Editar Número do RO">✎</a>
                    </div>
                    <div class="ro-edit-area ro-edit-numero-area">
                        <input type="text" class="form-control input-sm numero-ro-input" placeholder="Informe o número do RO">
                        <div class="ro-edit-actions">
                            <button type="button" class="btn btn-default btn-xs cancelar-numero-ro">Cancelar</button>
                            <button type="button" class="btn btn-primary btn-xs salvar-numero-ro">Salvar</button>
                        </div>
                    </div>
                </div>

                <div class="ro-field">
                    <div class="ro-label">Criado em</div>
                    <div class="ro-value data-criacao-text ro-empty">Nenhum</div>
                </div>

                <div class="ro-field">
                    <div class="ro-label">Modificado em</div>
                    <div class="ro-value data-modificacao-text ro-empty">Nenhum</div>
                </div>

                <div class="ro-field">
                    <div class="ro-label">Data de Vencimento</div>
                    <div class="ro-value-row ro-read-vencimento">
                        <div class="ro-value data-vencimento-text ro-empty">Nenhum</div>
                        <a href="javascript:" class="ro-edit-icon editar-data-vencimento" title="Editar Data de Vencimento">✎</a>
                    </div>
                    <div class="ro-edit-area ro-edit-vencimento-area">
                        <input type="date" class="form-control input-sm data-vencimento-input">
                        <div class="ro-edit-actions">
                            <button type="button" class="btn btn-default btn-xs cancelar-data-vencimento">Cancelar</button>
                            <button type="button" class="btn btn-primary btn-xs salvar-data-vencimento">Salvar</button>
                        </div>
                    </div>
                </div>

                <div class="ro-msg registro-fabricante-msg"></div>
            </div>
        `,

        events: {
            'click .editar-numero-ro': function () {
                this.abrirEdicaoNumero();
            },
            'click .cancelar-numero-ro': function () {
                this.fecharEdicaoNumero();
            },
            'click .salvar-numero-ro': function () {
                this.salvarRegistro('numero');
            },
            'click .editar-data-vencimento': function () {
                this.abrirEdicaoVencimento();
            },
            'click .cancelar-data-vencimento': function () {
                this.fecharEdicaoVencimento();
            },
            'click .salvar-data-vencimento': function () {
                this.salvarRegistro('vencimento');
            }
        },

        setup: function () {
            this.registroId = null;
            this.canEditNumeroRo = true;
            this.canEditDataVencimento = true;

            this.numeroRo = '';
            this.dataCriacao = '';
            this.dataVencimento = '';
            this.modifiedAt = '';

            this.listenTo(this.model, 'change:tipoOportunidade', function () {
                this.controlarVisibilidade();
            });
        },

        afterRender: function () {
            var self = this;

            setTimeout(function () {
                self.controlarVisibilidade();
            }, 100);
        },

        getPainel: function () {
            var $el = this.$el;

            return $el.closest('.panel').length ? $el.closest('.panel') : $el.parent();
        },

        controlarVisibilidade: function () {
            var painel = this.getPainel();

            if (this.model.get('tipoOportunidade') !== 'Revenda') {
                painel.hide();
                return;
            }

            painel.show();
            this.carregarRegistro();
        },

        formatarData: function (valor) {
            if (!valor) {
                return 'Nenhum';
            }

            var somenteData = String(valor).split(' ')[0].split('T')[0];
            var partes = somenteData.split('-');

            if (partes.length !== 3) {
                return valor;
            }

            return partes[2] + '/' + partes[1] + '/' + partes[0];
        },

        aplicarTexto: function ($el, valor) {
            $el.text(valor || 'Nenhum');

            if (!valor || valor === 'Nenhum') {
                $el.addClass('ro-empty');
            } else {
                $el.removeClass('ro-empty');
            }
        },

        atualizarTela: function () {
            this.aplicarTexto(this.$el.find('.numero-ro-text'), this.numeroRo || 'Nenhum');
            this.aplicarTexto(this.$el.find('.data-criacao-text'), this.formatarData(this.dataCriacao));
            this.aplicarTexto(this.$el.find('.data-modificacao-text'), this.formatarData(this.modifiedAt));
            this.aplicarTexto(this.$el.find('.data-vencimento-text'), this.formatarData(this.dataVencimento));

            this.$el.find('.numero-ro-input').val(this.numeroRo || '');
            this.$el.find('.data-vencimento-input').val(this.dataVencimento || '');

            this.$el.find('.editar-numero-ro').toggle(!!this.canEditNumeroRo);
            this.$el.find('.editar-data-vencimento').toggle(!!this.canEditDataVencimento);

            this.fecharEdicaoNumero();
            this.fecharEdicaoVencimento();
        },

        abrirEdicaoNumero: function () {
            if (!this.canEditNumeroRo) {
                this.setMensagem('Somente administrador pode alterar o Número do RO.');
                return;
            }

            this.$el.find('.ro-read-numero').hide();
            this.$el.find('.ro-edit-numero-area').show();
            this.$el.find('.numero-ro-input').focus();
        },

        fecharEdicaoNumero: function () {
            this.$el.find('.ro-edit-numero-area').hide();
            this.$el.find('.ro-read-numero').show();
            this.$el.find('.numero-ro-input').val(this.numeroRo || '');
        },

        abrirEdicaoVencimento: function () {
            if (!this.canEditDataVencimento) {
                this.setMensagem('Você não tem permissão para alterar a Data de Vencimento.');
                return;
            }

            this.$el.find('.ro-read-vencimento').hide();
            this.$el.find('.ro-edit-vencimento-area').show();
            this.$el.find('.data-vencimento-input').focus();
        },

        fecharEdicaoVencimento: function () {
            this.$el.find('.ro-edit-vencimento-area').hide();
            this.$el.find('.ro-read-vencimento').show();
            this.$el.find('.data-vencimento-input').val(this.dataVencimento || '');
        },

        carregarRegistro: function () {
            var opportunityId = this.model.id;
            var self = this;

            if (!opportunityId) {
                this.setMensagem('Salve a oportunidade antes de registrar o RO.');
                return;
            }

            this.setMensagem('Carregando registro...');

            $.ajax({
                type: 'GET',
                url: 'api/v1/RegistroFabricante/action/getByOpportunity',
                dataType: 'json',
                data: {
                    opportunityId: opportunityId
                },
                timeout: 10000
            }).done(function (response) {
                self.canEditNumeroRo = !!(response && response.canEditNumeroRo);
                self.canEditDataVencimento = !!(response && response.canEditDataVencimento);

                if (!response || !response.found || !response.record) {
                    self.registroId = null;
                    self.numeroRo = '';
                    self.dataCriacao = '';
                    self.dataVencimento = '';
                    self.modifiedAt = '';

                    self.setMensagem('Nenhum RO registrado ainda.');
                    self.atualizarTela();
                    return;
                }

                var item = response.record;

                self.registroId = item.id;
                self.numeroRo = item.numeroRo || '';
                self.dataCriacao = item.dataCriacao || '';
                self.dataVencimento = item.dataVencimento || '';
                self.modifiedAt = item.modifiedAt || item.createdAt || '';

                self.setMensagem('');
                self.atualizarTela();
            }).fail(function (xhr) {
                console.error('Erro ao carregar RegistroFabricante:', xhr);
                self.setMensagem('Erro ao carregar registro. Código: ' + (xhr.status || 'sem código'));
            });
        },

        salvarRegistro: function (campo) {
            var opportunityId = this.model.id;
            var opportunityName = this.model.get('name') || '';

            if (!opportunityId) {
                this.setMensagem('Salve a oportunidade antes de registrar o RO.');
                return;
            }

            if (campo === 'numero' && !this.canEditNumeroRo) {
                this.setMensagem('Somente administrador pode alterar o Número do RO.');
                return;
            }

            if (campo === 'vencimento' && !this.canEditDataVencimento) {
                this.setMensagem('Você não tem permissão para alterar a Data de Vencimento.');
                return;
            }

            var numeroRo = this.numeroRo || '';
            var dataVencimento = this.dataVencimento || null;

            if (campo === 'numero') {
                numeroRo = (this.$el.find('.numero-ro-input').val() || '').trim();
            }

            if (campo === 'vencimento') {
                dataVencimento = this.$el.find('.data-vencimento-input').val() || null;
            }

            var payload = {
                id: this.registroId,
                numeroRo: numeroRo,
                dataVencimento: dataVencimento,
                opportunityId: opportunityId,
                opportunityName: opportunityName
            };

            var self = this;

            this.setMensagem('Salvando...');

            $.ajax({
                type: 'POST',
                url: 'api/v1/RegistroFabricante/action/saveForOpportunity',
                data: JSON.stringify(payload),
                contentType: 'application/json',
                dataType: 'json',
                timeout: 10000
            }).done(function (response) {
                self.canEditNumeroRo = !!(response && response.canEditNumeroRo);
                self.canEditDataVencimento = !!(response && response.canEditDataVencimento);

                if (response && response.record) {
                    self.registroId = response.record.id;
                    self.numeroRo = response.record.numeroRo || '';
                    self.dataCriacao = response.record.dataCriacao || '';
                    self.dataVencimento = response.record.dataVencimento || '';
                    self.modifiedAt = response.record.modifiedAt || response.record.createdAt || '';
                }

                self.setMensagem('Registro salvo com sucesso.');
                self.atualizarTela();
            }).fail(function (xhr) {
                console.error('Erro ao salvar RegistroFabricante:', xhr);

                if (xhr.status === 403) {
                    self.setMensagem('Sem permissão para alterar este campo do RO.');
                    self.carregarRegistro();
                    return;
                }

                self.setMensagem('Erro ao salvar registro. Código: ' + (xhr.status || 'sem código'));
            });
        },

        setMensagem: function (mensagem) {
            this.$el.find('.registro-fabricante-msg').text(mensagem || '');
        }
    });
});
