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
        $stage = (string) ($entity->get('stage') ?? '');

        $this->validateQualification($entity, $stage);
        $this->validateDevelopmentSolutionBeforeProposal($entity, $stage);
    }

    private function validateQualification(Entity $entity, string $stage): void
    {
        $stagesThatRequireQualification = [
            'Desenvolvendo Solução',
            'Proposal',
            'Negotiation',
            'Closed Won',
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
            if (!$this->hasValue($entity->get($field))) {
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

    private function validateDevelopmentSolutionBeforeProposal(Entity $entity, string $stage): void
    {
        if ($stage !== 'Proposal') {
            return;
        }

        $previousStage = null;

        if (method_exists($entity, 'getFetched')) {
            $previousStage = $entity->getFetched('stage');
        }

        if ($previousStage !== 'Desenvolvendo Solução') {
            return;
        }

        $requiredFields = [
            'situacaoAtualSolucao' => 'Situação atual',
            'contextoSituacaoAtualSolucao' => 'Contexto da situação atual',
            'dorIdentificadaSolucao' => 'Dor identificada',
            'contextoDorSolucao' => 'Contexto da dor',
            'impactoNegocioSolucao' => 'Impacto no negócio',
            'contextoImpactoSolucao' => 'Contexto do impacto',
            'urgenciaSolucao' => 'Urgência',
            'fatoresUrgenciaSolucao' => 'Fatores de urgência',
            'criteriosDecisaoSolucao' => 'Critérios de decisão',
            'contextoCriteriosDecisaoSolucao' => 'Contexto dos critérios de decisão',
        ];

        $missingFields = [];

        foreach ($requiredFields as $field => $label) {
            if (!$this->hasValue($entity->get($field))) {
                $missingFields[] = $label;
            }
        }

        if (count($missingFields) === 0) {
            return;
        }

        throw new BadRequest(
            'Para avançar para Proposta, registre o Desenvolvimento da Solução. Preencha: ' .
            implode(', ', $missingFields) .
            '.'
        );
    }

    private function hasValue(mixed $value): bool
    {
        if (is_array($value)) {
            return count($value) > 0;
        }

        if ($value === null) {
            return false;
        }

        if (is_string($value) && trim($value) === '') {
            return false;
        }

        return true;
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
