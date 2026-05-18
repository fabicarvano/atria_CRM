<?php

namespace Espo\Custom\Hooks\Account;

use Espo\ORM\Entity;
use Espo\ORM\EntityManager;

class GerarHeatMapConta
{
    public static int $order = 20;

    public function __construct(
        private EntityManager $entityManager
    ) {}

    public function afterSave(Entity $entity, array $options): void
    {
        if (!$entity->isNew()) {
            return;
        }

        $accountId = (string) $entity->getId();

        if ($accountId === '') {
            return;
        }

        $ofertas = $this->entityManager
            ->getRDBRepository('CatalogoOferta')
            ->where([
                'deleted' => false,
                'ativo' => true,
            ])
            ->order('ordem', 'asc')
            ->find();

        foreach ($ofertas as $oferta) {
            $ofertaId = (string) $oferta->getId();

            if ($ofertaId === '') {
                continue;
            }

            $existente = $this->entityManager
                ->getRDBRepository('MapeamentoConta')
                ->where([
                    'accountId' => $accountId,
                    'catalogoOfertaId' => $ofertaId,
                    'deleted' => false,
                ])
                ->findOne();

            if ($existente) {
                continue;
            }

            $this->entityManager->createEntity('MapeamentoConta', [
                'accountId' => $accountId,
                'catalogoOfertaId' => $ofertaId,
                'categoria' => (string) ($oferta->get('categoria') ?? ''),
                'status' => '',
            ]);
        }
    }
}
