define('custom:views/account/record/panels/contatos-executivos', ['views/record/panels/bottom'], function (Dep) {
    return Dep.extend({

        templateContent: `
            <div class="ce-wrapper">
                <div class="ce-header"></div>
                <div class="ce-msg text-muted">Carregando...</div>
                <div class="ce-table-wrap hidden">
                    <table class="table ce-table">
                        <thead>
                            <tr>
                                <th style="width:44px">Foto</th>
                                <th>Nome</th>
                                <th>Cargo</th>
                                <th>Localização</th>
                                <th style="width:90px">LinkedIn</th>
                                <th style="width:110px">Ação</th>
                            </tr>
                        </thead>
                        <tbody class="ce-body"></tbody>
                    </table>
                </div>
                <div class="ce-pagination" style="margin-top:10px;"></div>
            </div>
        `,

        setup: function () {
            Dep.prototype.setup.call(this);
            this.items = [];

            // Recarrega quando o enriquecimento ocorre na mesma sessão
            this.listenTo(this.model, 'change:enriquecidaLinkedin', function () {
                this.carregarContatos();
            });
        },

        afterRender: function () {
            Dep.prototype.afterRender.call(this);
            this.injectStyle();
            this.bindEvents();
            // Garante que enriquecidaLinkedin está carregado no model
            var self = this;
            if (this.model.get('enriquecidaLinkedin') === undefined) {
                this.model.fetch().then(function () {
                    self.carregarContatos();
                });
            } else {
                this.carregarContatos();
            }
        },

        bindEvents: function () {
            var self = this;
            this.$el.off('click.ceCriar', '.ce-criar');
            this.$el.on('click.ceCriar', '.ce-criar', function () {
                self.confirmarCriarContato($(this).attr('data-id'));
            });
        },

        carregarContatos: function (page, pageSize) {
            page     = page     || 1;
            pageSize = pageSize || 20;
            var self        = this;
            var enriquecida = !!this.model.get('enriquecidaLinkedin');

            if (!enriquecida) {
                this.$el.find('.ce-table-wrap').addClass('hidden');
                this.$el.find('.ce-pagination').empty();
                this.setMsg('Esta conta ainda não foi enriquecida. Clique em <strong>Enriquecer</strong> para buscar decisores de TI no LinkedIn.', true);
                return;
            }

            this.setMsg('Carregando Contatos Executivos...');
            this.$el.find('.ce-table-wrap').addClass('hidden');

            Espo.Ajax.postRequest('Account/action/listarContatosExecutivos', { id: this.model.id })
                .then(function (result) {
                    self.items = result.list || [];

                    if (!self.items.length) {
                        self.setMsg('Nenhum Contato Executivo encontrado para esta conta.');
                        return;
                    }

                    var disponiveis = (result.summary || {}).disponiveis || 0;
                    var jaExistem   = (result.summary || {}).jaExistem   || 0;
                    var jaCriados   = (result.summary || {}).jaCriados   || 0;

                    var msg = 'Contatos Executivos: <strong>' + self.items.length + '</strong>';
                    if (disponiveis > 0) msg += ' &nbsp;|&nbsp; <span style="color:#16a34a">Disponíveis: ' + disponiveis + '</span>';
                    if (jaExistem > 0)   msg += ' &nbsp;|&nbsp; <span style="color:#2563eb">Já no CRM: ' + jaExistem + '</span>';
                    if (jaCriados > 0)   msg += ' &nbsp;|&nbsp; <span style="color:#7c3aed">Criados: ' + jaCriados + '</span>';
                    self.setMsg(msg, true);

                    var start = (page - 1) * pageSize;
                    var end   = start + pageSize;
                    self.renderTabela(self.items.slice(start, end));
                    self.renderPagination(page, pageSize);
                })
                .catch(function () {
                    self.setMsg('Não foi possível carregar os Contatos Executivos.');
                    Espo.Ui.error('Não foi possível carregar os Contatos Executivos.');
                });
        },

        renderTabela: function (items) {
            var self  = this;
            var $tbody = this.$el.find('.ce-body');
            $tbody.empty();

            (items || []).forEach(function (item) {
                var foto = item.pictureUrl
                    ? '<img class="ce-foto" src="' + self.esc(item.pictureUrl) + '" />'
                    : '<div class="ce-foto-placeholder">' + self.esc((item.firstName || item.name || '?').charAt(0).toUpperCase()) + '</div>';

                var linkedin = item.linkedinUrl
                    ? '<a href="' + self.esc(item.linkedinUrl) + '" target="_blank" title="Abrir LinkedIn" style="display:inline-flex;align-items:center">' +
                      '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="#0a66c2">' +
                      '<path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 0 1-2.063-2.065 2.064 2.064 0 1 1 2.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>' +
                      '</svg></a>'
                    : '-';

                var acao = '';
                if (item.isCreated) {
                    // Já foi criado via botão — mostra link para o Contact
                    acao = '<span class="badge" style="background:#7c3aed;color:#fff;padding:3px 8px;border-radius:6px;font-size:11px">Criado</span>';
                } else if (item.existsInCrm) {
                    // Já existe no CRM — encontrado por match
                    acao = '<span class="badge" style="background:#2563eb;color:#fff;padding:3px 8px;border-radius:6px;font-size:11px">No CRM</span>';
                } else {
                    // Disponível para criar
                    acao = '<button type="button" class="btn btn-primary btn-xs ce-criar" data-id="' + self.esc(item.id) + '">Criar Contato</button>';
                }

                var premium = item.premium
                    ? ' <span title="LinkedIn Premium" style="color:#c4930a;font-size:10px">★</span>'
                    : '';

                var openToWork = item.openToWork
                    ? ' <span title="Aberto a oportunidades" style="color:#16a34a;font-size:10px">●</span>'
                    : '';

                var row = '<tr data-id="' + self.esc(item.id) + '">' +
                    '<td>' + foto + '</td>' +
                    '<td><strong>' + self.esc(item.name || '-') + '</strong>' + premium + openToWork + '</td>' +
                    '<td>' + self.esc(item.cargo || item.headline || '-') + '</td>' +
                    '<td style="font-size:12px;color:#64748b">' + self.esc(item.location || '-') + '</td>' +
                    '<td style="text-align:center">' + linkedin + '</td>' +
                    '<td>' + acao + '</td>' +
                    '</tr>';

                $tbody.append(row);
            });

            this.$el.find('.ce-table-wrap').removeClass('hidden');
        },

        renderPagination: function (currentPage, pageSize) {
            var self       = this;
            var totalPages = Math.ceil((self.items || []).length / pageSize);
            var $container = this.$el.find('.ce-pagination');
            $container.empty();

            if (totalPages <= 1) return;

            for (var i = 1; i <= totalPages; i++) {
                var $btn = $('<button class="btn btn-xs btn-default" style="margin:1px;">' + i + '</button>');
                if (i === currentPage) $btn.addClass('active');
                (function (p) {
                    $btn.on('click', function () {
                        self.carregarContatos(p, pageSize);
                    });
                })(i);
                $container.append($btn);
            }
        },

        confirmarCriarContato: function (id) {
            var item = (this.items || []).find(function (r) { return r.id === id; });
            if (!item) return Espo.Ui.error('Contato Executivo não encontrado.');
            var self = this;
            Espo.Ui.confirm(
                'Deseja criar o contato "' + item.name + '" (' + (item.cargo || item.headline || '') + ') vinculado a esta conta?',
                { confirmText: 'Criar Contato', cancelText: 'Cancelar' },
                function () { self.criarContato(id); }
            );
        },

        criarContato: function (id) {
            var self    = this;
            var $button = this.$el.find('.ce-criar[data-id="' + id + '"]');
            $button.prop('disabled', true).text('Criando...');

            Espo.Ajax.postRequest('Account/action/criarContatoExecutivo', { executivoId: id })
                .then(function (r) {
                    if (r && r.created) {
                        Espo.Ui.success(r.message || 'Contato criado com sucesso.');
                    } else {
                        Espo.Ui.warning(r.message || 'O contato não pôde ser criado.');
                    }
                    self.carregarContatos();
                })
                .catch(function () {
                    Espo.Ui.error('Não foi possível criar o contato.');
                    $button.prop('disabled', false).text('Criar Contato');
                });
        },

        setMsg: function (msg, isHtml) {
            var $el = this.$el.find('.ce-msg');
            if (isHtml) {
                $el.html(msg || '');
            } else {
                $el.text(msg || '');
            }
        },

        esc: function (v) {
            return String(v || '')
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#039;');
        },

        injectStyle: function () {
            if (document.getElementById('ce-style')) return;
            var s = document.createElement('style');
            s.id = 'ce-style';
            s.textContent = [
                '.ce-wrapper{padding:4px 0 10px}',
                '.ce-msg{margin-bottom:8px;font-size:13px}',
                '.ce-table-wrap{border:1px solid #e5e7eb;border-radius:12px;overflow:hidden;background:#fff}',
                '.ce-table thead th{background:#f8fafc;color:#475569;font-size:12px;font-weight:700;border-bottom:1px solid #e5e7eb;padding:8px 10px}',
                '.ce-table td{vertical-align:middle !important;padding:6px 10px}',
                '.ce-foto{width:36px;height:36px;border-radius:50%;object-fit:cover;border:1px solid #e5e7eb;background:#fff}',
                '.ce-foto-placeholder{width:36px;height:36px;border-radius:50%;background:#e0e7ff;color:#3730a3;font-weight:700;font-size:15px;display:flex;align-items:center;justify-content:center;border:1px solid #c7d2fe}',
            ].join('');
            document.head.appendChild(s);
        }

    });
});
