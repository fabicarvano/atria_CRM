define('custom:views/opportunity/record/panels/registro-fabricante-v7', ['view'], function (View) {

    return View.extend({

        templateContent: `
            <div class="registro-fabricante-content">
                <div class="form-group">
                    <label>Número do RO</label>
                    <input type="text" class="form-control input-sm numero-ro" placeholder="Informe o número do RO">
                </div>

                <div class="form-group">
                    <label>Data de Criação</label>
                    <input type="date" class="form-control input-sm data-criacao" readonly>
                </div>

                <div class="form-group">
                    <label>Data de Vencimento</label>
                    <input type="date" class="form-control input-sm data-vencimento">
                </div>

                <div class="text-right registro-fabricante-actions">
                    <button type="button" class="btn btn-primary btn-sm salvar-registro-fabricante">
                        Salvar
                    </button>
                </div>

                <div class="registro-fabricante-msg text-muted small" style="margin-top: 8px;"></div>
            </div>
        `,

        events: {
            'click .salvar-registro-fabricante': function () {
                this.salvarRegistro();
            }
        },

        setup: function () {
            this.registroId = null;
            this.canEditNumeroRo = true;
            this.canEditDataVencimento = true;

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

        aplicarPermissao: function () {
            this.$el.find('.numero-ro').prop('readonly', !this.canEditNumeroRo);
            this.$el.find('.data-vencimento').prop('readonly', !this.canEditDataVencimento);

            var podeSalvar = this.canEditNumeroRo || this.canEditDataVencimento;

            this.$el.find('.salvar-registro-fabricante').toggle(!!podeSalvar);

            if (this.registroId && !this.canEditNumeroRo && this.canEditDataVencimento) {
                this.setMensagem('RO já criado. Você pode alterar apenas a Data de Vencimento.');
                return;
            }

            if (this.registroId && !this.canEditNumeroRo && !this.canEditDataVencimento) {
                this.setMensagem('RO já criado. Somente administrador ou o criador pode alterar a Data de Vencimento.');
                return;
            }
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

                    self.$el.find('.numero-ro').val('');
                    self.$el.find('.data-criacao').val('');
                    self.$el.find('.data-vencimento').val('');
                    self.setMensagem('Nenhum RO registrado ainda.');

                    self.aplicarPermissao();
                    return;
                }

                var item = response.record;

                self.registroId = item.id;

                self.$el.find('.numero-ro').val(item.numeroRo || '');
                self.$el.find('.data-criacao').val(item.dataCriacao || '');
                self.$el.find('.data-vencimento').val(item.dataVencimento || '');

                self.setMensagem('Registro carregado.');
                self.aplicarPermissao();
            }).fail(function (xhr) {
                console.error('Erro ao carregar RegistroFabricante:', xhr);
                self.setMensagem('Erro ao carregar registro. Código: ' + (xhr.status || 'sem código'));
            });
        },

        salvarRegistro: function () {
            var opportunityId = this.model.id;
            var opportunityName = this.model.get('name') || '';

            var numeroRo = (this.$el.find('.numero-ro').val() || '').trim();
            var dataVencimento = this.$el.find('.data-vencimento').val() || null;

            if (!opportunityId) {
                this.setMensagem('Salve a oportunidade antes de registrar o RO.');
                return;
            }

            if (this.registroId && !this.canEditNumeroRo && !this.canEditDataVencimento) {
                this.setMensagem('Você não tem permissão para alterar este RO.');
                return;
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

                    self.$el.find('.numero-ro').val(response.record.numeroRo || '');
                    self.$el.find('.data-criacao').val(response.record.dataCriacao || '');
                    self.$el.find('.data-vencimento').val(response.record.dataVencimento || '');
                }

                self.setMensagem('Registro salvo com sucesso.');
                self.aplicarPermissao();
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
