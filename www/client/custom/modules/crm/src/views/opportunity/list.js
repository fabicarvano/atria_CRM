/**
 * EscopoCRM — Customização Kanban Oportunidades
 * Exibe a soma de "amount" (Valor) no cabeçalho de cada coluna do Kanban.
 *
 * Arquivo: client/custom/modules/crm/src/views/opportunity/list.js
 * No servidor: /opt/espocrm/www/client/custom/modules/crm/src/views/opportunity/list.js
 */

define('custom:crm/views/opportunity/list', ['crm/views/opportunity/list'], function (Dep) {

    return Dep.extend({

        /**
         * Após o Kanban renderizar, calcula e exibe a soma por coluna.
         */
        afterRender: function () {
            Dep.prototype.afterRender.call(this);
            this.listenToOnce(this, 'after:render', this._injectColumnTotals.bind(this));
            // Também recalcula quando registros são carregados/arrastados
            this.listenTo(this, 'collection-fetched', this._injectColumnTotals.bind(this));
        },

        /**
         * Calcula a soma de "amount" por grupo (stage) e injeta no header de cada coluna.
         */
        _injectColumnTotals: function () {
            var self = this;

            // Aguarda o sub-view do record (kanban) estar disponível
            var recordView = this.getView('list');
            if (!recordView) {
                // Tenta novamente após pequeno delay (render assíncrono)
                setTimeout(function () {
                    self._injectColumnTotals();
                }, 300);
                return;
            }

            var collection = recordView.collection || this.collection;
            if (!collection) return;

            // -------------------------------------------------------
            // 1. Agrupa os models por estágio e soma os valores
            // -------------------------------------------------------
            var totals = {};   // { stageName: totalAmount }
            var currency = null;

            collection.models.forEach(function (model) {
                var stage  = model.get('stage') || '';
                var amount = parseFloat(model.get('amount')) || 0;
                currency   = currency || model.get('amountCurrency') || 'BRL';

                if (!totals[stage]) totals[stage] = 0;
                totals[stage] += amount;
            });

            // -------------------------------------------------------
            // 2. Formata o valor como moeda brasileira
            // -------------------------------------------------------
            function formatBRL(value) {
                return value.toLocaleString('pt-BR', {
                    style: 'currency',
                    currency: currency || 'BRL',
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                });
            }

            // -------------------------------------------------------
            // 3. Injeta no DOM de cada coluna do kanban
            // -------------------------------------------------------
            //
            // O template do EspoCRM gera headers com:
            //   <th data-name="{stageName}" class="group-header ...">
            //     <div>
            //       <span class="kanban-group-label">Prospectando</span>
            //       ...
            //     </div>
            //   </th>
            //
            // Injetamos um <div class="kanban-column-total"> logo abaixo do label.
            //
            self.$el.find('th[data-name]').each(function () {
                var $th    = Espo.Ui.$(this);
                var stage  = $th.data('name');
                var total  = totals[stage] || 0;
                var formatted = formatBRL(total);

                // Remove total anterior (evita duplicar ao recarregar)
                $th.find('.kanban-column-total').remove();

                var $totalEl = Espo.Ui.$('<div class="kanban-column-total"></div>').text(formatted);
                $th.find('> div').first().append($totalEl);
            });

            // -------------------------------------------------------
            // 4. Estilos inline (fallback caso CSS não seja carregado)
            // -------------------------------------------------------
            if (!document.getElementById('kanban-total-style')) {
                var style = document.createElement('style');
                style.id  = 'kanban-total-style';
                style.textContent = [
                    '.kanban-column-total {',
                    '    font-size: 12px;',
                    '    font-weight: 600;',
                    '    opacity: 0.85;',
                    '    margin-top: 2px;',
                    '    letter-spacing: 0.01em;',
                    '}'
                ].join('\n');
                document.head.appendChild(style);
            }
        }

    });
});
