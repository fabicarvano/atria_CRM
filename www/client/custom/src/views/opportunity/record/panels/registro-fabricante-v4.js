define('custom:views/opportunity/record/panels/registro-fabricante-v4', ['view'], function (View) {

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

                <div class="text-right">
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
            this.registroData = null;

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

            var painel =
                $el.closest('.panel').length ? $el.closest('.panel') :
                $el.closest('.panel-default').length ? $el.closest('.panel-default') :
                $el.closest('.side-panel').length ? $el.closest('.side-panel') :
                $el.closest('.record-panel').length ? $el.closest('.record-panel') :
                $el.closest('[data-name="registroFabricante"]').length ? $el.closest('[data-name="registroFabricante"]') :
                $el.parent();

            return painel;
        },

        controlarVisibilidade: function () {
            var tipo = this.model.get('tipoOportunidade');
            var painel = this.getPainel();

            if (tipo !== 'Revenda') {
                painel.hide();
                return;
            }

            painel.show();
            this.carregarRegistro();
        },

        carregarRegistro: function () {
            var opportunityId = this.model.id;

            if (!opportunityId) {
                this.setMensagem('Salve a oportunidade antes de registrar o RO.');
                return;
            }

            var self = this;

            this.setMensagem('Carregando registro...');

            $.ajax({
                type: 'GET',
                url: 'api/v1/RegistroFabricante',
                dataType: 'json',
                data: {
                    maxSize: 1,
                    sortBy: 'createdAt',
                    asc: false,
                    where: JSON.stringify([
                        {
                            type: 'equals',
                            attribute: 'opportunityId',
                            value: opportunityId
                        }
                    ])
                },
                timeout: 10000
            }).done(function (response) {
                var list = response && response.list ? response.list : [];

                if (!list.length) {
                    self.registroId = null;
                    self.registroData = null;

                    self.$el.find('.numero-ro').val('');
                    self.$el.find('.data-criacao').val('');
                    self.$el.find('.data-vencimento').val('');

                    self.setMensagem('Nenhum RO registrado ainda.');
                    return;
                }

                var item = list[0];

                self.registroId = item.id;
                self.registroData = item;

                self.$el.find('.numero-ro').val(item.numeroRo || '');
                self.$el.find('.data-criacao').val(item.dataCriacao || '');
                self.$el.find('.data-vencimento').val(item.dataVencimento || '');

                self.setMensagem('Registro carregado.');
            }).fail(function (xhr, textStatus) {
                console.error('Erro ao carregar RegistroFabricante:', xhr, textStatus);

                if (textStatus === 'timeout') {
                    self.setMensagem('Tempo esgotado ao carregar o registro.');
                    return;
                }

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

            var payload = {
                numeroRo: numeroRo,
                dataVencimento: dataVencimento,
                opportunityId: opportunityId,
                opportunityName: opportunityName
            };

            var self = this;

            this.setMensagem('Salvando...');

            if (this.registroId) {
                $.ajax({
                    type: 'PUT',
                    url: 'api/v1/RegistroFabricante/' + this.registroId,
                    data: JSON.stringify(payload),
                    contentType: 'application/json',
                    dataType: 'json',
                    timeout: 10000
                }).done(function () {
                    self.setMensagem('Registro atualizado com sucesso.');
                    self.carregarRegistro();
                }).fail(function (xhr) {
                    console.error('Erro ao atualizar RegistroFabricante:', xhr);
                    self.setMensagem('Erro ao atualizar registro. Código: ' + (xhr.status || 'sem código'));
                });

                return;
            }

            $.ajax({
                type: 'POST',
                url: 'api/v1/RegistroFabricante',
                data: JSON.stringify(payload),
                contentType: 'application/json',
                dataType: 'json',
                timeout: 10000
            }).done(function () {
                self.setMensagem('Registro criado com sucesso.');
                self.carregarRegistro();
            }).fail(function (xhr) {
                console.error('Erro ao criar RegistroFabricante:', xhr);
                self.setMensagem('Erro ao criar registro. Código: ' + (xhr.status || 'sem código'));
            });
        },

        setMensagem: function (mensagem) {
            this.$el.find('.registro-fabricante-msg').text(mensagem || '');
        }
    });
});
