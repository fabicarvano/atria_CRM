define('custom:views/opportunity/record/panels/registro-fabricante', ['view'], function (View) {

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
            this.controlarVisibilidade();
        },

        controlarVisibilidade: function () {
            const tipo = this.model.get('tipoOportunidade');
            const painel = this.$el.closest('.panel');

            if (tipo !== 'Revenda') {
                painel.hide();
                return;
            }

            painel.show();
            this.carregarRegistro();
        },

        getAjax: function () {
            if (typeof Espo !== 'undefined' && Espo.Ajax) {
                return Espo.Ajax;
            }

            return null;
        },

        carregarRegistro: function () {
            const opportunityId = this.model.id;

            if (!opportunityId) {
                this.setMensagem('Salve a oportunidade antes de registrar o RO.');
                return;
            }

            const ajax = this.getAjax();

            if (!ajax) {
                this.setMensagem('Erro: componente AJAX do EspoCRM não disponível.');
                return;
            }

            this.setMensagem('Carregando registro...');

            ajax.getRequest('RegistroFabricante', {
                maxSize: 1,
                sortBy: 'createdAt',
                asc: false,
                where: [
                    {
                        type: 'equals',
                        attribute: 'opportunityId',
                        value: opportunityId
                    }
                ]
            }).then(response => {
                const list = response && response.list ? response.list : [];

                if (!list.length) {
                    this.registroId = null;
                    this.registroData = null;

                    this.$el.find('.numero-ro').val('');
                    this.$el.find('.data-criacao').val('');
                    this.$el.find('.data-vencimento').val('');

                    this.setMensagem('Nenhum RO registrado ainda.');
                    return;
                }

                const item = list[0];

                this.registroId = item.id;
                this.registroData = item;

                this.$el.find('.numero-ro').val(item.numeroRo || '');
                this.$el.find('.data-criacao').val(item.dataCriacao || '');
                this.$el.find('.data-vencimento').val(item.dataVencimento || '');

                this.setMensagem('Registro carregado.');
            }).catch(error => {
                console.error('Erro ao carregar RegistroFabricante:', error);
                this.setMensagem('Não foi possível carregar o registro. Verifique permissões ou endpoint da entidade.');
            });
        },

        salvarRegistro: function () {
            const opportunityId = this.model.id;
            const opportunityName = this.model.get('name') || '';

            const numeroRo = (this.$el.find('.numero-ro').val() || '').trim();
            const dataVencimento = this.$el.find('.data-vencimento').val() || null;

            if (!opportunityId) {
                this.setMensagem('Salve a oportunidade antes de registrar o RO.');
                return;
            }

            const ajax = this.getAjax();

            if (!ajax) {
                this.setMensagem('Erro: componente AJAX do EspoCRM não disponível.');
                return;
            }

            const payload = {
                numeroRo: numeroRo,
                dataVencimento: dataVencimento,
                opportunityId: opportunityId,
                opportunityName: opportunityName
            };

            this.setMensagem('Salvando...');

            if (this.registroId) {
                ajax.putRequest('RegistroFabricante/' + this.registroId, payload)
                    .then(() => {
                        this.setMensagem('Registro atualizado com sucesso.');
                        this.carregarRegistro();
                    })
                    .catch(error => {
                        console.error('Erro ao atualizar RegistroFabricante:', error);
                        this.setMensagem('Erro ao atualizar o registro.');
                    });

                return;
            }

            ajax.postRequest('RegistroFabricante', payload)
                .then(() => {
                    this.setMensagem('Registro criado com sucesso.');
                    this.carregarRegistro();
                })
                .catch(error => {
                    console.error('Erro ao criar RegistroFabricante:', error);
                    this.setMensagem('Erro ao criar o registro.');
                });
        },

        setMensagem: function (mensagem) {
            this.$el.find('.registro-fabricante-msg').text(mensagem || '');
        }
    });
});
