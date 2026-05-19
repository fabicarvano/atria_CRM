<?php

namespace Espo\Custom\Hooks\Opportunity;

use Espo\ORM\Entity;
use Espo\Core\Exceptions\BadRequest;

class ValidarPipelineOportunidade
{
    public static int $order = 9;

    /*
     * ATENÇÃO:
     * O EspoCRM exibe os nomes traduzidos na tela,
     * mas o campo stage usa valores internos no banco/metadata.
     *
     * Prospecting    = Prospectando
     * Qualification = Qualificação
     * Proposal      = Proposta
     * Negotiation   = Negociação
     * Closed Won    = Ganha
     * Closed Lost   = Perdida
     */

    private const STAGE_INICIAL = 'Prospecting';
    private const STAGE_PERDIDA = 'Closed Lost';

    private const MENSAGEM_TRANSICAO_INVALIDA =
        'Transição não permitida. Para manter a consistência do processo comercial, a oportunidade deve avançar sempre para a próxima fase do funil.';

    private const TRANSICOES_PERMITIDAS = [
        'Prospecting' => [
            'Qualification',
        ],
        'Qualification' => [
            'Desenvolvendo Solução',
        ],
        'Desenvolvendo Solução' => [
            'Proposal',
        ],
        'Proposal' => [
            'Negotiation',
        ],
        'Negotiation' => [
            'Closed Won',
        ],
    ];

    public function beforeSave(Entity $entity, array $options = []): void
    {
        /*
         * Toda nova oportunidade deve nascer obrigatoriamente em Prospectando.
         * Valor interno correto: Prospecting.
         */
        if ($entity->isNew()) {
            $entity->set('stage', self::STAGE_INICIAL);
            return;
        }

        if (!$entity->isAttributeChanged('stage')) {
            return;
        }

        $stageAnterior = (string) ($entity->getFetched('stage') ?? '');
        $stageNovo = (string) ($entity->get('stage') ?? '');

        if ($stageAnterior === '' || $stageNovo === '') {
            return;
        }

        if ($stageAnterior === $stageNovo) {
            return;
        }

        /*
         * Exceção:
         * Perdida pode sair de qualquer fase.
         * Valor interno correto: Closed Lost.
         */
        if ($stageNovo === self::STAGE_PERDIDA) {
            return;
        }

        $proximasEtapasPermitidas = self::TRANSICOES_PERMITIDAS[$stageAnterior] ?? [];

        if (in_array($stageNovo, $proximasEtapasPermitidas, true)) {
            return;
        }

        throw new BadRequest(self::MENSAGEM_TRANSICAO_INVALIDA);
    }
}
