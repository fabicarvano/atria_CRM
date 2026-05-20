<?php
namespace Espo\Custom\Hooks\Account;

class AtualizarContasSimilaresPatch extends \Espo\Core\Hooks\Base
{
    public function afterSave($entity, $params)
    {
        $repo = $this->getEntityManager()->getRepository('ContaSimilar');
        $similares = $repo->find(['account_id'=>$entity->id, 'exists_in_crm'=>0]);
        foreach ($similares as $s) {
            $s->exists_in_crm = 1;
            $repo->save($s);
        }
    }
}
