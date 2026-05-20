<?php
namespace Espo\Custom\Controllers;

use Espo\Core\Containers;

class ContaSimilarPatch extends \Espo\Core\Controllers\Base
{
    public function actionListarContasSimilaresIncremental($params)
    {
        $accountId = $params['accountId'] ?? null;
        return $this->getEntityManager()->getRepository('ContaSimilar')->find([
            'account_id' => $accountId,
            'exists_in_crm' => 0,
            'is_created' => 0
        ]);
    }

    public function actionCriarContaSimilarIncremental($params)
    {
        $similarId = $params['similarId'] ?? null;
        if (!$similarId) return ['error'=>'similarId não informado'];
        $repo = $this->getEntityManager()->getRepository('ContaSimilar');
        $similar = $repo->find($similarId);
        if ($similar) {
            $similar->is_created = 1;
            $similar->exists_in_crm = 1;
            $this->getEntityManager()->saveEntity($similar);
            return ['success'=>true];
        }
        return ['error'=>'Registro não encontrado'];
    }
}
