<?php

namespace Espo\Custom\Hooks\Account;

use Espo\ORM\Entity;
use Espo\ORM\EntityManager;

class GerarSiglaConta
{
    public static int $order = 5;

    public function __construct(
        private EntityManager $entityManager
    ) {}

    public function beforeSave(Entity $entity, array $options): void
    {
        $current = (string) ($entity->get('siglaConta') ?? '');

        if (!$entity->isNew()) {
            $old = $this->entityManager->getEntityById('Account', $entity->getId());

            if ($old && $old->get('siglaConta')) {
                $entity->set('siglaConta', $old->get('siglaConta'));
                return;
            }
        }

        if ($current !== '') {
            $entity->set('siglaConta', strtoupper(substr($current, 0, 5)));
            return;
        }

        $name = (string) ($entity->get('name') ?? '');

        $entity->set('siglaConta', $this->generateUniqueSigla($name, $entity->getId()));
    }

    private function generateUniqueSigla(string $name, ?string $currentId = null): string
    {
        $base = $this->makeBaseSigla($name);

        if ($base === '') {
            $base = 'CTA';
        }

        $base = substr($base, 0, 5);

        if ($this->isSiglaAvailable($base, $currentId)) {
            return $base;
        }

        for ($i = 1; $i <= 99; $i++) {
            $suffix = str_pad((string) $i, 2, '0', STR_PAD_LEFT);
            $candidate = substr($base, 0, 3) . $suffix;

            if ($this->isSiglaAvailable($candidate, $currentId)) {
                return $candidate;
            }
        }

        return substr($base, 0, 2) . strtoupper(substr(md5($name . microtime(true)), 0, 3));
    }

    private function makeBaseSigla(string $name): string
    {
        $name = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $name);
        $name = strtoupper($name ?: '');
        $name = preg_replace('/[^A-Z0-9 ]/', ' ', $name);
        $name = preg_replace('/\s+/', ' ', trim($name));

        $ignore = [
            'SA', 'S', 'A', 'LTDA', 'LTD', 'ME', 'EPP', 'EIRELI', 'SPE',
            'BRASIL', 'BRAZIL', 'HOLDING', 'PARTICIPACOES', 'PARTICIPACOES'
        ];

        $words = array_values(array_filter(explode(' ', $name), function ($word) use ($ignore) {
            return $word !== '' && !in_array($word, $ignore, true);
        }));

        if (!$words) {
            return '';
        }

        $first = $words[0];

        $manual = [
            'BRADESCO' => 'BRA',
            'PETROBRAS' => 'PETRO',
            'TRANSPETRO' => 'TRANS',
            'GLOBO' => 'GLB'
        ];

        if (isset($manual[$first])) {
            return $manual[$first];
        }

        if (count($words) >= 2) {
            $sigla = '';
            foreach ($words as $word) {
                $sigla .= substr($word, 0, 1);
                if (strlen($sigla) >= 5) {
                    break;
                }
            }

            return substr($sigla, 0, 5);
        }

        if (strlen($first) <= 5) {
            $consonants = preg_replace('/[AEIOU]/', '', $first);
            if (strlen($consonants) >= 3) {
                return substr($consonants, 0, 5);
            }

            return substr($first, 0, 5);
        }

        return substr($first, 0, 5);
    }

    private function isSiglaAvailable(string $sigla, ?string $currentId = null): bool
    {
        $existing = $this->entityManager
            ->getRDBRepository('Account')
            ->where(['siglaConta' => $sigla])
            ->findOne();

        if (!$existing) {
            return true;
        }

        return $currentId && $existing->getId() === $currentId;
    }
}
