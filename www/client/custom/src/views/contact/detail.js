define(['views/detail'], (Dep) => {
    return class extends Dep {

        setup() {
            super.setup();
            // ── Botão Enriquecer LinkedIn ──────────────────────────
            const _isEnriq = !!this.model.get('enriquecidaLinkedin');
            this.addMenuItem('buttons', {
                name: 'enriquecerLinkedin',
                html: '<span style="font-weight:500">Enriquecer</span>',
                style: 'default',
                hidden: _isEnriq,
                onClick: () => this._actionEnriquecerLinkedin()
            }, true);
            this.addMenuItem('buttons', {
                name: 'enriquecidaLinkedin',
                html: '<span style="color:#64748b;font-weight:500">Enriquecido</span>',
                style: 'default',
                hidden: !_isEnriq,
                disabled: true
            }, true);
            this.listenTo(this.model, 'change:enriquecidaLinkedin', () => {
                this._controlEnriqButtons();
            });


            // Oculta o label e célula do linkedinPhotoUrl — a view custom já renderiza o avatar
            if (!document.getElementById('hide-contact-photo-label')) {
                const s = document.createElement('style');
                s.id = 'hide-contact-photo-label';
                s.textContent = [
                    'label[data-name="linkedinPhotoUrl"]',
                    '.cell[data-name="linkedinPhotoUrl"] > label.control-label'
                ].join(',') + ' { display: none !important; }';
                document.head.appendChild(s);
            }

            this.listenTo(this, 'after:render', () => {
                this._waitAndInjectAvatar();
            });
        }

        _waitAndInjectAvatar() {
            const target = document.querySelector('.record-grid .left .middle .panel');
            if (target) { this._injectAvatar(); return; }
            const observer = new MutationObserver(() => {
                const t = document.querySelector('.record-grid .left .middle .panel');
                if (t) { observer.disconnect(); this._injectAvatar(); }
            });
            observer.observe(document.body, { childList: true, subtree: true });
            setTimeout(() => observer.disconnect(), 5000);
        }

        _injectAvatar() {
            // O EspoCRM já carregou linkedinPhotoUrl porque está no layout
            // Apenas força re-render do campo que usa a view custom
            const fieldView = this.getFieldView('linkedinPhotoUrl');
            if (fieldView) {
                fieldView.reRender();
            }
        }

        _controlEnriqButtons() {
            const isEnriq = !!this.model.get('enriquecidaLinkedin');
            if (isEnriq) {
                this.hideHeaderActionItem('enriquecerLinkedin');
                this.showHeaderActionItem('enriquecidaLinkedin');
            } else {
                this.hideHeaderActionItem('enriquecidaLinkedin');
                this.showHeaderActionItem('enriquecerLinkedin');
            }
        }

        async _actionEnriquecerLinkedin() {
            const linkedinUrl = this.model.get('linkedinUrl') || '';
            if (this.model.get('enriquecidaLinkedin')) {
                Espo.Ui.warning('Este contato já foi enriquecido.');
                return;
            }
            if (!linkedinUrl) {
                Espo.Ui.error('Preencha o campo LinkedIn URL antes de enriquecer.');
                return;
            }
            const confirmed = await new Promise(resolve => {
                Espo.Ui.confirm(
                    'Enriquecer este contato com dados do LinkedIn?',
                    { confirmText: 'Enriquecer', cancelText: 'Cancelar' },
                    () => resolve(true),
                    () => resolve(false)
                );
            });
            if (!confirmed) return;
            this.disableMenuItem('enriquecerLinkedin');
            try {
                Espo.Ui.notify('Consultando LinkedIn...', 'warning');
                const result = await Espo.Ajax.postRequest('Contact/action/enriquecerLinkedin', {
                    id: this.model.id
                });
                const rec = result.record || {};
                this.model.set('enriquecidaLinkedin',        !!rec.enriquecidaLinkedin);
                this.model.set('headline',                   rec.headline                   || null);
                this.model.set('cargo',                      rec.cargo                      || null);
                this.model.set('linkedinPhotoUrl',           rec.linkedinPhotoUrl           || null);
                this.model.set('locationLinkedin',           rec.locationLinkedin           || null);
                this.model.set('isPremium',                  !!rec.isPremium);
                this.model.set('isCreator',                  !!rec.isCreator);
                this.model.set('isInfluencer',               !!rec.isInfluencer);
                this.model.set('nivelHierarquico',           rec.nivelHierarquico           || null);
                this.model.set('dataEnriquecimentoLinkedin', rec.dataEnriquecimentoLinkedin || null);
                this.model.set('fonteEnriquecimento',        rec.fonteEnriquecimento        || null);
                this._controlEnriqButtons();
                Espo.Ui.success(result.message || 'Contato enriquecido com sucesso.');
                this.reRender();
            } catch (e) {
                Espo.Ui.error('Não foi possível enriquecer o contato.');
                this.enableMenuItem('enriquecerLinkedin');
            }
        }

    };
});
