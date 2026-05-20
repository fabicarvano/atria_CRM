define('custom:views/account/record/panels/contas-similares', ['views/record/panels/bottom'], function (Dep) {
    return Dep.extend({

        templateContent: `
            <div class="contas-similares-wrapper">
                <div class="contas-similares-header"></div>
                <div class="contas-similares-msg text-muted">Carregando...</div>
                <div class="contas-similares-table-wrap hidden">
                    <table class="table contas-similares-table">
                        <thead>
                            <tr>
                                <th>Logo</th>
                                <th>Empresa</th>
                                <th>Indústria</th>
                                <th>Funcionários</th>
                                <th>LinkedIn</th>
                                <th>Ação</th>
                            </tr>
                        </thead>
                        <tbody class="contas-similares-body"></tbody>
                    </table>
                </div>
                <div class="contas-similares-pagination" style="margin-top:10px;"></div>
            </div>
        `,

        setup: function () {
            Dep.prototype.setup.call(this);
            this.items = [];
            this.summary = null;
        },

        afterRender: function () {
            Dep.prototype.afterRender.call(this);
            this.injectStyle();
            this.bindEvents();
            this.carregarContasSimilares();
        },

        bindEvents: function () {
            var self = this;
            this.$el.off('click.contasSimilaresCriar', '.conta-similar-criar');
            this.$el.on('click.contasSimilaresCriar', '.conta-similar-criar', function () {
                self.confirmarCriarConta($(this).attr('data-id'));
            });
        },

        carregarContasSimilares: function (page, pageSize) {
            page = page || 1;
            pageSize = pageSize || 20;
            var self = this;
            var enriquecida = !!this.model.get('enriquecidaLinkedin');

            if (!enriquecida) {
                this.setMsg('Esta conta ainda não foi enriquecida e não possui contas similares.');
                this.$el.find('.contas-similares-table-wrap').addClass('hidden');
                return;
            }

            this.setMsg('Carregando Contas Similares...');
            this.$el.find('.contas-similares-table-wrap').addClass('hidden');

            Espo.Ajax.postRequest('Account/action/listarContasSimilares', { id: this.model.id })
            .then(function (result) {
                self.items = result.list || [];
                self.totalCount = self.items.length;

                if (!self.items.length) {
                    self.setMsg('Nenhuma Conta Similar disponível para criação.');
                    return;
                }

                self.setMsg('Contas Similares Disponíveis: ' + self.totalCount);

                var start = (page - 1) * pageSize;
                var end = start + pageSize;
                self.renderTabela(self.items.slice(start, end));
                self.renderPagination(page, pageSize);
            })
            .catch(function () {
                self.setMsg('Não foi possível carregar as Contas Similares.');
                Espo.Ui.error('Não foi possível carregar as Contas Similares.');
            });
        },

        renderTabela: function (items) {
            var self = this;
            var $tbody = this.$el.find('.contas-similares-body');
            $tbody.empty();

            (items || []).forEach(function (item) {
                var logo = item.logoUrl
                    ? '<img class="conta-similar-logo" src="' + self.escapeHtml(item.logoUrl) + '"/>'
                    : '<div class="conta-similar-logo-placeholder">' + self.escapeHtml((item.name || '?').charAt(0)) + '</div>';
                var linkedin = item.linkedinUrl
                    ? '<a href="' + self.escapeHtml(item.linkedinUrl) + '" target="_blank">Abrir LinkedIn</a>'
                    : '-';
                var funcionarios = (function(item) {
                    if (item.employeeCountRangeStart && item.employeeCountRangeEnd) {
                        return item.employeeCountRangeStart.toLocaleString('pt-BR') +
                               ' – ' +
                               item.employeeCountRangeEnd.toLocaleString('pt-BR');
                    }
                    if (item.employeeCountRangeStart && !item.employeeCountRangeEnd) {
                        return item.employeeCountRangeStart.toLocaleString('pt-BR') + '+';
                    }
                    if (item.employeeCount) {
                        return item.employeeCount.toLocaleString('pt-BR');
                    }
                    return '-';
                })(item);

                var row = '<tr data-id="' + self.escapeHtml(item.id) + '">' +
                    '<td>' + logo + '</td>' +
                    '<td>' + self.escapeHtml(item.name || '-') + '</td>' +
                    '<td>' + self.escapeHtml(item.industry || '-') + '</td>' +
                    '<td>' + self.escapeHtml(String(funcionarios)) + '</td>' +
                    '<td>' + linkedin + '</td>' +
                    '<td><button type="button" class="btn btn-primary btn-xs conta-similar-criar" data-id="' + self.escapeHtml(item.id) + '">Criar Conta</button></td>' +
                    '</tr>';
                $tbody.append(row);
            });

            this.$el.find('.contas-similares-table-wrap').removeClass('hidden');
        },

        renderPagination: function (currentPage, pageSize) {
            var self = this;
            var totalPages = Math.ceil((self.items || []).length / pageSize);
            var $container = this.$el.find('.contas-similares-pagination');
            $container.empty();

            if (totalPages <= 1) return;

            for (var i = 1; i <= totalPages; i++) {
                var $btn = $('<button class="btn btn-xs btn-default" style="margin:1px;">' + i + '</button>');
                if (i === currentPage) $btn.addClass('active');
                (function (page) {
                    $btn.on('click', function () {
                        self.carregarContasSimilares(page, pageSize);
                    });
                })(i);
                $container.append($btn);
            }
        },

        confirmarCriarConta: function (id) {
            var item = (this.items || []).find(function (r) { return r.id === id; });
            if (!item) return Espo.Ui.error('Conta Similar não encontrada.');
            var self = this;
            Espo.Ui.confirm(
                'Deseja criar a conta "' + item.name + '" a partir desta Conta Similar?',
                { confirmText: 'Criar Conta', cancelText: 'Cancelar' },
                function () { self.criarContaSimilar(id); }
            );
        },

        criarContaSimilar: function (id) {
            var self = this;
            var $button = this.$el.find('.conta-similar-criar[data-id="' + id + '"]');
            $button.prop('disabled', true).text('Criando...');
            Espo.Ajax.postRequest('Account/action/criarContaSimilar', { similarId: id })
                .then(function (r) {
                    if (r && r.created) {
                        Espo.Ui.success(r.message || 'Conta criada.');
                    } else {
                        Espo.Ui.warning(r.message || 'A Conta Similar não pôde ser criada.');
                    }
                    self.carregarContasSimilares();
                })
                .catch(function () {
                    Espo.Ui.error('Não foi possível criar a Conta.');
                    $button.prop('disabled', false).text('Criar Conta');
                });
        },

        setMsg: function (msg) {
            this.$el.find('.contas-similares-msg').text(msg || '');
        },

        escapeHtml: function (v) {
            return String(v || '')
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#039;');
        },

        injectStyle: function () {
            if (document.getElementById('contas-similares-style')) return;
            var s = document.createElement('style');
            s.id = 'contas-similares-style';
            s.textContent = ".contas-similares-wrapper{padding:4px 0 10px}.contas-similares-table-wrap{border:1px solid #e5e7eb;border-radius:12px;overflow:hidden;background:#fff}.contas-similares-table thead th{background:#f8fafc;color:#475569;font-size:12px;font-weight:700;border-bottom:1px solid #e5e7eb}.contas-similares-table td{vertical-align:middle !important}.conta-similar-logo{width:36px;height:36px;border-radius:8px;object-fit:cover;border:1px solid #e5e7eb;background:#fff}.conta-similar-logo-placeholder{width:36px;height:36px;border-radius:8px;background:#f1f5f9;color:#475569;font-weight:700;display:flex;align-items:center;justify-content:center;border:1px solid #e5e7eb}";
            document.head.appendChild(s);
        }

    });
});
