<?php

namespace Espo\Custom\Hooks\RegistroFabricante;

use Espo\ORM\Entity;

class DataCriacaoImutavel
{
    public function beforeSave(Entity $entity, array $options = []): void
    {
        $today = date('Y-m-d');

        if ($entity->isNew()) {
            if (!$entity->get('dataCriacao')) {
                $entity->set('dataCriacao', $today);
            }

            if (!$entity->get('name')) {
                $numeroRo = $entity->get('numeroRo') ?: 'RO';
                $entity->set('name', $numeroRo);
            }

            return;
        }

        if ($entity->isAttributeChanged('dataCriacao')) {
            $fetched = $entity->getFetched('dataCriacao');

            if ($fetched) {
                $entity->set('dataCriacao', $fetched);
            }
        }

        if ($entity->isAttributeChanged('numeroRo') && !$entity->get('name')) {
            $entity->set('name', $entity->get('numeroRo'));
        }
    }
}
