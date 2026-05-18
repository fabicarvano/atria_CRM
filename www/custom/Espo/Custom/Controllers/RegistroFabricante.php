<?php

namespace Espo\Custom\Controllers;

use Espo\Core\Api\Request;
use Espo\Core\Controllers\Record;
use Espo\Core\Exceptions\BadRequest;
use Espo\Core\Exceptions\Forbidden;
use Espo\ORM\Entity;
use stdClass;

class RegistroFabricante extends Record
{
    public function getActionGetByOpportunity(Request $request): stdClass
    {
        $opportunityId = $request->getQueryParam('opportunityId');

        if (!$opportunityId) {
            throw new BadRequest('opportunityId is required.');
        }

        $entity = $this->entityManager
            ->getRDBRepository('RegistroFabricante')
            ->where([
                'opportunityId' => $opportunityId,
            ])
            ->findOne();

        if (!$entity) {
            return (object) [
                'found' => false,
                'record' => null,
                'isAdmin' => $this->user->isAdmin(),
                'isOwner' => false,
                'canEditNumeroRo' => true,
                'canEditDataVencimento' => true,
            ];
        }

        $isAdmin = $this->user->isAdmin();
        $isOwner = $this->isOwner($entity);

        return (object) [
            'found' => true,
            'isAdmin' => $isAdmin,
            'isOwner' => $isOwner,
            'canEditNumeroRo' => $isAdmin,
            'canEditDataVencimento' => $isAdmin || $isOwner,
            'record' => $this->entityToObject($entity),
        ];
    }

    public function postActionSaveForOpportunity(Request $request): stdClass
    {
        $data = $request->getParsedBody();

        $opportunityId = $data->opportunityId ?? null;

        if (!$opportunityId) {
            throw new BadRequest('opportunityId is required.');
        }

        $numeroRo = $data->numeroRo ?? null;
        $dataVencimento = $data->dataVencimento ?? null;
        $opportunityName = $data->opportunityName ?? null;

        $entity = $this->entityManager
            ->getRDBRepository('RegistroFabricante')
            ->where([
                'opportunityId' => $opportunityId,
            ])
            ->findOne();

        $isNew = false;
        $currentUserId = $this->getCurrentUserId();

        if (!$entity) {
            $isNew = true;

            $entity = $this->entityManager->getNewEntity('RegistroFabricante');
            $entity->set('opportunityId', $opportunityId);
            $entity->set('dataCriacao', date('Y-m-d'));
            $entity->set('createdAt', date('Y-m-d H:i:s'));

            if ($currentUserId) {
                $entity->set('createdById', $currentUserId);
            }
        }

        $isAdmin = $this->user->isAdmin();
        $isOwner = $this->isOwner($entity);

        if (!$isNew && !$isAdmin) {
            $numeroAtual = (string) ($entity->get('numeroRo') ?? '');
            $numeroNovo = (string) ($numeroRo ?? '');

            if ($numeroNovo !== $numeroAtual) {
                throw new Forbidden('Somente administrador pode alterar o Número do RO.');
            }

            if (!$isOwner) {
                throw new Forbidden('Somente administrador ou o usuário que criou o RO pode alterar a Data de Vencimento.');
            }
        }

        $entity->set('modifiedAt', date('Y-m-d H:i:s'));

        if ($currentUserId) {
            $entity->set('modifiedById', $currentUserId);
        }

        $entity->set('dataVencimento', $dataVencimento);

        if ($isNew || $isAdmin) {
            $entity->set('numeroRo', $numeroRo);

            if ($numeroRo) {
                $entity->set('name', $numeroRo);
            } else if ($opportunityName) {
                $entity->set('name', 'RO - ' . $opportunityName);
            } else {
                $entity->set('name', 'Registro de Oportunidade');
            }
        }

        $this->entityManager->saveEntity($entity);

        $isOwner = $this->isOwner($entity);

        return (object) [
            'success' => true,
            'isNew' => $isNew,
            'isAdmin' => $isAdmin,
            'isOwner' => $isOwner,
            'canEditNumeroRo' => $isAdmin || $isNew,
            'canEditDataVencimento' => $isAdmin || $isOwner || $isNew,
            'record' => $this->entityToObject($entity),
        ];
    }

    private function getCurrentUserId(): ?string
    {
        if (method_exists($this->user, 'getId')) {
            return $this->user->getId();
        }

        $id = $this->user->get('id');

        return $id ? (string) $id : null;
    }

    private function isOwner(Entity $entity): bool
    {
        $currentUserId = $this->getCurrentUserId();

        if (!$currentUserId) {
            return false;
        }

        $createdById = $entity->get('createdById');

        return $createdById && (string) $createdById === (string) $currentUserId;
    }

    private function entityToObject(Entity $entity): stdClass
    {
        return (object) [
            'id' => $entity->getId(),
            'name' => $entity->get('name'),
            'numeroRo' => $entity->get('numeroRo'),
            'dataCriacao' => $entity->get('dataCriacao'),
            'dataVencimento' => $entity->get('dataVencimento'),
            'opportunityId' => $entity->get('opportunityId'),
            'createdById' => $entity->get('createdById'),
            'modifiedById' => $entity->get('modifiedById'),
            'createdAt' => $entity->get('createdAt'),
            'modifiedAt' => $entity->get('modifiedAt'),
        ];
    }
}
