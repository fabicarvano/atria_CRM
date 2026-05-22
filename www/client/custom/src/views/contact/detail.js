define(['views/detail'], (Dep) => {
    return class extends Dep {

        setup() {
            super.setup();

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
    };
});
