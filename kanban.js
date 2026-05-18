/**
 * EscopoCRM — Kanban Oportunidades com soma de valores por coluna
 *
 * Caminho no servidor:
 *   /opt/atria/www/client/custom/src/views/opportunity/record/kanban.js
 */
define('custom:views/opportunity/record/kanban', ['crm:views/opportunity/record/kanban'], (Dep) => {

    return class extends Dep {

        afterRender() {
            super.afterRender();
            this._injectColumnTotals();
        }

        _injectColumnTotals() {
            if (!this.groupDataList || !this.groupDataList.length) return;

            // Injeta o CSS uma única vez na página
            if (!document.getElementById('kanban-total-style')) {
                const style = document.createElement('style');
                style.id = 'kanban-total-style';
                style.textContent = `
                    .kanban-column-total {
                        display: block;
                        font-size: 11px;
                        font-weight: 700;
                        opacity: 0.95;
                        margin-top: 2px;
                        white-space: nowrap;
                    }
                `;
                document.head.appendChild(style);
            }

            this.groupDataList.forEach(group => {
                let total    = 0;
                let currency = 'BRL';

                // Soma amount de todos os models da sub-collection deste grupo
                if (group.collection && group.collection.models) {
                    group.collection.models.forEach(model => {
                        total    += parseFloat(model.get('amount')) || 0;
                        currency  = model.get('amountCurrency') || currency;
                    });
                }

                const formatted = total.toLocaleString('pt-BR', {
                    style:                 'currency',
                    currency:              currency,
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                });

                // Seleciona o <th> do grupo pelo data-name e injeta o total
                const $th = this.$el.find(`th.group-header[data-name="${CSS.escape(group.name)}"]`);
                $th.find('.kanban-column-total').remove();
                $th.find('> div').first().append(
                    $(`<span class="kanban-column-total"></span>`).text(formatted)
                );
            });
        }
    };
});
