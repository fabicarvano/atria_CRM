<?php

namespace Espo\Custom\Hooks\Opportunity;

use Espo\ORM\Entity;
use Espo\ORM\EntityManager;
use Espo\Core\Exceptions\BadRequest;

class ValidateQualificationBeforeStageAdvance
{
    public static int $order = 5;

    public function __construct(
        private EntityManager $entityManager
    ) {}

    public function beforeSave(Entity $entity, array $options): void
    {
        $stage = $entity->get('stage');

        $stagesThatRequireQualification = [
            'Desenvolvendo Solução',
            'Proposal',
            'Negotiation',
            'Closed Won',
            'Closed Lost',
        ];

        if (!in_array($stage, $stagesThatRequireQualification, true)) {
            return;
        }

        $missingFields = [];

        if (!$this->hasAtLeastOneContact($entity)) {
            $missingFields[] = 'Contato';
        }

        $requiredFields = [
            'dorPrincipal' => 'Dor principal',
            'impactoEstimado' => 'Impacto estimado',
            'orcamentoIdentificado' => 'Orçamento identificado',
            'criterioDecisao' => 'Critério de decisão',
            'processoDecisao' => 'Processo de decisão',
            'prazoDecisao' => 'Prazo de decisão',
        ];

        foreach ($requiredFields as $field => $label) {
            $value = $entity->get($field);

            if (is_array($value)) {
                if (count($value) === 0) {
                    $missingFields[] = $label;
                }

                continue;
            }

            if ($value === null || $value === '') {
                $missingFields[] = $label;
            }
        }

        if (count($missingFields) === 0) {
            return;
        }

        throw new BadRequest(
            'Para avançar a oportunidade a partir de Desenvolvendo Solução, preencha: ' .
            implode(', ', $missingFields) .
            '.'
        );
    }

    private function hasAtLeastOneContact(Entity $entity): bool
    {
        if (!$entity->getId()) {
            return false;
        }

        $contact = $this->entityManager
            ->getRelation($entity, 'contacts')
            ->limit(0, 1)
            ->findOne();

        return $contact !== null;
    }
}
