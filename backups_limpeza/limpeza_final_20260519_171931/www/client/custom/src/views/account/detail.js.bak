define(['views/detail'], (Dep) => {
    return class extends Dep {

        setup() {
            super.setup();

            const isFoco = !!this.model.get('statusProspeccao');

            this.addMenuItem('buttons', {
                name: 'marcarFoco',
                html: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="13" height="13" style="vertical-align:-1px;margin-right:5px"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/></svg>Alvo',
                style: 'default',
                hidden: isFoco,
                onClick: () => this._actionMarcarFoco()
            }, true);

            this.addMenuItem('buttons', {
                name: 'desmarcarFoco',
                html: '<svg viewBox="0 0 24 24" fill="none" stroke="#185FA5" stroke-width="1.8" width="13" height="13" style="vertical-align:-1px;margin-right:5px"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2" fill="#185FA5"/></svg><span style="color:#185FA5;font-weight:500">Foco</span>',
                style: 'default',
                hidden: !isFoco,
                onClick: () => this._actionDesmarcarFoco()
            }, true);

            this.listenTo(this.model, 'change:statusProspeccao', () => {
                this._controlFocoButtons();
                this._applyFieldCss();
            });

            this.listenTo(this, 'after:render', () => {
                this._applyFieldCss();
            });
        }

        _controlFocoButtons() {
            const isFoco = !!this.model.get('statusProspeccao');
            if (isFoco) {
                this.hideHeaderActionItem('marcarFoco');
                this.showHeaderActionItem('desmarcarFoco');
            } else {
                this.hideHeaderActionItem('desmarcarFoco');
                this.showHeaderActionItem('marcarFoco');
            }
        }

        _applyFieldCss() {
            const isFoco = !!this.model.get('statusProspeccao');

            // Injeta estilo global persistente
            let styleEl = document.getElementById('foco-field-style');
            if (!styleEl) {
                styleEl = document.createElement('style');
                styleEl.id = 'foco-field-style';
                document.head.appendChild(styleEl);
            }

            if (isFoco) {
                styleEl.textContent = `
                    .cell[data-name="porQueAlvo"] { display: none !important; }
                    .cell[data-name="porQueFoco"] { display: block !important; }
                `;
            } else {
                styleEl.textContent = `
                    .cell[data-name="porQueFoco"] { display: none !important; }
                    .cell[data-name="porQueAlvo"] { display: block !important; }
                `;
            }

            // Aplica inline também como dupla garantia
            const cellFoco = document.querySelector('.cell[data-name="porQueFoco"]');
            const cellAlvo = document.querySelector('.cell[data-name="porQueAlvo"]');

            if (cellFoco) cellFoco.style.setProperty('display', isFoco ? 'block' : 'none', 'important');
            if (cellAlvo) cellAlvo.style.setProperty('display', isFoco ? 'none' : 'block', 'important');
        }

        async _actionMarcarFoco() {
            const porQue = await this._askPorQueFoco();
            if (porQue === null) return;
            this.disableMenuItem('marcarFoco');
            try {
                await Espo.Ajax.patchRequest('Account/' + this.model.id, {
                    statusProspeccao: true,
                    porQueFoco: porQue
                });
                this.model.set('statusProspeccao', true, {sync: true});
                this.model.set('porQueFoco', porQue);
                Espo.Ui.success('Conta marcada como Foco.');
            } catch(e) {
                Espo.Ui.error('Erro ao salvar. Tente novamente.');
            }
            this.enableMenuItem('marcarFoco');
        }

        async _actionDesmarcarFoco() {
            const confirmed = await new Promise(resolve => {
                Espo.Ui.confirm(
                    'Remover status Foco? A conta voltara para Alvo.',
                    {confirmText: 'Confirmar', cancelText: 'Cancelar'},
                    () => resolve(true),
                    () => resolve(false)
                );
            });
            if (!confirmed) return;
            this.disableMenuItem('desmarcarFoco');
            try {
                await Espo.Ajax.patchRequest('Account/' + this.model.id, {
                    statusProspeccao: false
                });
                this.model.set('statusProspeccao', false, {sync: true});
                Espo.Ui.success('Conta voltou para Alvo.');
            } catch(e) {
                Espo.Ui.error('Erro ao salvar. Tente novamente.');
            }
            this.enableMenuItem('desmarcarFoco');
        }

        _askPorQueFoco() {
            return new Promise((resolve) => {
                const current = this.model.get('porQueFoco') || '';
                this.createView('dialog', 'views/modal', {
                    headerText: 'Por que e Foco?',
                    templateContent: `
                        <div class="form-group" style="margin:0">
                            <label class="control-label">
                                Motivo <span style="color:red">*</span>
                            </label>
                            <textarea id="porQueFocoInput"
                                class="form-control" rows="3"
                                placeholder="Ex: Decisor identificado, budget aprovado..."
                            >${current}</textarea>
                        </div>`,
                    buttonList: [
                        {
                            name: 'confirm',
                            label: 'Confirmar Foco',
                            style: 'primary',
                            onClick: (view) => {
                                const el = document.getElementById('porQueFocoInput');
                                const val = el ? el.value.trim() : '';
                                if (!val) { Espo.Ui.error('Informe o motivo.'); return; }
                                view.close();
                                resolve(val);
                            }
                        },
                        {
                            name: 'cancel',
                            label: 'Cancelar',
                            onClick: (view) => { view.close(); resolve(null); }
                        }
                    ]
                }, (view) => view.render());
            });
        }
    };
});
