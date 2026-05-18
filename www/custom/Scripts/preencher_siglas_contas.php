<?php

require_once __DIR__ . '/../../bootstrap.php';

use Espo\Core\Application;

$app = new Application();
$container = $app->getContainer();

$entityManager = $container->get('entityManager');

function makeBaseSigla(string $name): string
{
    $name = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $name);
    $name = strtoupper($name ?: '');
    $name = preg_replace('/[^A-Z0-9 ]/', ' ', $name);
    $name = preg_replace('/\s+/', ' ', trim($name));

    $ignore = [
        'SA', 'S', 'A', 'LTDA', 'LTD', 'ME', 'EPP', 'EIRELI', 'SPE',
        'BRASIL', 'BRAZIL', 'HOLDING', 'PARTICIPACOES'
    ];

    $words = array_values(array_filter(explode(' ', $name), function ($word) use ($ignore) {
        return $word !== '' && !in_array($word, $ignore, true);
    }));

    if (!$words) {
        return 'CTA';
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

function siglaAvailable($entityManager, string $sigla, ?string $currentId = null): bool
{
    $existing = $entityManager
        ->getRDBRepository('Account')
        ->where(['siglaConta' => $sigla])
        ->findOne();

    if (!$existing) {
        return true;
    }

    return $currentId && $existing->getId() === $currentId;
}

function uniqueSigla($entityManager, string $name, ?string $currentId = null): string
{
    $base = substr(makeBaseSigla($name), 0, 5);

    if (siglaAvailable($entityManager, $base, $currentId)) {
        return $base;
    }

    for ($i = 1; $i <= 99; $i++) {
        $candidate = substr($base, 0, 3) . str_pad((string) $i, 2, '0', STR_PAD_LEFT);

        if (siglaAvailable($entityManager, $candidate, $currentId)) {
            return $candidate;
        }
    }

    return substr($base, 0, 2) . strtoupper(substr(md5($name . microtime(true)), 0, 3));
}

$accounts = $entityManager
    ->getRDBRepository('Account')
    ->where([
        'siglaConta' => null
    ])
    ->find();

$count = 0;

foreach ($accounts as $account) {
    $sigla = uniqueSigla($entityManager, (string) $account->get('name'), $account->getId());

    $account->set('siglaConta', $sigla);

    $entityManager->saveEntity($account, [
        'skipHooks' => true
    ]);

    echo $account->get('name') . " => " . $sigla . PHP_EOL;

    $count++;
}

echo "Total de contas atualizadas: {$count}" . PHP_EOL;
