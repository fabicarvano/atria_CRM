#!/bin/bash

set -e

BASE_DIR="/opt/atria"
ARQUIVO="$BASE_DIR/www/client/custom/src/views/opportunity/record/detail-timeline.js"
BACKUP="$ARQUIVO.bak_visibilidade_devsol_$(date +%Y%m%d_%H%M%S)"

cd "$BASE_DIR"

echo "=================================================="
echo "Correção: visibilidade do bloco Desenvolvimento da Solução"
echo "=================================================="

if [ ! -f "$ARQUIVO" ]; then
  echo "ERRO: arquivo não encontrado:"
  echo "$ARQUIVO"
  exit 1
fi

echo
echo "=== 1. Contexto atual antes da alteração ==="
grep -n -C 5 "afterRender: function\|renderAtriaOpportunityTimeline\|escapeAtriaHtml" "$ARQUIVO" || true

echo
echo "=== 2. Criando backup ==="
cp -a "$ARQUIVO" "$BACKUP"
echo "Backup criado em:"
echo "$BACKUP"

echo
echo "=== 3. Aplicando correção automática ==="

python3 <<'PY'
from pathlib import Path

path = Path("/opt/atria/www/client/custom/src/views/opportunity/record/detail-timeline.js")
text = path.read_text()

if "controlarVisibilidadeDesenvolvimentoSolucao" in text:
    print("A função controlarVisibilidadeDesenvolvimentoSolucao já existe. Nenhuma duplicação será feita.")
else:
    old_after = """        afterRender: function () {
            Dep.prototype.afterRender.call(this);

            this.injectAtriaOpportunityTimelineStyle();
            this.renderAtriaOpportunityTimeline();

        },
"""

    new_after = """        afterRender: function () {
            Dep.prototype.afterRender.call(this);

            this.injectAtriaOpportunityTimelineStyle();
            this.renderAtriaOpportunityTimeline();

            this.controlarVisibilidadeDesenvolvimentoSolucao();

            var self = this;
            setTimeout(function () {
                self.controlarVisibilidadeDesenvolvimentoSolucao();
            }, 150);

            setTimeout(function () {
                self.controlarVisibilidadeDesenvolvimentoSolucao();
            }, 600);
        },
"""

    if old_after not in text:
        raise SystemExit("Não encontrei o bloco afterRender esperado. Abortando para não quebrar o arquivo.")

    text = text.replace(old_after, new_after)

    marker = """        escapeAtriaHtml: function (value) {"""

    insert = """        controlarVisibilidadeDesenvolvimentoSolucao: function () {
            var stage = this.model ? this.model.get('stage') : null;

            var stagesVisiveis = [
                'Desenvolvendo Solução',
                'Proposal',
                'Negotiation',
                'Closed Won',
                'Closed Lost'
            ];

            var deveMostrar = stagesVisiveis.indexOf(stage) !== -1;

            var campos = [
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

            var $root = this.$el || $(document);

            campos.forEach(function (campo) {
                var $nodes = $root.find(
                    '[data-name=\"' + campo + '\"], ' +
                    '[data-field-name=\"' + campo + '\"], ' +
                    '.field[data-name=\"' + campo + '\"]'
                );

                $nodes.each(function () {
                    var $node = $(this);
                    var $container = $node.closest('.cell');

                    if (!$container.length) {
                        $container = $node.closest('.form-group');
                    }

                    if (!$container.length) {
                        $container = $node.closest('[class*=\"col-\"]');
                    }

                    if (!$container.length) {
                        $container = $node;
                    }

                    if (deveMostrar) {
                        $container.show();
                    } else {
                        $container.hide();
                    }
                });
            });

            var titulos = [
                'Desenvolvimento da Solução',
                'Desenvolvimento da Solucao'
            ];

            $root.find('*').each(function () {
                var $el = $(this);
                var texto = ($el.clone().children().remove().end().text() || '').trim();

                if (titulos.indexOf(texto) === -1) {
                    return;
                }

                var $container = $el.closest('.panel-heading');

                if (!$container.length) {
                    $container = $el.closest('.row');
                }

                if (!$container.length) {
                    $container = $el.closest('.cell, .form-group, .col-sm-12, .col-md-12');
                }

                if (!$container.length) {
                    $container = $el.parent();
                }

                if (deveMostrar) {
                    $container.show();
                    $el.show();
                } else {
                    $container.hide();
                    $el.hide();
                }
            });
        },

"""

    if marker not in text:
        raise SystemExit("Não encontrei o ponto de inserção antes de escapeAtriaHtml. Abortando.")

    text = text.replace(marker, insert + marker)

    path.write_text(text)

print("Correção aplicada com sucesso.")
PY

echo
echo "=== 4. Contexto depois da alteração ==="
grep -n -C 5 "controlarVisibilidadeDesenvolvimentoSolucao\|afterRender: function" "$ARQUIVO" || true

echo
echo "=== 5. Limpando cache do EspoCRM ==="
php /opt/atria/www/command.php clear-cache

echo
echo "=== 6. Status do Git ==="
git status

echo
echo "=================================================="
echo "Correção concluída."
echo "Agora faça Ctrl + Shift + R no navegador."
echo "=================================================="
