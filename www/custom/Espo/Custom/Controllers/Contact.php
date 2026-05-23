<?php
namespace Espo\Custom\Controllers;

use Espo\Core\Api\Request;
use Espo\Core\Controllers\Record;
use Espo\Core\Exceptions\BadRequest;
use Espo\Core\Exceptions\Forbidden;
use Espo\Core\Exceptions\NotFound;
use stdClass;

class Contact extends Record
{
    // Campos reais do actor dev_fusion/linkedin-profile-scraper (diagnóstico 2026-05-23):
    // profilePicHighQuality → linkedin_photo_url | jobTitle → cargo
    // headline | isPremium → is_premium | isCreator → is_creator
    // isInfluencer → is_influencer | addressWithoutCountry → location_linkedin
    // about → description (só se vazio) | firstName/lastName (só se vazios)
    // NÃO existem na API: connectionsCount, followerCount, openToWork
    private const ACTOR_ID = 'dev_fusion/linkedin-profile-scraper';

    public function postActionEnriquecerLinkedin(Request $request): stdClass
    {
        $data      = $request->getParsedBody();
        $contactId = $data->id ?? null;

        if (!$contactId) throw new BadRequest('ID do contato não informado.');

        $userType = (string)($this->user->get('type') ?? '');
        if (!$this->user->isAdmin() && $userType !== 'api') {
            throw new Forbidden('Somente administrador ou API User pode enriquecer contatos.');
        }

        $contact = $this->entityManager->getEntityById('Contact', (string)$contactId);
        if (!$contact) throw new NotFound('Contato não encontrado.');

        // Proteção server-side: rejeita se já enriquecido
        if ((bool)$contact->get('enriquecidaLinkedin')) {
            throw new BadRequest('Este contato já foi enriquecido.');
        }

        // Validação: linkedinUrl obrigatório
        $linkedinUrl = trim((string)($contact->get('linkedinUrl') ?? ''));
        if ($linkedinUrl === '') {
            throw new BadRequest('Preencha o campo LinkedIn URL antes de enriquecer.');
        }
        $linkedinUrl = $this->normalizeUrl($linkedinUrl);

        $token = $this->getEnv('APIFY_API_TOKEN');
        if (!$token) throw new BadRequest('APIFY_API_TOKEN não configurado em /opt/atria/.env.');

        // 1. Chama Apify
        $items = $this->callApify(self::ACTOR_ID, $token, (object)['profileUrls' => [$linkedinUrl]]);
        if (!is_array($items) || count($items) === 0 || !is_object($items[0])) {
            throw new BadRequest('Apify não retornou dados para este perfil. Verifique se a URL está correta e o perfil é público.');
        }
        $item = $items[0];

        // 2. Grava JSON bruto no Redis (TTL 24h)
        $redisKey = 'contact:linkedin-enrichment:' . $contact->getId();
        $this->saveRedis($redisKey, (object)[
            'status'            => 'raw_received',
            'contactId'         => $contact->getId(),
            'linkedinUrl'       => $linkedinUrl,
            'source'            => 'apify_linkedin_profile',
            'actorId'           => self::ACTOR_ID,
            'requestedByUserId' => $this->getUserId(),
            'createdAt'         => date('Y-m-d H:i:s'),
            'itemsCount'        => count($items),
            'items'             => $items,
        ], 86400);

        // 3. Extrai campos com nomes REAIS confirmados pelo diagnóstico
        $foto        = trim((string)($item->profilePicHighQuality ?? $item->profilePic ?? ''));
        $cargo       = trim((string)($item->jobTitle ?? ''));
        if ($cargo === '' && !empty($item->experiences) && is_array($item->experiences)) {
            $cargo = trim((string)($item->experiences[0]->title ?? ''));
        }
        $headline    = trim((string)($item->headline   ?? ''));
        $about       = trim((string)($item->about      ?? ''));
        $location    = trim((string)($item->addressWithoutCountry ?? ''));
        $isPremium   = (bool)($item->isPremium    ?? false);
        $isCreator   = (bool)($item->isCreator    ?? false);
        $isInfluencer= (bool)($item->isInfluencer ?? false);
        $firstName   = trim((string)($item->firstName  ?? ''));
        $lastName    = trim((string)($item->lastName   ?? ''));

        $nivel = $this->inferirNivel($cargo ?: $headline);

        // 4. Salva no banco — regras de preenchimento
        if ($foto !== '')    $contact->set('linkedinPhotoUrl', $foto);
        if ($cargo !== '') {
            $contact->set('cargo', $cargo);
            if (trim((string)($contact->get('title') ?? '')) === '') $contact->set('title', $cargo);
        }
        if ($headline !== '') $contact->set('headline',         $headline);
        if ($location !== '') $contact->set('locationLinkedin', $location);
        $contact->set('isPremium',    $isPremium);
        $contact->set('isCreator',    $isCreator);
        $contact->set('isInfluencer', $isInfluencer);
        if ($nivel !== '')    $contact->set('nivelHierarquico', $nivel);

        // Nome e descrição: só se vazios no CRM
        if ($firstName !== '' && trim((string)($contact->get('firstName') ?? '')) === '') {
            $contact->set('firstName', $firstName);
        }
        if ($lastName !== '' && trim((string)($contact->get('lastName') ?? '')) === '') {
            $contact->set('lastName', $lastName);
        }
        if ($about !== '' && trim((string)($contact->get('description') ?? '')) === '') {
            $contact->set('description', $about);
        }

        // Flags de controle
        $contact->set('enriquecidaLinkedin',        true);
        $contact->set('dataEnriquecimentoLinkedin', date('Y-m-d H:i:s'));
        $contact->set('fonteEnriquecimento',        'apify_linkedin_profile');
        $contact->set('linkedinLastSync',           date('Y-m-d H:i:s'));

        $this->entityManager->saveEntity($contact);

        // 5. Log de uso
        $this->logUso($contact->getId(), $redisKey, count($items));

        // 6. Retorna record atualizado para o front atualizar o model
        return (object)[
            'success' => true,
            'message' => 'Contato enriquecido com sucesso.',
            'record'  => (object)[
                'id'                         => $contact->getId(),
                'headline'                   => $contact->get('headline'),
                'cargo'                      => $contact->get('cargo'),
                'linkedinPhotoUrl'           => $contact->get('linkedinPhotoUrl'),
                'locationLinkedin'           => $contact->get('locationLinkedin'),
                'isPremium'                  => $contact->get('isPremium'),
                'isCreator'                  => $contact->get('isCreator'),
                'isInfluencer'               => $contact->get('isInfluencer'),
                'nivelHierarquico'           => $contact->get('nivelHierarquico'),
                'enriquecidaLinkedin'        => $contact->get('enriquecidaLinkedin'),
                'dataEnriquecimentoLinkedin' => $contact->get('dataEnriquecimentoLinkedin'),
                'fonteEnriquecimento'        => $contact->get('fonteEnriquecimento'),
            ],
        ];
    }

    private function inferirNivel(string $cargo): string
    {
        $l = mb_strtolower($cargo);
        foreach (['ceo','cto','ciso','coo','cfo','cmo','chief','presidente','president'] as $k) {
            if (str_contains($l, $k)) return 'C-Level';
        }
        foreach (['vp ','vice president','diretor','director','head of','head de'] as $k) {
            if (str_contains($l, $k)) return 'VP / Diretor';
        }
        foreach (['gerente','manager','coordenador','coordinator','supervisor'] as $k) {
            if (str_contains($l, $k)) return 'Gerente / Coordenador';
        }
        foreach (['analista','analyst','especialista','specialist','engenheiro','engineer','desenvolvedor','developer'] as $k) {
            if (str_contains($l, $k)) return 'Analista / Especialista';
        }
        return $cargo !== '' ? 'Outro' : '';
    }

    private function normalizeUrl(string $url): string
    {
        $url = trim($url);
        if ($url === '') return $url;
        if (!str_starts_with($url, 'http://') && !str_starts_with($url, 'https://')) $url = 'https://' . $url;
        return rtrim($url, '/');
    }

    private function getUserId(): ?string
    {
        if (method_exists($this->user, 'getId')) return $this->user->getId();
        $id = $this->user->get('id');
        return $id ? (string)$id : null;
    }

    private function getEnv(string $key): ?string
    {
        $v = getenv($key);
        if ($v !== false && trim($v) !== '') return trim($v);
        $lines = is_readable('/opt/atria/.env') ? file('/opt/atria/.env', FILE_IGNORE_NEW_LINES) : [];
        foreach ((array)$lines as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) continue;
            [$name, $val] = explode('=', $line, 2);
            if (trim($name) === $key) return trim(trim($val), "\"'") ?: null;
        }
        return null;
    }

    private function saveRedis(string $key, object $payload, int $ttl): void
    {
        if (!class_exists('Redis')) return;
        $r = new \Redis();
        try {
            $r->connect($this->getEnv('REDIS_HOST') ?: '127.0.0.1', (int)($this->getEnv('REDIS_PORT') ?: 6379), 2.5);
            $pass = $this->getEnv('REDIS_PASS');
            if ($pass) $r->auth($pass);
            $json = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            if ($json !== false) $r->setex($key, $ttl, $json);
        } catch (\Throwable $e) {
        } finally { try { $r->close(); } catch (\Throwable $e) {} }
    }

    private function callApify(string $actorId, string $token, stdClass $input): array
    {
        // NÃO usar rawurlencode no actorId — o ~ vira %7E e a Apify rejeita
        $url = 'https://api.apify.com/v2/acts/' . $actorId .
               '/run-sync-get-dataset-items?token=' . rawurlencode($token);
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
            CURLOPT_POSTFIELDS     => json_encode($input, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            CURLOPT_CONNECTTIMEOUT => 20,
            CURLOPT_TIMEOUT        => 180,
        ]);
        $resp = curl_exec($ch);
        $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $err  = curl_error($ch);
        curl_close($ch);
        if ($resp === false) throw new BadRequest('Erro cURL: ' . $err);
        $decoded = json_decode($resp);
        if ($code < 200 || $code >= 300) {
            $msg = is_object($decoded) && isset($decoded->error->message) ? $decoded->error->message : $resp;
            throw new BadRequest('Apify HTTP ' . $code . ': ' . $msg);
        }
        if (!is_array($decoded)) throw new BadRequest('Apify não retornou array. Resp: ' . substr($resp, 0, 200));
        return $decoded;
    }

    private function logUso(string $contactId, string $redisKey, int $items): void
    {
        try {
            $pdo = new \PDO(
                'mysql:host=' . ($this->getEnv('DB_HOST') ?: 'localhost') . ';dbname=' . $this->getEnv('DB_NAME') . ';charset=utf8mb4',
                $this->getEnv('DB_USER'), $this->getEnv('DB_PASS') ?: '',
                [\PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION]
            );
            $pdo->prepare("INSERT INTO contact_enrichment_usage
                (id,contact_id,requested_by_user_id,source,redis_key,status,items_count,created_at)
                VALUES(:id,:cid,:uid,:src,:rk,:st,:ic,:ca)"
            )->execute([
                ':id'  => substr(bin2hex(random_bytes(9)), 0, 17),
                ':cid' => $contactId,
                ':uid' => $this->getUserId(),
                ':src' => 'apify_linkedin_profile',
                ':rk'  => $redisKey,
                ':st'  => 'success',
                ':ic'  => $items,
                ':ca'  => date('Y-m-d H:i:s'),
            ]);
        } catch (\Throwable $e) {}
    }
}
