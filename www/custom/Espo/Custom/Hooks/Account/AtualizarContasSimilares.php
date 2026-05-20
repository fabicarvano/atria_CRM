<?php

namespace Espo\Custom\Hooks\Account;

use Espo\ORM\Entity;
use Espo\ORM\EntityManager;

class AtualizarContasSimilares
{
    public static int $order = 60;

    public function __construct(
        private EntityManager $entityManager
    ) {}

    public function afterSave(Entity $entity, array $options): void
    {
        if (!$entity->isNew()) {
            return;
        }

        $accountId = (string) $entity->getId();
        $accountName = trim((string) ($entity->get('name') ?? ''));
        $accountWebsite = trim((string) ($entity->get('website') ?? ''));

        if ($accountId === '' || $accountName === '') {
            return;
        }

        $matched = $this->findByLinkedin($accountId, $accountWebsite);

        if (!$matched) {
            $matched = $this->findByNameSimilarity($accountId, $accountName);
        }

        if (!$matched) {
            return;
        }

        $similar = $this->entityManager->getEntityById('ContaSimilar', (string) $matched['id']);

        if (!$similar) {
            return;
        }

        $similar->set('existsInCrm', true);
        $similar->set('matchedAccountId', $accountId);
        $similar->set('matchReason', $matched['reason']);

        $this->entityManager->saveEntity($similar);
    }

    private function findByLinkedin(string $accountId, string $accountWebsite): ?array
    {
        $normalizedAccountLinkedin = $this->normalizeComparableUrl($accountWebsite);

        if ($normalizedAccountLinkedin === '') {
            return null;
        }

        $similares = $this->entityManager
            ->getRDBRepository('ContaSimilar')
            ->where([
                'deleted' => false,
                'existsInCrm' => false,
                'isCreated' => false,
            ])
            ->find();

        foreach ($similares as $similar) {
            $similarLinkedin = $this->normalizeComparableUrl((string) ($similar->get('linkedinUrl') ?? ''));

            if ($similarLinkedin !== '' && $similarLinkedin === $normalizedAccountLinkedin) {
                return [
                    'id' => $similar->getId(),
                    'reason' => 'linkedin_match',
                ];
            }
        }

        return null;
    }

    private function findByNameSimilarity(string $accountId, string $accountName): ?array
    {
        $normalizedAccountName = $this->normalizeCompanyName($accountName);

        if ($normalizedAccountName === '') {
            return null;
        }

        $similares = $this->entityManager
            ->getRDBRepository('ContaSimilar')
            ->where([
                'deleted' => false,
                'existsInCrm' => false,
                'isCreated' => false,
            ])
            ->find();

        $bestId = null;
        $bestPercent = 0.0;

        foreach ($similares as $similar) {
            $similarName = $this->normalizeCompanyName((string) ($similar->get('name') ?? ''));

            if ($similarName === '') {
                continue;
            }

            similar_text($normalizedAccountName, $similarName, $percent);

            if ($percent > $bestPercent) {
                $bestPercent = $percent;
                $bestId = $similar->getId();
            }
        }

        if ($bestId && $bestPercent >= 85.0) {
            return [
                'id' => $bestId,
                'reason' => 'name_similarity',
            ];
        }

        return null;
    }

    private function normalizeComparableUrl(string $url): string
    {
        $url = strtolower(trim($url));

        if ($url === '') {
            return '';
        }

        $url = preg_replace('#^https?://#', '', $url);
        $url = preg_replace('#^www\.#', '', $url);
        $url = rtrim($url, '/');

        return $url ?: '';
    }

    private function normalizeCompanyName(string $name): string
    {
        $name = strtolower(trim($name));

        if ($name === '') {
            return '';
        }

        $name = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $name);
        $name = $name ?: '';

        $name = preg_replace('/[^a-z0-9 ]+/', ' ', $name);
        $name = preg_replace('/\b(sa|s a|ltda|ltd|me|eireli|holding|grupo|brasil|brazil|company|inc|corp|corporation)\b/', ' ', $name);
        $name = preg_replace('/\s+/', ' ', $name);

        return trim($name);
    }
}
