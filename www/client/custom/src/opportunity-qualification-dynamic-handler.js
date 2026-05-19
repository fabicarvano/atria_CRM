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

            const qualificationFields = [
                'dorPrincipal',
                'impactoEstimado',
                'orcamentoIdentificado',
                'criterioDecisao',
                'processoDecisao',
                'prazoDecisao'
            ];

            const developmentSolutionFields = [
                'situacaoAtualSolucao',
                'contextoSituacaoAtualSolucao',
                'dorIdentificadaSolucao',
                'contextoDorSolucao',
                'impactoNegocioSolucao',
                'contextoImpactoSolucao',
                'urgenciaSolucao',
                'fatoresUrgenciaSolucao',
                'criteriosDecisaoSolucao',
                'contextoCriteriosDecisaoSolucao'
            ];

            const developmentStages = [
                'Desenvolvendo Solução',
                'Proposal',
                'Negotiation',
                'Closed Won',
                'Closed Lost'
            ];

            this.controlQualificationFields(stage, qualificationFields, developmentStages);
            this.controlDevelopmentSolutionFields(stage, developmentSolutionFields, developmentStages);

            setTimeout(() => {
                this.toggleDevelopmentSolutionPanelTitle(stage, developmentStages);
            }, 50);
        }

        controlQualificationFields(stage, fields, developmentStages) {
            if (stage === 'Prospecting') {
                fields.forEach(field => {
                    this.recordView.hideField(field);
                    this.recordView.setFieldNotRequired(field);
                    this.recordView.setFieldNotReadOnly(field);
                });

                return;
            }

            fields.forEach(field => {
                this.recordView.showField(field);
                this.recordView.setFieldNotReadOnly(field);

                if (developmentStages.includes(stage)) {
                    this.recordView.setFieldRequired(field);
                } else {
                    this.recordView.setFieldNotRequired(field);
                }
            });
        }

        controlDevelopmentSolutionFields(stage, fields, developmentStages) {
            if (!developmentStages.includes(stage)) {
                fields.forEach(field => {
                    this.recordView.hideField(field);
                    this.recordView.setFieldNotRequired(field);
                    this.recordView.setFieldNotReadOnly(field);
                });

                return;
            }

            fields.forEach(field => {
                this.recordView.showField(field);
                this.recordView.setFieldNotRequired(field);
                this.recordView.setFieldNotReadOnly(field);
            });
        }
        toggleDevelopmentSolutionPanelTitle(stage, developmentStages) {
            const shouldShow = developmentStages.includes(stage);

            const $root =
                this.recordView && this.recordView.$el
                    ? this.recordView.$el
                    : $(document);

            const label = 'Desenvolvimento da Solução';

            const $labels = $root.find('*').filter(function () {
                const $el = $(this);
                const text = ($el.clone().children().remove().end().text() || '').trim();

                return text === label;
            });

            $labels.each(function () {
                const $label = $(this);

                let $container = $label.closest('.panel-heading');

                if (!$container.length) {
                    $container = $label.closest('.row');
                }

                if (!$container.length) {
                    $container = $label.closest('.cell, .form-group, .col-sm-12, .col-md-12');
                }

                if (!$container.length) {
                    $container = $label.parent();
                }

                if (!$container.length) {
                    $container = $label;
                }

                if (shouldShow) {
                    $container.show();
                    $label.show();
                } else {
                    $container.hide();
                    $label.hide();
                }
            });
        }

    };
});
