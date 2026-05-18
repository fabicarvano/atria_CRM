define(['crm:views/opportunity/record/kanban'], (Dep) => {

    return class extends Dep {

        afterRender() {
            super.afterRender();

            console.log('[Atria] Kanban custom de Opportunity carregado.');

            this._injectColumnTotals();
        }

        _injectColumnTotals() {
            if (!this.groupDataList || !this.groupDataList.length) {
                console.warn('[Atria] groupDataList não encontrado no Kanban.');
                return;
            }

            if (!document.getElementById('kanban-total-style')) {
                const style = document.createElement('style');
                style.id = 'kanban-total-style';
                style.textContent = `
                    .kanban-head th.group-header {
                        height: 38px;
                        padding: 5px 8px 6px 8px;
                        vertical-align: middle;
                    }

                    .kanban-head th.group-header > div {
                        display: flex;
                        flex-direction: column;
                        justify-content: center;
                        width: 100%;
                        min-height: 28px;
                    }

                    .kanban-head .kanban-group-label {
                        display: block;
                        width: 100%;
                        font-size: 13px;
                        font-weight: 700;
                        line-height: 14px;
                        overflow: hidden;
                        text-overflow: ellipsis;
                        white-space: nowrap;
                    }

                    .kanban-column-total {
                        display: block;
                        width: calc(100% - 10px);
                        margin-top: 4px;
                        margin-right: 10px;
                        font-size: 10.5px;
                        font-weight: 700;
                        line-height: 12px;
                        text-align: right;
                        color: rgba(255,255,255,0.96);
                        white-space: nowrap;
                    }

                    .kanban-head .create-button {
                        display: none;
                    }
                `;
                document.head.appendChild(style);
            }

            this.groupDataList.forEach(group => {
                let total = 0;
                let currency = 'BRL';

                if (group.collection && group.collection.models) {
                    group.collection.models.forEach(model => {
                        total += parseFloat(model.get('amount')) || 0;
                        currency = model.get('amountCurrency') || currency;
                    });
                }

                const formatted = total.toLocaleString('pt-BR', {
                    style: 'currency',
                    currency: currency,
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                });

                const groupName = group.name;

                const $th = this.$el.find(
                    'th.group-header[data-name="' + CSS.escape(groupName) + '"], th[data-name="' + CSS.escape(groupName) + '"]'
                );

                if (!$th.length) {
                    console.warn('[Atria] Cabeçalho não encontrado para grupo:', groupName);
                    return;
                }

                $th.find('.kanban-column-total').remove();

                const $headerDiv = $th.find('> div').first();

                if ($headerDiv.length) {
                    $headerDiv.append(
                        $('<span class="kanban-column-total"></span>').text(formatted)
                    );
                } else {
                    $th.append(
                        $('<span class="kanban-column-total"></span>').text(formatted)
                    );
                }
            });
        }

    };

});
