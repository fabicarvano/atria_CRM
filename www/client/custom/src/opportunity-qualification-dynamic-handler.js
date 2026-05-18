define('custom:opportunity-qualification-dynamic-handler', ['dynamic-handler'], (Dep) => {

    return class extends Dep {

        init() {
            this.control();

            this.recordView.listenTo(this.model, 'change:stage', () => {
                this.control();
            });
        }

        control() {
            const stage = this.model.get('stage');

            const fields = [
                'dorPrincipal',
                'impactoEstimado',
                'orcamentoIdentificado',
                'criterioDecisao',
                'processoDecisao',
                'prazoDecisao'
            ];

            if (stage === 'Prospecting') {
                fields.forEach(field => {
                    this.recordView.hideField(field);
                    this.recordView.setFieldNotRequired(field);
                    this.recordView.setFieldReadOnly(field);
                });

                return;
            }

            if (stage === 'Qualification') {
                fields.forEach(field => {
                    this.recordView.showField(field);
                    this.recordView.setFieldNotRequired(field);
                    this.recordView.setFieldNotReadOnly(field);
                });

                return;
            }

            if (stage === 'Desenvolvendo Solução') {
                fields.forEach(field => {
                    this.recordView.showField(field);
                    this.recordView.setFieldRequired(field);
                    this.recordView.setFieldReadOnly(field);
                });

                return;
            }

            fields.forEach(field => {
                this.recordView.showField(field);
                this.recordView.setFieldNotRequired(field);
                this.recordView.setFieldReadOnly(field);
            });
        }
    };
});
