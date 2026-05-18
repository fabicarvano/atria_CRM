<?php

require_once __DIR__ . '/../../bootstrap.php';

use Espo\Core\Application;

$app = new Application();
$container = $app->getContainer();

$entityManager = $container->get('entityManager');

function suffixFromTipo(?string $tipo): string
{
    return match ((string) $tipo) {
        'Revenda' => 'RR',
        'ServicoGerenciado' => 'SG',
        'ServicoPontual' => 'SP',
        'ProjetoEspecial' => 'PE',
        default => 'PE'
    };
}

function postToStream($entityManager, $opportunity, string $message): void
{
    $note = $entityManager->getNewEntity('Note');

    $note->set([
        'type' => 'Post',
        'parentId' => $opportunity->getId(),
        'parentType' => 'Opportunity',
        'post' => $message
    ]);

    $entityManager->saveEntity($note, [
        'skipHooks' => true
    ]);
}

$opportunities = $entityManager
    ->getRDBRepository('Opportunity')
    ->where([
        'numeroOportunidade' => null
    ])
    ->order('createdAt', 'ASC')
    ->find();

$sequenciaisPorConta = [];
$count = 0;
$ignored = 0;

foreach ($opportunities as $opportunity) {
    $accountId = $opportunity->get('accountId');

    if (!$accountId) {
        echo "IGNORADA sem conta: " . $opportunity->get('name') . PHP_EOL;
        $ignored++;
        continue;
    }

    $account = $entityManager->getEntityById('Account', $accountId);

    if (!$account) {
        echo "IGNORADA conta não encontrada: " . $opportunity->get('name') . PHP_EOL;
        $ignored++;
        continue;
    }

    $sigla = $account->get('siglaConta');

    if (!$sigla) {
        echo "IGNORADA conta sem sigla: " . $opportunity->get('name') . " / Conta: " . $account->get('name') . PHP_EOL;
        $ignored++;
        continue;
    }

    if (!isset($sequenciaisPorConta[$accountId])) {
        $existing = $entityManager
            ->getRDBRepository('Opportunity')
            ->where([
                'accountId' => $accountId
            ])
            ->find();

        $max = 0;

        foreach ($existing as $item) {
            $number = (string) ($item->get('numeroOportunidade') ?? '');

            if (preg_match('/-(\d{4})\.[A-Z]{2}$/', $number, $m)) {
                $max = max($max, (int) $m[1]);
            }
        }

        $sequenciaisPorConta[$accountId] = $max;
    }

    $sequenciaisPorConta[$accountId]++;

    $createdAt = (string) ($opportunity->get('createdAt') ?? '');
    $year = $createdAt ? substr($createdAt, 0, 4) : date('Y');

    if (!preg_match('/^\d{4}$/', $year)) {
        $year = date('Y');
    }

    $suffix = suffixFromTipo($opportunity->get('tipoOportunidade'));

    $numero = sprintf(
        '%s-%s-%04d.%s',
        $sigla,
        $year,
        $sequenciaisPorConta[$accountId],
        $suffix
    );

    $opportunity->set('numeroOportunidade', $numero);

    $entityManager->saveEntity($opportunity, [
        'skipHooks' => true
    ]);

    postToStream(
        $entityManager,
        $opportunity,
        "Sistema gerou o número da oportunidade: {$numero}"
    );

    echo $opportunity->get('name') . " => " . $numero . PHP_EOL;

    $count++;
}

echo "Total de oportunidades atualizadas: {$count}" . PHP_EOL;
echo "Total de oportunidades ignoradas: {$ignored}" . PHP_EOL;
