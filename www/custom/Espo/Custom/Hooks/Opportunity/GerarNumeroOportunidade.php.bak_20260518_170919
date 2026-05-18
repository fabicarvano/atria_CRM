<?php

namespace Espo\Custom\Hooks\Opportunity;

use Espo\ORM\Entity;
use Espo\ORM\EntityManager;

class GerarNumeroOportunidade
{
    public static int $order = 6;

    private const ALLOWED_STAGES_FOR_SUFFIX_CHANGE = [
        'Prospectando',
        'Qualificando',
        'Prospecting',
        'Qualification',
        'prospectando',
        'qualificando'
    ];

    public function __construct(
        private EntityManager $entityManager
    ) {}

    public function beforeSave(Entity $entity, array $options): void
    {
        $oldNumber = (string) ($entity->get('numeroOportunidade') ?? '');

        if ($entity->isNew() || $oldNumber === '') {
            $entity->set('numeroOportunidade', $this->buildNewNumber($entity));
            return;
        }

        if (!$this->canUpdateSuffix($entity)) {
            return;
        }

        $newSuffix = $this->suffixFromTipo((string) ($entity->get('tipoOportunidade') ?? ''));

        if ($newSuffix === '') {
            return;
        }

        $newNumber = preg_replace('/\.[A-Z]{2}$/', '.' . $newSuffix, $oldNumber);

        if ($newNumber && $newNumber !== $oldNumber) {
            $entity->set('numeroOportunidade', $newNumber);
        }
    }

    public function afterSave(Entity $entity, array $options): void
    {
        $number = (string) ($entity->get('numeroOportunidade') ?? '');

        if ($number === '') {
            return;
        }

        $old = null;

        if (!$entity->isNew()) {
            $old = $this->entityManager->getEntityById('Opportunity', $entity->getId());
        }

        $fetchedNumber = null;

        if (method_exists($entity, 'getFetched')) {
            $fetchedNumber = $entity->getFetched('numeroOportunidade');
        }

        if (!$fetchedNumber && $old) {
            $fetchedNumber = $old->get('numeroOportunidade');
        }

        if ($entity->isNew() || !$fetchedNumber) {
            $this->postToStream(
                $entity,
                "Sistema gerou o número da oportunidade: {$number}"
            );
            return;
        }

        if ($fetchedNumber !== $number) {
            $oldSuffix = $this->extractSuffix((string) $fetchedNumber);
            $newSuffix = $this->extractSuffix($number);

            $this->postToStream(
                $entity,
                "Sistema atualizou o sufixo do número da oportunidade de {$oldSuffix} para {$newSuffix}, pois o Tipo de Oportunidade foi alterado."
            );
        }
    }

    private function buildNewNumber(Entity $entity): string
    {
        $accountId = (string) ($entity->get('accountId') ?? '');

        if ($accountId === '') {
            throw new \RuntimeException('Não foi possível gerar o número da oportunidade: a conta é obrigatória.');
        }

        $account = $this->entityManager->getEntityById('Account', $accountId);

        if (!$account) {
            throw new \RuntimeException('Não foi possível gerar o número da oportunidade: conta não encontrada.');
        }

        $sigla = (string) ($account->get('siglaConta') ?? '');

        if ($sigla === '') {
            throw new \RuntimeException('Não foi possível gerar o número da oportunidade: a conta não possui sigla.');
        }

        $year = date('Y');

        $sequence = $this->nextSequenceForAccount($accountId);

        $suffix = $this->suffixFromTipo((string) ($entity->get('tipoOportunidade') ?? ''));

        if ($suffix === '') {
            $suffix = 'PE';
        }

        return sprintf('%s-%s-%04d.%s', $sigla, $year, $sequence, $suffix);
    }

    private function nextSequenceForAccount(string $accountId): int
    {
        $list = $this->entityManager
            ->getRDBRepository('Opportunity')
            ->where(['accountId' => $accountId])
            ->find();

        $max = 0;

        foreach ($list as $item) {
            $number = (string) ($item->get('numeroOportunidade') ?? '');

            if (preg_match('/-(\d{4})\.[A-Z]{2}$/', $number, $m)) {
                $max = max($max, (int) $m[1]);
            }
        }

        return $max + 1;
    }

    private function suffixFromTipo(string $tipo): string
    {
        return match ($tipo) {
            'Revenda' => 'RR',
            'ServicoGerenciado' => 'SG',
            'ServicoPontual' => 'SP',
            'ProjetoEspecial' => 'PE',
            default => ''
        };
    }

    private function canUpdateSuffix(Entity $entity): bool
    {
        $stage = (string) ($entity->get('stage') ?? '');

        return in_array($stage, self::ALLOWED_STAGES_FOR_SUFFIX_CHANGE, true);
    }

    private function extractSuffix(string $number): string
    {
        if (preg_match('/\.([A-Z]{2})$/', $number, $m)) {
            return $m[1];
        }

        return '';
    }

    private function postToStream(Entity $entity, string $message): void
    {
        $note = $this->entityManager->getNewEntity('Note');

        $note->set([
            'type' => 'Post',
            'parentId' => $entity->getId(),
            'parentType' => 'Opportunity',
            'post' => $message
        ]);

        $this->entityManager->saveEntity($note, [
            'skipHooks' => true
        ]);
    }
}
