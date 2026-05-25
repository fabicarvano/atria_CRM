<?php

namespace Espo\Custom\Controllers;

use Espo\Core\Api\Request;
use Espo\Core\Controllers\Record;
use Espo\Core\Exceptions\BadRequest;
use Espo\Core\Exceptions\Forbidden;
use Espo\Core\Exceptions\NotFound;
use stdClass;

class Account extends Record
{
    private const LINKEDIN_COMPANY_ACTOR_ID = 'AjfNXEI9qTA2IdaAX';

    // Actor harvestapi para busca de funcionários/decisores
    // O actor é hardcoded pois é estável — apenas o token muda
    private const EMPLOYEES_ACTOR_ID = 'harvestapi~linkedin-company-employees';

    // ============================================================
    // TODO (QUANDO COMPRAR API PAGA):
    // 1. Adicionar em /opt/atria/.env:
    // 2. Adicionar em /etc/php/8.3/fpm/pool.d/atria.conf:
    // 3. Substituir a linha abaixo por:
    //    $token = $this->getEnvValue('APIFY_TOKEN_EMPLOYEES');
    // ============================================================

    public function postActionEnriquecerLinkedin(Request $request): stdClass
    {
        // ── Etapa 1: busca empresa no LinkedIn (dev_fusion) ──────────────────
        $redisResult = $this->postActionGravarEnriquecimentoLinkedinRedis($request);
        $processResult = $this->postActionProcessarEnriquecimentoLinkedinRedis($request);

        $this->registrarUsoEnriquecimento($request, $redisResult, $processResult);

        $similaresResult = $this->salvarContasSimilaresDoRedisInterno($request);

        // ── Etapa 2: busca contatos executivos (harvestapi) em paralelo ──────
        // Executa de forma não-bloqueante: salva no Redis e processa assíncrono
        $contatosResult = null;
        try {
            $contatosResult = $this->buscarESalvarContatosExecutivos($request);
        } catch (\Throwable $e) {
            // Não falha o enriquecimento principal se a busca de contatos falhar
            $contatosResult = (object) [
                'success' => false,
                'message' => 'Busca de contatos executivos falhou: ' . $e->getMessage(),
            ];
        }

        return (object) [
            'success' => true,
            'message' => 'Conta enriquecida com sucesso.',
            'redis' => (object) [
                'redisKey' => $redisResult->redisKey ?? null,
                'itemsCount' => $redisResult->itemsCount ?? null,
                'summary' => $redisResult->summary ?? null,
            ],
            'record' => $processResult->record ?? null,
            'sourceSummary' => $processResult->sourceSummary ?? null,
            'similares' => $similaresResult,
            'contatosExecutivos' => $contatosResult,
        ];
    }

    public function postActionBuscarEnriquecimentoLinkedin(Request $request): stdClass
    {
        $data = $request->getParsedBody();

        $accountId = $data->id ?? null;

        if (!$accountId) {
            throw new BadRequest('ID da conta não informado.');
        }

        $userType = (string) ($this->user->get('type') ?? '');

        if (!$this->user->isAdmin() && $userType !== 'api') {
            throw new Forbidden('Somente administrador ou API User pode buscar enriquecimento neste momento.');
        }

        $account = $this->entityManager->getEntityById('Account', (string) $accountId);

        if (!$account) {
            throw new NotFound('Conta não encontrada.');
        }

        $linkedinUrl = trim((string) ($account->get('website') ?? ''));

        if ($linkedinUrl === '') {
            throw new BadRequest('Esta conta não possui LinkedIn cadastrado no campo Website.');
        }

        $linkedinUrl = $this->normalizeLinkedinUrl($linkedinUrl);

        $token = $this->getEnvValue('APIFY_API_TOKEN');

        $token = $this->getEnvValue('APIFY_API_TOKEN');
        if (!$token) {
            throw new BadRequest('APIFY_API_TOKEN não configurado em /opt/atria/.env.');
        }

        $input = $this->buildApifyInput($linkedinUrl, $data);

        $items = $this->callApifyActor(self::LINKEDIN_COMPANY_ACTOR_ID, $token, $input);

        return (object) [
            'success' => true,
            'source' => 'apify_linkedin_company',
            'actorId' => self::LINKEDIN_COMPANY_ACTOR_ID,
            'account' => (object) [
                'id' => $account->getId(),
                'name' => $account->get('name'),
                'linkedinUrl' => $linkedinUrl,
            ],
            'input' => $input,
            'itemsCount' => count($items),
            'items' => $items,
        ];
    }

    public function postActionGravarEnriquecimentoLinkedinRedis(Request $request): stdClass
    {
        $data = $request->getParsedBody();

        $accountId = $data->id ?? null;

        if (!$accountId) {
            throw new BadRequest('ID da conta não informado.');
        }

        $userType = (string) ($this->user->get('type') ?? '');

        if (!$this->user->isAdmin() && $userType !== 'api') {
            throw new Forbidden('Somente administrador ou API User pode gravar enriquecimento no Redis.');
        }

        $account = $this->entityManager->getEntityById('Account', (string) $accountId);

        if (!$account) {
            throw new NotFound('Conta não encontrada.');
        }

        $linkedinUrl = trim((string) ($account->get('website') ?? ''));

        if ($linkedinUrl === '') {
            throw new BadRequest('Esta conta não possui LinkedIn cadastrado no campo Website.');
        }

        $linkedinUrl = $this->normalizeLinkedinUrl($linkedinUrl);

        $token = $this->getEnvValue('APIFY_API_TOKEN');

        $token = $this->getEnvValue('APIFY_API_TOKEN');
        if (!$token) {
            throw new BadRequest('APIFY_API_TOKEN não configurado em /opt/atria/.env.');
        }

        $input = $this->buildApifyInput($linkedinUrl, $data);
        $items = $this->callApifyActor(self::LINKEDIN_COMPANY_ACTOR_ID, $token, $input);

        $payload = (object) [
            'status' => 'raw_received',
            'accountId' => $account->getId(),
            'accountName' => $account->get('name'),
            'linkedinUrl' => $linkedinUrl,
            'source' => 'apify_linkedin_company',
            'actorId' => self::LINKEDIN_COMPANY_ACTOR_ID,
            'requestedByUserId' => $this->getCurrentUserId(),
            'createdAt' => date('Y-m-d H:i:s'),
            'input' => $input,
            'itemsCount' => count($items),
            'items' => $items,
        ];

        $redisKey = 'account:linkedin-enrichment:' . $account->getId();

        $this->saveRedisJson($redisKey, $payload, 86400);

        $first = count($items) > 0 && is_object($items[0]) ? $items[0] : null;

        return (object) [
            'success' => true,
            'message' => 'JSON bruto gravado no Redis.',
            'redisKey' => $redisKey,
            'ttlSeconds' => 86400,
            'itemsCount' => count($items),
            'summary' => $first ? (object) [
                'companyName' => $first->companyName ?? null,
                'industry' => $first->industry ?? null,
                'employeeCount' => $first->employeeCount ?? null,
                'hasDescription' => !empty($first->description ?? null),
                'hasLogo' => !empty($first->logoResolutionResult ?? null),
                'similarOrganizationsCount' => is_array($first->similarOrganizations ?? null) ? count($first->similarOrganizations) : 0,
            ] : null,
        ];
    }

    private function saveRedisJson(string $key, object $payload, int $ttlSeconds): void
    {
        if (!class_exists('Redis')) {
            throw new BadRequest('Extensão PHP Redis não está instalada/habilitada.');
        }

        $host = $this->getEnvValue('REDIS_HOST') ?: '127.0.0.1';
        $port = (int) ($this->getEnvValue('REDIS_PORT') ?: 6379);
        $pass = $this->getEnvValue('REDIS_PASS');

        $redis = new \Redis();

        try {
            $redis->connect($host, $port, 2.5);

            if ($pass) {
                $redis->auth($pass);
            }

            $json = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

            if ($json === false) {
                throw new BadRequest('Não foi possível serializar JSON para Redis.');
            }

            $redis->setex($key, $ttlSeconds, $json);
        } catch (\Throwable $e) {
            throw new BadRequest('Erro ao gravar no Redis: ' . $e->getMessage());
        } finally {
            try {
                $redis->close();
            } catch (\Throwable $e) {
            }
        }
    }

    private function getCurrentUserId(): ?string
    {
        if (method_exists($this->user, 'getId')) {
            return $this->user->getId();
        }

        $id = $this->user->get('id');

        return $id ? (string) $id : null;
    }

    public function postActionProcessarEnriquecimentoLinkedinRedis(Request $request): stdClass
    {
        $data = $request->getParsedBody();

        $accountId = $data->id ?? null;

        if (!$accountId) {
            throw new BadRequest('ID da conta não informado.');
        }

        $userType = (string) ($this->user->get('type') ?? '');

        if (!$this->user->isAdmin() && $userType !== 'api') {
            throw new Forbidden('Somente administrador ou API User pode processar enriquecimento.');
        }

        $account = $this->entityManager->getEntityById('Account', (string) $accountId);

        if (!$account) {
            throw new NotFound('Conta não encontrada.');
        }

        if ((bool) $account->get('enriquecidaLinkedin')) {
            throw new BadRequest('Esta conta já foi enriquecida.');
        }

        $redisKey = 'account:linkedin-enrichment:' . $account->getId();

        $payload = $this->loadRedisJson($redisKey);

        if (!$payload) {
            throw new BadRequest('JSON de enriquecimento não encontrado no Redis.');
        }

        $items = $payload->items ?? [];

        if (!is_array($items) || count($items) === 0 || !is_object($items[0])) {
            throw new BadRequest('JSON do Redis não possui item válido para processamento.');
        }

        $item = $items[0];

        $industry = trim((string) ($item->industry ?? ''));
        $employeeCount = isset($item->employeeCount) ? (int) $item->employeeCount : null;
        $description = trim((string) ($item->description ?? ''));
        $logoUrl = trim((string) ($item->logoResolutionResult ?? ''));

        if ($industry !== '') {
            $account->set('industriaLinkedin', $industry);
        }

        if ($employeeCount !== null && $employeeCount > 0) {
            $account->set('employeeCountLinkedin', $employeeCount);
        }

        if ($websiteUrl !== '') {
            $account->set('companyWebsite', $websiteUrl);
        }

        if ($description !== '' && trim((string) ($account->get('description') ?? '')) === '') {
            $account->set('description', $description);
        }

        if ($logoUrl !== '') {
            $account->set('logoUrl', $logoUrl);
        }

        $account->set('enriquecidaLinkedin', true);
        $account->set('dataEnriquecimentoLinkedin', date('Y-m-d H:i:s'));
        $account->set('enriquecidoPorId', $this->getExecutorUserId());
        $account->set('fonteEnriquecimento', 'apify_linkedin_company');

        $this->entityManager->saveEntity($account);

        return (object) [
            'success' => true,
            'message' => 'Conta enriquecida a partir do JSON salvo no Redis.',
            'redisKey' => $redisKey,
            'record' => (object) [
                'id' => $account->getId(),
                'name' => $account->get('name'),
                'logoUrl' => $account->get('logoUrl'),
                'industriaLinkedin' => $account->get('industriaLinkedin'),
                'employeeCountLinkedin' => $account->get('employeeCountLinkedin'),
                'enriquecidaLinkedin' => $account->get('enriquecidaLinkedin'),
                'dataEnriquecimentoLinkedin' => $account->get('dataEnriquecimentoLinkedin'),
                'enriquecidoPorId' => $account->get('enriquecidoPorId'),
                'fonteEnriquecimento' => $account->get('fonteEnriquecimento'),
            ],
            'sourceSummary' => (object) [
                'companyName' => $item->companyName ?? null,
                'industry' => $item->industry ?? null,
                'employeeCount' => $item->employeeCount ?? null,
                'similarOrganizationsCount' => is_array($item->similarOrganizations ?? null) ? count($item->similarOrganizations) : 0,
            ],
        ];
    }

    private function loadRedisJson(string $key): ?stdClass
    {
        if (!class_exists('Redis')) {
            throw new BadRequest('Extensão PHP Redis não está instalada/habilitada.');
        }

        $host = $this->getEnvValue('REDIS_HOST') ?: '127.0.0.1';
        $port = (int) ($this->getEnvValue('REDIS_PORT') ?: 6379);
        $pass = $this->getEnvValue('REDIS_PASS');

        $redis = new \Redis();

        try {
            $redis->connect($host, $port, 2.5);

            if ($pass) {
                $redis->auth($pass);
            }

            $json = $redis->get($key);

            if (!$json) {
                return null;
            }

            $decoded = json_decode((string) $json);

            if (!$decoded || !is_object($decoded)) {
                throw new BadRequest('JSON salvo no Redis está inválido.');
            }

            return $decoded;
        } catch (\Throwable $e) {
            throw new BadRequest('Erro ao ler do Redis: ' . $e->getMessage());
        } finally {
            try {
                $redis->close();
            } catch (\Throwable $e) {
            }
        }
    }

    public function postActionContarEnriquecimentosUsuario(Request $request): stdClass
    {
        $data = $request->getParsedBody();

        $userId = $data->userId ?? $this->getCurrentUserId();

        if (!$userId) {
            throw new BadRequest('ID do usuário não informado.');
        }

        $pdo = $this->getCustomPdo();

        $stmt = $pdo->prepare("
            SELECT
                requested_by_user_id,
                COUNT(*) AS total,
                SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS total_success,
                MIN(created_at) AS primeiro_enriquecimento,
                MAX(created_at) AS ultimo_enriquecimento
            FROM account_enrichment_usage
            WHERE requested_by_user_id = :userId
            GROUP BY requested_by_user_id
        ");

        $stmt->execute([
            ':userId' => $userId,
        ]);

        $row = $stmt->fetch(\PDO::FETCH_ASSOC);

        return (object) [
            'success' => true,
            'userId' => $userId,
            'total' => $row ? (int) $row['total'] : 0,
            'totalSuccess' => $row ? (int) $row['total_success'] : 0,
            'primeiroEnriquecimento' => $row['primeiro_enriquecimento'] ?? null,
            'ultimoEnriquecimento' => $row['ultimo_enriquecimento'] ?? null,
        ];
    }

    private function registrarUsoEnriquecimento(Request $request, stdClass $redisResult, stdClass $processResult): void
    {
        $record = $processResult->record ?? null;
        $sourceSummary = $processResult->sourceSummary ?? null;

        if (!$record || empty($record->id)) {
            return;
        }

        $requestedByUserId = $this->getCurrentUserId();
        $executedByUserId = $this->getExecutorUserId();

        $itemsCount = isset($redisResult->itemsCount) ? (int) $redisResult->itemsCount : 0;
        $similarCount = isset($sourceSummary->similarOrganizationsCount) ? (int) $sourceSummary->similarOrganizationsCount : 0;

        $pdo = $this->getCustomPdo();

        $stmt = $pdo->prepare("
            INSERT INTO account_enrichment_usage (
                id,
                account_id,
                requested_by_user_id,
                executed_by_user_id,
                source,
                redis_key,
                status,
                items_count,
                similar_organizations_count,
                created_at
            ) VALUES (
                :id,
                :accountId,
                :requestedByUserId,
                :executedByUserId,
                :source,
                :redisKey,
                :status,
                :itemsCount,
                :similarOrganizationsCount,
                :createdAt
            )
        ");

        $stmt->execute([
            ':id' => $this->generateCustomId(),
            ':accountId' => (string) $record->id,
            ':requestedByUserId' => $requestedByUserId,
            ':executedByUserId' => $executedByUserId,
            ':source' => 'apify_linkedin_company',
            ':redisKey' => $redisResult->redisKey ?? null,
            ':status' => 'success',
            ':itemsCount' => $itemsCount,
            ':similarOrganizationsCount' => $similarCount,
            ':createdAt' => date('Y-m-d H:i:s'),
        ]);
    }

    private function getExecutorUserId(): ?string
    {
        return $this->getEnvValue('ESPO_BOT_USER_ID') ?: $this->getCurrentUserId();
    }

    private function getCustomPdo(): \PDO
    {
        $host = $this->getEnvValue('DB_HOST') ?: 'localhost';
        $dbName = $this->getEnvValue('DB_NAME');
        $user = $this->getEnvValue('DB_USER');
        $pass = $this->getEnvValue('DB_PASS');

        if (!$dbName || !$user) {
            throw new BadRequest('Credenciais do banco não configuradas no .env.');
        }

        $dsn = 'mysql:host=' . $host . ';dbname=' . $dbName . ';charset=utf8mb4';

        return new \PDO($dsn, $user, $pass ?: '', [
            \PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION,
            \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
        ]);
    }

    private function generateCustomId(): string
    {
        return substr(bin2hex(random_bytes(9)), 0, 17);
    }

    public function postActionCriarContaSimilar(Request $request): stdClass
    {
        $data = $request->getParsedBody();

        $similarId = $data->similarId ?? null;

        if (!$similarId) {
            throw new BadRequest('ID da conta similar não informado.');
        }

        $pdo = $this->getCustomPdo();

        $stmt = $pdo->prepare("
            SELECT *
            FROM conta_similar
            WHERE id = :id
              AND deleted = 0
            LIMIT 1
        ");

        $stmt->execute([
            ':id' => (string) $similarId,
        ]);

        $similar = $stmt->fetch(\PDO::FETCH_ASSOC);

        if (!$similar) {
            throw new NotFound('Conta Similar não encontrada.');
        }

        if ((int) $similar['exists_in_crm'] === 1 || (int) $similar['is_created'] === 1) {
            throw new BadRequest('Esta Conta Similar já existe no CRM ou já foi criada.');
        }

        $name = trim((string) ($similar['name'] ?? ''));
        $linkedinUrl = trim((string) ($similar['linkedin_url'] ?? ''));

        if ($name === '') {
            throw new BadRequest('Conta Similar sem nome.');
        }

        $match = $this->buscarContaExistenteParaSimilar(
            $pdo,
            (string) $similar['account_id'],
            $name,
            $linkedinUrl
        );

        if ($match['existsInCrm']) {
            $update = $pdo->prepare("
                UPDATE conta_similar
                SET
                    exists_in_crm = 1,
                    matched_account_id = :matchedAccountId,
                    match_reason = :matchReason,
                    modified_at = :modifiedAt,
                    modified_by_id = :modifiedById
                WHERE id = :id
            ");

            $update->execute([
                ':id' => (string) $similarId,
                ':matchedAccountId' => $match['matchedAccountId'],
                ':matchReason' => $match['matchReason'],
                ':modifiedAt' => date('Y-m-d H:i:s'),
                ':modifiedById' => $this->getCurrentUserId(),
            ]);

            return (object) [
                'success' => false,
                'created' => false,
                'message' => 'Conta Similar já existe no CRM. Registro marcado como existente.',
                'matchedAccountId' => $match['matchedAccountId'],
                'matchReason' => $match['matchReason'],
            ];
        }

        $botNovaContaUserId = $this->getBotNovaContaUserId();
        $requestedByUserId = $this->getCurrentUserId();

        $account = $this->entityManager->getNewEntity('Account');

        $account->set('name', $name);

        if ($linkedinUrl !== '') {
            $account->set('website', $linkedinUrl);
        }

        if (!empty($similar['logo_url'])) {
            $account->set('logoUrl', $similar['logo_url']);
        }

        if (!empty($similar['industry'])) {
            $account->set('industriaLinkedin', $similar['industry']);
        }

        if (!empty($similar['employee_count'])) {
            $account->set('employeeCountLinkedin', (int) $similar['employee_count']);
        }

        if (!empty($similar['description'])) {
            $account->set('description', $similar['description']);
        }

        $account->set('enriquecidaLinkedin', false);
        $account->set('fonteEnriquecimento', 'apify_similar_organization');

        $this->entityManager->saveEntity($account);

        $createdAccountId = $account->getId();

        if ($botNovaContaUserId) {
            $this->atualizarCreatedByDaConta($pdo, $createdAccountId, $botNovaContaUserId);
        }

        $update = $pdo->prepare("
            UPDATE conta_similar
            SET
                is_created = 1,
                created_account_id = :createdAccountId,
                created_by_user_id = :createdByUserId,
                created_by_bot_user_id = :createdByBotUserId,
                created_from = :createdFrom,
                exists_in_crm = 1,
                matched_account_id = :matchedAccountId,
                match_reason = :matchReason,
                modified_at = :modifiedAt,
                modified_by_id = :modifiedById
            WHERE id = :id
        ");

        $update->execute([
            ':id' => (string) $similarId,
            ':createdAccountId' => $createdAccountId,
            ':createdByUserId' => $requestedByUserId,
            ':createdByBotUserId' => $botNovaContaUserId,
            ':createdFrom' => 'similar_organization',
            ':matchedAccountId' => $createdAccountId,
            ':matchReason' => 'created_from_similar',
            ':modifiedAt' => date('Y-m-d H:i:s'),
            ':modifiedById' => $requestedByUserId,
        ]);

        return (object) [
            'success' => true,
            'created' => true,
            'message' => 'Conta criada a partir da Conta Similar.',
            'similarId' => (string) $similarId,
            'record' => (object) [
                'id' => $createdAccountId,
                'name' => $account->get('name'),
                'website' => $account->get('website'),
                'logoUrl' => $account->get('logoUrl'),
                'industriaLinkedin' => $account->get('industriaLinkedin'),
                'employeeCountLinkedin' => $account->get('employeeCountLinkedin'),
                'enriquecidaLinkedin' => $account->get('enriquecidaLinkedin'),
                'fonteEnriquecimento' => $account->get('fonteEnriquecimento'),
                'createdByBotUserId' => $botNovaContaUserId,
                'requestedByUserId' => $requestedByUserId,
            ],
        ];
    }

    private function getBotNovaContaUserId(): ?string
    {
        return $this->getEnvValue('ESPO_BOT_NOVA_CONTA_USER_ID');
    }

    private function atualizarCreatedByDaConta(\PDO $pdo, string $accountId, string $botUserId): void
    {
        $stmt = $pdo->prepare("
            UPDATE account
            SET
                created_by_id = :botUserId,
                modified_by_id = :botUserId
            WHERE id = :accountId
        ");

        $stmt->execute([
            ':accountId' => $accountId,
            ':botUserId' => $botUserId,
        ]);
    }

    public function postActionListarContasSimilares(Request $request): stdClass
    {
        $data = $request->getParsedBody();

        $accountId = $data->id ?? null;
        $limit = isset($data->limit) ? (int) $data->limit : 50;

        if (!$accountId) {
            throw new BadRequest('ID da conta não informado.');
        }

        if ($limit <= 0 || $limit > 100) {
            $limit = 50;
        }

        $account = $this->entityManager->getEntityById('Account', (string) $accountId);

        if (!$account) {
            throw new NotFound('Conta não encontrada.');
        }

        $pdo = $this->getCustomPdo();

        $stmt = $pdo->prepare("
            SELECT
                id,
                account_id,
                name,
                linkedin_url,
                website_url,
                industry,
                employee_count,
                description,
                logo_url,
                JSON_UNQUOTE(JSON_EXTRACT(raw_json, '$.employeeCountRange.start')) AS range_start,
                JSON_UNQUOTE(JSON_EXTRACT(raw_json, '$.employeeCountRange.end')) AS range_end,
                exists_in_crm,
                matched_account_id,
                match_reason,
                is_created,
                created_account_id,
                created_at
            FROM conta_similar
            WHERE deleted = 0
              AND account_id = :accountId
              AND exists_in_crm = 0
              AND is_created = 0
            ORDER BY name ASC
            LIMIT " . $limit
        );

        $stmt->execute([
            ':accountId' => (string) $accountId,
        ]);

        $rows = $stmt->fetchAll(\PDO::FETCH_ASSOC);

        $items = [];

        foreach ($rows as $row) {
            $items[] = (object) [
                'id' => $row['id'],
                'accountId' => $row['account_id'],
                'name' => $row['name'],
                'linkedinUrl' => $row['linkedin_url'],
                'websiteUrl' => $row['website_url'],
                'industry' => $row['industry'],
                'employeeCount' => $row['employee_count'] !== null ? (int) $row['employee_count'] : null,
                'employeeCountRangeStart' => $row['range_start'] !== null ? (int) $row['range_start'] : null,
                'employeeCountRangeEnd' => $row['range_end'] !== null ? (int) $row['range_end'] : null,
                'description' => $row['description'],
                'logoUrl' => $row['logo_url'],
                'existsInCrm' => (bool) $row['exists_in_crm'],
                'matchedAccountId' => $row['matched_account_id'],
                'matchReason' => $row['match_reason'],
                'isCreated' => (bool) $row['is_created'],
                'createdAccountId' => $row['created_account_id'],
                'createdAt' => $row['created_at'],
            ];
        }

        $countStmt = $pdo->prepare("
            SELECT
                COUNT(*) AS total,
                SUM(CASE WHEN exists_in_crm = 1 THEN 1 ELSE 0 END) AS ja_existem_crm,
                SUM(CASE WHEN exists_in_crm = 0 AND is_created = 0 THEN 1 ELSE 0 END) AS disponiveis,
                SUM(CASE WHEN is_created = 1 THEN 1 ELSE 0 END) AS ja_criadas
            FROM conta_similar
            WHERE deleted = 0
              AND account_id = :accountId
        ");

        $countStmt->execute([
            ':accountId' => (string) $accountId,
        ]);

        $summary = $countStmt->fetch(\PDO::FETCH_ASSOC) ?: [];

        return (object) [
            'success' => true,
            'account' => (object) [
                'id' => $account->getId(),
                'name' => $account->get('name'),
            ],
            'total' => count($items),
            'summary' => (object) [
                'total' => isset($summary['total']) ? (int) $summary['total'] : 0,
                'jaExistemCrm' => isset($summary['ja_existem_crm']) ? (int) $summary['ja_existem_crm'] : 0,
                'disponiveis' => isset($summary['disponiveis']) ? (int) $summary['disponiveis'] : 0,
                'jaCriadas' => isset($summary['ja_criadas']) ? (int) $summary['ja_criadas'] : 0,
            ],
            'list' => $items,
        ];
    }

    public function postActionSalvarContasSimilaresDoRedis(Request $request): stdClass
    {
        return $this->salvarContasSimilaresDoRedisInterno($request);
    }

    private function salvarContasSimilaresDoRedisInterno(Request $request): stdClass
    {
        $data = $request->getParsedBody();

        $accountId = $data->id ?? null;

        if (!$accountId) {
            throw new BadRequest('ID da conta não informado.');
        }

        $userType = (string) ($this->user->get('type') ?? '');

        if (!$this->user->isAdmin() && $userType !== 'api') {
            throw new Forbidden('Somente administrador ou API User pode salvar contas similares.');
        }

        $account = $this->entityManager->getEntityById('Account', (string) $accountId);

        if (!$account) {
            throw new NotFound('Conta não encontrada.');
        }

        $redisKey = 'account:linkedin-enrichment:' . $account->getId();

        $payload = $this->loadRedisJson($redisKey);

        if (!$payload) {
            throw new BadRequest('JSON de enriquecimento não encontrado no Redis.');
        }

        $items = $payload->items ?? [];

        if (!is_array($items) || count($items) === 0 || !is_object($items[0])) {
            return (object) [
                'success' => true,
                'message' => 'Nenhum item principal encontrado para extrair similares.',
                'totalRecebidas' => 0,
                'totalGravadas' => 0,
                'totalExistentesCrm' => 0,
                'totalDisponiveis' => 0,
            ];
        }

        $item = $items[0];
        $similares = $item->similarOrganizations ?? [];

        if (!is_array($similares)) {
            $similares = [];
        }

        $pdo = $this->getCustomPdo();

        $totalRecebidas = count($similares);
        $totalGravadas = 0;
        $totalAtualizadas = 0;
        $totalExistentesCrm = 0;
        $totalDisponiveis = 0;

        foreach ($similares as $similar) {
            if (!is_object($similar)) {
                continue;
            }

            $dados = $this->extrairDadosContaSimilar($similar);

            if (($dados['name'] ?? '') === '') {
                continue;
            }

            $match = $this->buscarContaExistenteParaSimilar(
                $pdo,
                $account->getId(),
                $dados['name'],
                $dados['linkedinUrl']
            );

            $existsInCrm = $match['existsInCrm'];
            $matchedAccountId = $match['matchedAccountId'];
            $matchReason = $match['matchReason'];

            if ($existsInCrm) {
                $totalExistentesCrm++;
            } else {
                $totalDisponiveis++;
            }

            $rawJson = json_encode($similar, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

            $existente = $this->buscarContaSimilarExistente(
                $pdo,
                $account->getId(),
                $dados['name'],
                $dados['linkedinUrl']
            );

            if ($existente) {
                $stmt = $pdo->prepare("
                    UPDATE conta_similar
                    SET
                        name = :name,
                        linkedin_url = :linkedinUrl,
                        website_url = :websiteUrl,
                        industry = :industry,
                        employee_count = :employeeCount,
                        description = :description,
                        logo_url = :logoUrl,
                        source = :source,
                        raw_json = :rawJson,
                        exists_in_crm = :existsInCrm,
                        matched_account_id = :matchedAccountId,
                        match_reason = :matchReason,
                        modified_at = :modifiedAt,
                        modified_by_id = :modifiedById
                    WHERE id = :id
                ");

                $stmt->execute([
                    ':id' => $existente['id'],
                    ':name' => $dados['name'],
                    ':linkedinUrl' => $dados['linkedinUrl'],
                    ':websiteUrl' => $dados['websiteUrl'],
                    ':industry' => $dados['industry'],
                    ':employeeCount' => $dados['employeeCount'],
                    ':description' => $dados['description'],
                    ':logoUrl' => $dados['logoUrl'],
                    ':source' => 'apify_linkedin_company',
                    ':rawJson' => $rawJson,
                    ':existsInCrm' => $existsInCrm ? 1 : 0,
                    ':matchedAccountId' => $matchedAccountId,
                    ':matchReason' => $matchReason,
                    ':modifiedAt' => date('Y-m-d H:i:s'),
                    ':modifiedById' => $this->getCurrentUserId(),
                ]);

                $totalAtualizadas++;
                continue;
            }

            $stmt = $pdo->prepare("
                INSERT INTO conta_similar (
                    id,
                    name,
                    deleted,
                    account_id,
                    linkedin_url,
                    website_url,
                    industry,
                    employee_count,
                    description,
                    logo_url,
                    source,
                    raw_json,
                    exists_in_crm,
                    matched_account_id,
                    match_reason,
                    is_created,
                    created_from,
                    created_at,
                    modified_at,
                    created_by_id,
                    modified_by_id
                ) VALUES (
                    :id,
                    :name,
                    0,
                    :accountId,
                    :linkedinUrl,
                    :websiteUrl,
                    :industry,
                    :employeeCount,
                    :description,
                    :logoUrl,
                    :source,
                    :rawJson,
                    :existsInCrm,
                    :matchedAccountId,
                    :matchReason,
                    0,
                    :createdFrom,
                    :createdAt,
                    :modifiedAt,
                    :createdById,
                    :modifiedById
                )
            ");

            $stmt->execute([
                ':id' => $this->generateCustomId(),
                ':name' => $dados['name'],
                ':accountId' => $account->getId(),
                ':linkedinUrl' => $dados['linkedinUrl'],
                ':websiteUrl' => $dados['websiteUrl'],
                ':industry' => $dados['industry'],
                ':employeeCount' => $dados['employeeCount'],
                ':description' => $dados['description'],
                ':logoUrl' => $dados['logoUrl'],
                ':source' => 'apify_linkedin_company',
                ':rawJson' => $rawJson,
                ':existsInCrm' => $existsInCrm ? 1 : 0,
                ':matchedAccountId' => $matchedAccountId,
                ':matchReason' => $matchReason,
                ':createdFrom' => 'similar_organization',
                ':createdAt' => date('Y-m-d H:i:s'),
                ':modifiedAt' => date('Y-m-d H:i:s'),
                ':createdById' => $this->getCurrentUserId(),
                ':modifiedById' => $this->getCurrentUserId(),
            ]);

            $totalGravadas++;
        }

        return (object) [
            'success' => true,
            'message' => 'Contas similares processadas a partir do Redis.',
            'redisKey' => $redisKey,
            'totalRecebidas' => $totalRecebidas,
            'totalGravadas' => $totalGravadas,
            'totalAtualizadas' => $totalAtualizadas,
            'totalExistentesCrm' => $totalExistentesCrm,
            'totalDisponiveis' => $totalDisponiveis,
        ];
    }

    private function extrairDadosContaSimilar(stdClass $similar): array
    {
        $name = $similar->companyName
            ?? $similar->name
            ?? $similar->title
            ?? '';

        $linkedinUrl = $similar->url
            ?? $similar->linkedinUrl
            ?? $similar->profileUrl
            ?? $similar->link
            ?? '';

        $websiteUrl = $similar->websiteUrl
            ?? $similar->website
            ?? '';

        $industry = $similar->industry
            ?? '';

        $employeeCount = null;
        if (isset($similar->employeeCount)) {
            $employeeCount = (int) $similar->employeeCount;
        } elseif (isset($similar->employeeCountRange)) {
            $range = $similar->employeeCountRange;
            $start = isset($range->start) ? (int) $range->start : 0;
            $end   = isset($range->end)   ? (int) $range->end   : 0;
            if ($start > 0 && $end > 0) {
                $employeeCount = (int) round(($start + $end) / 2);
            } elseif ($start > 0) {
                $employeeCount = $start;
            }
        }

        $description = $similar->description
            ?? $similar->tagline
            ?? '';

        $logoUrl = $similar->logoResolutionResult
            ?? $similar->logoUrl
            ?? $similar->logo
            ?? '';

        $linkedinUrl = $this->normalizeLinkedinUrl((string) $linkedinUrl);

        return [
            'name' => trim((string) $name),
            'linkedinUrl' => trim((string) $linkedinUrl),
            'websiteUrl' => trim((string) $websiteUrl),
            'industry' => trim((string) $industry),
            'employeeCount' => $employeeCount && $employeeCount > 0 ? $employeeCount : null,
            'description' => trim((string) $description),
            'logoUrl' => trim((string) $logoUrl),
        ];
    }

    private function buscarContaSimilarExistente(\PDO $pdo, string $accountId, string $name, string $linkedinUrl): ?array
    {
        if ($linkedinUrl !== '') {
            $stmt = $pdo->prepare("
                SELECT id
                FROM conta_similar
                WHERE deleted = 0
                  AND account_id = :accountId
                  AND linkedin_url = :linkedinUrl
                LIMIT 1
            ");

            $stmt->execute([
                ':accountId' => $accountId,
                ':linkedinUrl' => $linkedinUrl,
            ]);

            $row = $stmt->fetch(\PDO::FETCH_ASSOC);

            if ($row) {
                return $row;
            }
        }

        $stmt = $pdo->prepare("
            SELECT id
            FROM conta_similar
            WHERE deleted = 0
              AND account_id = :accountId
              AND name = :name
            LIMIT 1
        ");

        $stmt->execute([
            ':accountId' => $accountId,
            ':name' => $name,
        ]);

        $row = $stmt->fetch(\PDO::FETCH_ASSOC);

        return $row ?: null;
    }

    private function buscarContaExistenteParaSimilar(\PDO $pdo, string $originAccountId, string $name, string $linkedinUrl): array
    {
        $normalizedLinkedin = $this->normalizeComparableUrl($linkedinUrl);

        if ($normalizedLinkedin !== '') {
            $stmt = $pdo->prepare("
                SELECT id, name, website
                FROM account
                WHERE deleted = 0
                  AND id <> :originAccountId
                  AND website IS NOT NULL
                  AND website <> ''
            ");

            $stmt->execute([
                ':originAccountId' => $originAccountId,
            ]);

            while ($row = $stmt->fetch(\PDO::FETCH_ASSOC)) {
                $accountLinkedin = $this->normalizeComparableUrl((string) ($row['website'] ?? ''));

                if ($accountLinkedin !== '' && $accountLinkedin === $normalizedLinkedin) {
                    return [
                        'existsInCrm' => true,
                        'matchedAccountId' => $row['id'],
                        'matchReason' => 'linkedin_match',
                    ];
                }
            }
        }

        $similarName = $this->normalizeCompanyName($name);

        if ($similarName === '') {
            return [
                'existsInCrm' => false,
                'matchedAccountId' => null,
                'matchReason' => null,
            ];
        }

        $stmt = $pdo->prepare("
            SELECT id, name
            FROM account
            WHERE deleted = 0
              AND id <> :originAccountId
              AND name IS NOT NULL
              AND name <> ''
        ");

        $stmt->execute([
            ':originAccountId' => $originAccountId,
        ]);

        $bestId = null;
        $bestPercent = 0.0;

        while ($row = $stmt->fetch(\PDO::FETCH_ASSOC)) {
            $accountName = $this->normalizeCompanyName((string) ($row['name'] ?? ''));

            if ($accountName === '') {
                continue;
            }

            similar_text($similarName, $accountName, $percent);

            if ($percent > $bestPercent) {
                $bestPercent = $percent;
                $bestId = $row['id'];
            }
        }

        if ($bestId && $bestPercent >= 85.0) {
            return [
                'existsInCrm' => true,
                'matchedAccountId' => $bestId,
                'matchReason' => 'name_similarity',
            ];
        }

        return [
            'existsInCrm' => false,
            'matchedAccountId' => null,
            'matchReason' => null,
        ];
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

        $map = [
            'á' => 'a', 'à' => 'a', 'ã' => 'a', 'â' => 'a',
            'é' => 'e', 'ê' => 'e',
            'í' => 'i',
            'ó' => 'o', 'ô' => 'o', 'õ' => 'o',
            'ú' => 'u',
            'ç' => 'c',
        ];

        $name = strtr($name, $map);
        $name = preg_replace('/[^a-z0-9 ]+/', ' ', $name);
        $name = preg_replace('/\b(sa|s a|ltda|me|eireli|holding|grupo|brasil|brazil)\b/', ' ', $name);
        $name = preg_replace('/\s+/', ' ', $name);

        return trim($name);
    }

    private function normalizeLinkedinUrl(string $url): string
    {
        $url = trim($url);

        if ($url === '') {
            return $url;
        }

        if (!str_starts_with($url, 'http://') && !str_starts_with($url, 'https://')) {
            $url = 'https://' . $url;
        }

        return rtrim($url, '/');
    }

    private function buildApifyInput(string $linkedinUrl, stdClass $data): stdClass
    {
        if (isset($data->apifyInput) && is_object($data->apifyInput)) {
            return $data->apifyInput;
        }

        return (object) [
            'profileUrls' => [
                $linkedinUrl,
            ],
        ];
    }

    private function callApifyActor(string $actorId, string $token, stdClass $input): array
    {
        $url = 'https://api.apify.com/v2/acts/' . rawurlencode($actorId) .
            '/run-sync-get-dataset-items?token=' . rawurlencode($token);

        $payload = json_encode($input, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        if ($payload === false) {
            throw new BadRequest('Não foi possível montar o payload para o Apify.');
        }

        $ch = curl_init($url);

        if (!$ch) {
            throw new BadRequest('Não foi possível iniciar cURL.');
        }

        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS => $payload,
            CURLOPT_CONNECTTIMEOUT => 20,
            CURLOPT_TIMEOUT => 180,
        ]);

        $response = curl_exec($ch);

        if ($response === false) {
            $error = curl_error($ch);
            curl_close($ch);

            throw new BadRequest('Erro ao chamar Apify: ' . $error);
        }

        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);

        curl_close($ch);

        $decoded = json_decode($response);

        if ($httpCode < 200 || $httpCode >= 300) {
            $message = is_object($decoded) && isset($decoded->error->message)
                ? $decoded->error->message
                : $response;

            throw new BadRequest('Apify retornou erro HTTP ' . $httpCode . ': ' . $message);
        }

        if (!is_array($decoded)) {
            throw new BadRequest('Resposta inesperada do Apify. Era esperado um array de itens do dataset.');
        }

        return $decoded;
    }

    private function getEnvValue(string $key): ?string
    {
        $value = getenv($key);

        if ($value !== false && trim((string) $value) !== '') {
            return trim((string) $value);
        }

        $envPath = '/opt/atria/.env';

        if (!is_readable($envPath)) {
            return null;
        }

        $lines = file($envPath, FILE_IGNORE_NEW_LINES);

        if (!$lines) {
            return null;
        }

        foreach ($lines as $line) {
            $line = trim((string) $line);

            if ($line === '' || str_starts_with($line, '#')) {
                continue;
            }

            if (!str_contains($line, '=')) {
                continue;
            }

            [$name, $rawValue] = explode('=', $line, 2);

            $name = trim($name);

            if ($name !== $key) {
                continue;
            }

            $rawValue = trim($rawValue);
            $rawValue = trim($rawValue, "\"'");

            return $rawValue !== '' ? $rawValue : null;
        }

        return null;
    }
    // =========================================================================
    // CONTATOS EXECUTIVOS — Decisores de TI/Segurança via LinkedIn Apify
    // =========================================================================

    /**
     * Busca contatos executivos via harvestapi e salva no Redis + tabela.
     * Chamado pelo postActionEnriquecerLinkedin em paralelo com o enriquecimento da empresa.
     */
    private function buscarESalvarContatosExecutivos(Request $request): stdClass
    {
        $data     = $request->getParsedBody();
        $accountId = $data->id ?? null;

        if (!$accountId) {
            throw new BadRequest('ID da conta não informado.');
        }

        $account = $this->entityManager->getEntityById('Account', (string) $accountId);
        if (!$account) {
            throw new NotFound('Conta não encontrada.');
        }

        $linkedinUrl = trim((string) ($account->get('website') ?? ''));
        if ($linkedinUrl === '') {
            return (object) [
                'success' => false,
                'message' => 'Conta sem LinkedIn cadastrado no campo Website.',
            ];
        }

        $linkedinUrl = $this->normalizeLinkedinUrl($linkedinUrl);

        // Lê cargos buscados da tabela de config (editável pela console do EspoCRM)
        $jobTitles = $this->lerCargosBuscados();

        if (empty($jobTitles)) {
            return (object) [
                'success' => false,
                'message' => 'Nenhum cargo configurado em contato_executivo_config.',
            ];
        }

        // Token para busca de employees — usa o mesmo APIFY_API_TOKEN da empresa



        $token = $this->getEnvValue('APIFY_API_TOKEN');
        if (!$token) {
            throw new BadRequest('Token Apify employees não configurado.');
        }

        // Monta input para harvestapi
        $input = (object) [
            'companies'          => [$linkedinUrl],
            'companyBatchMode'   => 'all_at_once',
            'jobTitles'          => $jobTitles,
            'maxItems'           => 50,
            'profileScraperMode' => 'Short ($4 per 1k)',
            'recentlyChangedJobs'=> false,
            'searchQuery'        => 'security OR cybersecurity OR "information security" OR "segurança da informação" OR cibersegurança OR IT OR tecnologia OR technology OR TI',
        ];

        // Chama Apify — harvestapi employees
        $items = $this->callApifyActorAsync(self::EMPLOYEES_ACTOR_ID, $token, $input);

        // Salva raw no Redis (TTL 24h)
        $redisKey = 'account:linkedin-employees:' . $account->getId();
        $payload  = (object) [
            'status'     => 'raw_received',
            'accountId'  => $account->getId(),
            'linkedinUrl'=> $linkedinUrl,
            'source'     => 'harvestapi_employees',
            'actorId'    => self::EMPLOYEES_ACTOR_ID,
            'createdAt'  => date('Y-m-d H:i:s'),
            'itemsCount' => count($items),
            'items'      => $items,
        ];
        $this->saveRedisJson($redisKey, $payload, 86400);

        // Processa e salva na tabela contato_executivo
        $result = $this->processarESalvarContatosDoRedis($account->getId(), $redisKey);

        return (object) [
            'success'    => true,
            'message'    => 'Contatos executivos buscados e salvos.',
            'redisKey'   => $redisKey,
            'itemsCount' => count($items),
            'salvos'     => $result->totalSalvos ?? 0,
            'existentes' => $result->totalExistentes ?? 0,
        ];
    }

    /**
     * Lê os cargos buscados da tabela contato_executivo_config.
     * Editável pela console do EspoCRM sem necessidade de CLI.
     * Retorna array com máximo de 20 itens (limite da API harvestapi).
     */
    private function lerCargosBuscados(): array
    {
        $pdo = $this->getCustomPdo();

        $stmt = $pdo->prepare("
            SELECT valor FROM contato_executivo_config
            WHERE chave = 'cargos_buscados'
            LIMIT 1
        ");
        $stmt->execute();
        $row = $stmt->fetch(\PDO::FETCH_ASSOC);

        if (!$row || empty($row['valor'])) {
            return [];
        }

        $cargos = array_map('trim', explode(',', $row['valor']));
        $cargos = array_filter($cargos, fn($c) => $c !== '');
        $cargos = array_values($cargos);

        // Garante máximo de 20 itens (limite harvestapi)
        return array_slice($cargos, 0, 20);
    }

    /**
     * Processa itens do Redis e salva na tabela contato_executivo.
     * Valida duplicidade por LinkedIn URL e similaridade de nome.
     */
    private function processarESalvarContatosDoRedis(string $accountId, string $redisKey): stdClass
    {
        $payload = $this->loadRedisJson($redisKey);

        if (!$payload || !is_array($payload->items ?? null)) {
            return (object) ['totalSalvos' => 0, 'totalExistentes' => 0];
        }

        $pdo          = $this->getCustomPdo();
        $totalSalvos  = 0;
        $totalAtualizados = 0;
        $totalExistentes  = 0;

        foreach ($payload->items as $item) {
            if (!is_object($item)) {
                continue;
            }

            $dados = $this->extrairDadosContatoExecutivo($item);

            if (empty($dados['firstName']) && empty($dados['lastName'])) {
                continue;
            }

            // Valida duplicidade no CRM (Contact)
            $match = $this->buscarContatoExistenteNoCrm(
                $pdo,
                $accountId,
                $dados['firstName'] . ' ' . $dados['lastName'],
                $dados['linkedinUrl']
            );

            $existsInCrm     = $match['existsInCrm'];
            $matchedContactId = $match['matchedContactId'];
            $matchReason      = $match['matchReason'];

            if ($existsInCrm) {
                $totalExistentes++;
            }

            $rawJson = json_encode($item, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            $name    = trim($dados['firstName'] . ' ' . $dados['lastName']);

            // Verifica se já existe na tabela contato_executivo
            $existente = $this->buscarContatoExecutivoExistente($pdo, $accountId, $dados['linkedinUrl'], $name);

            if ($existente) {
                // Atualiza
                $stmt = $pdo->prepare("
                    UPDATE contato_executivo SET
                        name = :name, first_name = :firstName, last_name = :lastName,
                        headline = :headline, cargo = :cargo, summary = :summary,
                        picture_url = :pictureUrl, location = :location,
                        connections_count = :connectionsCount, follower_count = :followerCount,
                        premium = :premium, open_to_work = :openToWork,
                        source = :source, raw_json = :rawJson,
                        exists_in_crm = :existsInCrm, matched_contact_id = :matchedContactId,
                        match_reason = :matchReason, modified_at = :modifiedAt,
                        modified_by_id = :modifiedById
                    WHERE id = :id
                ");
                $stmt->execute([
                    ':id'               => $existente['id'],
                    ':name'             => $name,
                    ':firstName'        => $dados['firstName'],
                    ':lastName'         => $dados['lastName'],
                    ':headline'         => $dados['headline'],
                    ':cargo'            => $dados['cargo'],
                    ':summary'          => $dados['summary'],
                    ':pictureUrl'       => $dados['pictureUrl'],
                    ':location'         => $dados['location'],
                    ':connectionsCount' => $dados['connectionsCount'],
                    ':followerCount'    => $dados['followerCount'],
                    ':premium'          => $dados['premium'] ? 1 : 0,
                    ':openToWork'       => $dados['openToWork'] ? 1 : 0,
                    ':source'           => 'harvestapi_employees',
                    ':rawJson'          => $rawJson,
                    ':existsInCrm'      => $existsInCrm ? 1 : 0,
                    ':matchedContactId' => $matchedContactId,
                    ':matchReason'      => $matchReason,
                    ':modifiedAt'       => date('Y-m-d H:i:s'),
                    ':modifiedById'     => $this->getCurrentUserId(),
                ]);
                $totalAtualizados++;
                continue;
            }

            // Insere novo
            $stmt = $pdo->prepare("
                INSERT INTO contato_executivo (
                    id, name, deleted, account_id,
                    first_name, last_name, linkedin_url, public_identifier,
                    headline, cargo, summary, picture_url, location,
                    connections_count, follower_count, premium, open_to_work,
                    source, raw_json,
                    exists_in_crm, matched_contact_id, match_reason,
                    is_created, created_from,
                    created_at, modified_at, created_by_id, modified_by_id
                ) VALUES (
                    :id, :name, 0, :accountId,
                    :firstName, :lastName, :linkedinUrl, :publicIdentifier,
                    :headline, :cargo, :summary, :pictureUrl, :location,
                    :connectionsCount, :followerCount, :premium, :openToWork,
                    :source, :rawJson,
                    :existsInCrm, :matchedContactId, :matchReason,
                    0, :createdFrom,
                    :createdAt, :modifiedAt, :createdById, :modifiedById
                )
            ");
            $stmt->execute([
                ':id'               => $this->generateCustomId(),
                ':name'             => $name,
                ':accountId'        => $accountId,
                ':firstName'        => $dados['firstName'],
                ':lastName'         => $dados['lastName'],
                ':linkedinUrl'      => $dados['linkedinUrl'],
                ':publicIdentifier' => $dados['publicIdentifier'],
                ':headline'         => $dados['headline'],
                ':cargo'            => $dados['cargo'],
                ':summary'          => $dados['summary'],
                ':pictureUrl'       => $dados['pictureUrl'],
                ':location'         => $dados['location'],
                ':connectionsCount' => $dados['connectionsCount'],
                ':followerCount'    => $dados['followerCount'],
                ':premium'          => $dados['premium'] ? 1 : 0,
                ':openToWork'       => $dados['openToWork'] ? 1 : 0,
                ':source'           => 'harvestapi_employees',
                ':rawJson'          => $rawJson,
                ':existsInCrm'      => $existsInCrm ? 1 : 0,
                ':matchedContactId' => $matchedContactId,
                ':matchReason'      => $matchReason,
                ':createdFrom'      => 'linkedin_employee',
                ':createdAt'        => date('Y-m-d H:i:s'),
                ':modifiedAt'       => date('Y-m-d H:i:s'),
                ':createdById'      => $this->getCurrentUserId(),
                ':modifiedById'     => $this->getCurrentUserId(),
            ]);
            $totalSalvos++;
        }

        return (object) [
            'totalSalvos'     => $totalSalvos,
            'totalAtualizados'=> $totalAtualizados,
            'totalExistentes' => $totalExistentes,
        ];
    }

    /**
     * Extrai e normaliza dados de um item retornado pelo harvestapi.
     */
    private function extrairDadosContatoExecutivo(stdClass $item): array
    {
        $firstName = trim((string) ($item->firstName ?? ''));
        $lastName  = trim((string) ($item->lastName ?? ''));

        // Cargo vem em currentPositions[0].title (modo Short)
        $cargo = '';
        if (!empty($item->currentPositions) && is_array($item->currentPositions)) {
            $cargo = trim((string) ($item->currentPositions[0]->title ?? ''));
        }

        // Headline vem direto no modo Full, ou monta do cargo
        $headline = trim((string) ($item->headline ?? $cargo));

        $linkedinUrl      = trim((string) ($item->linkedinUrl ?? ''));
        $publicIdentifier = trim((string) ($item->publicIdentifier ?? ''));
        $summary          = trim((string) ($item->summary ?? $item->about ?? ''));
        $pictureUrl       = trim((string) ($item->pictureUrl ?? $item->photo ?? ''));
        $location         = trim((string) ($item->location->linkedinText ?? $item->location ?? ''));
        $connectionsCount = isset($item->connectionsCount) ? (int) $item->connectionsCount : null;
        $followerCount    = isset($item->followerCount) ? (int) $item->followerCount : null;
        $premium          = (bool) ($item->premium ?? false);
        $openToWork       = (bool) ($item->openToWork ?? false);

        if ($linkedinUrl !== '') {
            $linkedinUrl = $this->normalizeLinkedinUrl($linkedinUrl);
        }

        return [
            'firstName'        => $firstName,
            'lastName'         => $lastName,
            'cargo'            => $cargo,
            'headline'         => $headline,
            'linkedinUrl'      => $linkedinUrl,
            'publicIdentifier' => $publicIdentifier,
            'summary'          => $summary,
            'pictureUrl'       => $pictureUrl,
            'location'         => $location,
            'connectionsCount' => $connectionsCount,
            'followerCount'    => $followerCount,
            'premium'          => $premium,
            'openToWork'       => $openToWork,
        ];
    }

    /**
     * Verifica se já existe um registro na tabela contato_executivo
     * para essa account + linkedin_url ou nome.
     */
    private function buscarContatoExecutivoExistente(\PDO $pdo, string $accountId, string $linkedinUrl, string $name): ?array
    {
        if ($linkedinUrl !== '') {
            $stmt = $pdo->prepare("
                SELECT id FROM contato_executivo
                WHERE deleted = 0 AND account_id = :accountId AND linkedin_url = :linkedinUrl
                LIMIT 1
            ");
            $stmt->execute([':accountId' => $accountId, ':linkedinUrl' => $linkedinUrl]);
            $row = $stmt->fetch(\PDO::FETCH_ASSOC);
            if ($row) return $row;
        }

        if ($name !== '') {
            $stmt = $pdo->prepare("
                SELECT id FROM contato_executivo
                WHERE deleted = 0 AND account_id = :accountId AND name = :name
                LIMIT 1
            ");
            $stmt->execute([':accountId' => $accountId, ':name' => $name]);
            $row = $stmt->fetch(\PDO::FETCH_ASSOC);
            if ($row) return $row;
        }

        return null;
    }

    /**
     * Verifica se já existe um Contact no EspoCRM para esse executivo.
     * Valida por LinkedIn URL (normalizado) ou similaridade de nome (≥85%).
     * O Contact deve estar vinculado à mesma Account.
     */
    private function buscarContatoExistenteNoCrm(\PDO $pdo, string $accountId, string $name, string $linkedinUrl): array
    {
        $normalizedLinkedin = $this->normalizeComparableUrl($linkedinUrl);

        // Valida por LinkedIn URL
        if ($normalizedLinkedin !== '') {
            $stmt = $pdo->prepare("
                SELECT id, first_name, last_name, linkedin_url
                FROM contact
                WHERE deleted = 0
                  AND account_id = :accountId
                  AND linkedin_url IS NOT NULL AND linkedin_url <> ''
            ");
            $stmt->execute([':accountId' => $accountId]);

            while ($row = $stmt->fetch(\PDO::FETCH_ASSOC)) {
                $contactLinkedin = $this->normalizeComparableUrl((string) ($row['linkedin_url'] ?? ''));
                if ($contactLinkedin !== '' && $contactLinkedin === $normalizedLinkedin) {
                    return [
                        'existsInCrm'      => true,
                        'matchedContactId' => $row['id'],
                        'matchReason'      => 'linkedin_match',
                    ];
                }
            }
        }

        // Valida por similaridade de nome (≥85%)
        $normalizedName = $this->normalizePersonName($name);
        if ($normalizedName !== '') {
            $stmt = $pdo->prepare("
                SELECT id, first_name, last_name
                FROM contact
                WHERE deleted = 0 AND account_id = :accountId
            ");
            $stmt->execute([':accountId' => $accountId]);

            $bestId      = null;
            $bestPercent = 0.0;

            while ($row = $stmt->fetch(\PDO::FETCH_ASSOC)) {
                $contactName = $this->normalizePersonName(
                    trim($row['first_name'] . ' ' . $row['last_name'])
                );
                if ($contactName === '') continue;

                similar_text($normalizedName, $contactName, $percent);
                if ($percent > $bestPercent) {
                    $bestPercent = $percent;
                    $bestId = $row['id'];
                }
            }

            if ($bestId && $bestPercent >= 85.0) {
                return [
                    'existsInCrm'      => true,
                    'matchedContactId' => $bestId,
                    'matchReason'      => 'name_similarity',
                ];
            }
        }

        return ['existsInCrm' => false, 'matchedContactId' => null, 'matchReason' => null];
    }

    /**
     * Normaliza nome de pessoa para comparação (lowercase, sem acentos, sem títulos).
     */
    private function normalizePersonName(string $name): string
    {
        $name = mb_strtolower(trim($name));
        if ($name === '') return '';

        $map = [
            'á'=>'a','à'=>'a','ã'=>'a','â'=>'a','é'=>'e','ê'=>'e',
            'í'=>'i','ó'=>'o','ô'=>'o','õ'=>'o','ú'=>'u','ç'=>'c',
        ];
        $name = strtr($name, $map);
        $name = preg_replace('/[^a-z0-9 ]+/', ' ', $name);
        $name = preg_replace('/\s+/', ' ', $name);

        return trim($name);
    }

    /**
     * Lista contatos executivos de uma conta para o painel frontend.
     * Retorna apenas os que ainda não existem no CRM e não foram criados.
     * Também retorna os já existentes com flag exists_in_crm=1 para exibir tag.
     */
    public function postActionListarContatosExecutivos(Request $request): stdClass
    {
        $data      = $request->getParsedBody();
        $accountId = $data->id ?? null;
        $limit     = isset($data->limit) ? (int) $data->limit : 50;

        if (!$accountId) {
            throw new BadRequest('ID da conta não informado.');
        }

        $account = $this->entityManager->getEntityById('Account', (string) $accountId);
        if (!$account) {
            throw new NotFound('Conta não encontrada.');
        }

        $pdo = $this->getCustomPdo();

        // Busca disponíveis (não existem no CRM e não foram criados)
        $stmt = $pdo->prepare("
            SELECT
                id, account_id, first_name, last_name, linkedin_url,
                headline, cargo, summary, picture_url, location,
                connections_count, follower_count, premium, open_to_work,
                exists_in_crm, matched_contact_id, match_reason,
                is_created, created_contact_id, created_at
            FROM contato_executivo
            WHERE deleted = 0
              AND account_id = :accountId
            ORDER BY
                exists_in_crm ASC,
                is_created ASC,
                cargo ASC
            LIMIT " . (int) $limit
        );
        $stmt->execute([':accountId' => (string) $accountId]);
        $rows = $stmt->fetchAll(\PDO::FETCH_ASSOC);

        $items = [];
        foreach ($rows as $row) {
            $items[] = (object) [
                'id'               => $row['id'],
                'accountId'        => $row['account_id'],
                'firstName'        => $row['first_name'],
                'lastName'         => $row['last_name'],
                'name'             => trim($row['first_name'] . ' ' . $row['last_name']),
                'linkedinUrl'      => $row['linkedin_url'],
                'headline'         => $row['headline'],
                'cargo'            => $row['cargo'],
                'summary'          => $row['summary'],
                'pictureUrl'       => $row['picture_url'],
                'location'         => $row['location'],
                'connectionsCount' => $row['connections_count'] !== null ? (int) $row['connections_count'] : null,
                'followerCount'    => $row['follower_count'] !== null ? (int) $row['follower_count'] : null,
                'premium'          => (bool) $row['premium'],
                'openToWork'       => (bool) $row['open_to_work'],
                'existsInCrm'      => (bool) $row['exists_in_crm'],
                'matchedContactId' => $row['matched_contact_id'],
                'matchReason'      => $row['match_reason'],
                'isCreated'        => (bool) $row['is_created'],
                'createdContactId' => $row['created_contact_id'],
                'createdAt'        => $row['created_at'],
            ];
        }

        // Summary counts
        $countStmt = $pdo->prepare("
            SELECT
                COUNT(*) AS total,
                SUM(CASE WHEN exists_in_crm = 1 THEN 1 ELSE 0 END) AS ja_existem,
                SUM(CASE WHEN is_created = 1 THEN 1 ELSE 0 END) AS ja_criados,
                SUM(CASE WHEN exists_in_crm = 0 AND is_created = 0 THEN 1 ELSE 0 END) AS disponiveis
            FROM contato_executivo
            WHERE deleted = 0 AND account_id = :accountId
        ");
        $countStmt->execute([':accountId' => (string) $accountId]);
        $summary = $countStmt->fetch(\PDO::FETCH_ASSOC) ?: [];

        return (object) [
            'success' => true,
            'account' => (object) [
                'id'   => $account->getId(),
                'name' => $account->get('name'),
            ],
            'total'   => count($items),
            'summary' => (object) [
                'total'       => (int) ($summary['total'] ?? 0),
                'jaExistem'   => (int) ($summary['ja_existem'] ?? 0),
                'jaCriados'   => (int) ($summary['ja_criados'] ?? 0),
                'disponiveis' => (int) ($summary['disponiveis'] ?? 0),
            ],
            'list' => $items,
        ];
    }

    /**
     * Cria um Contact no EspoCRM a partir de um ContatoExecutivo.
     * O Contact é criado pelo bot BOT_BUSCA_CONTATO e vinculado à Account.
     */
    public function postActionCriarContatoExecutivo(Request $request): stdClass
    {
        $data      = $request->getParsedBody();
        $executivoId = $data->executivoId ?? null;

        if (!$executivoId) {
            throw new BadRequest('ID do contato executivo não informado.');
        }

        $pdo = $this->getCustomPdo();

        $stmt = $pdo->prepare("
            SELECT * FROM contato_executivo
            WHERE id = :id AND deleted = 0
            LIMIT 1
        ");
        $stmt->execute([':id' => (string) $executivoId]);
        $exec = $stmt->fetch(\PDO::FETCH_ASSOC);

        if (!$exec) {
            throw new NotFound('Contato executivo não encontrado.');
        }

        if ((int) $exec['is_created'] === 1) {
            throw new BadRequest('Este contato executivo já foi criado no CRM.');
        }

        // Verifica novamente se já existe no CRM antes de criar
        $name        = trim($exec['first_name'] . ' ' . $exec['last_name']);
        $linkedinUrl = trim($exec['linkedin_url'] ?? '');

        $match = $this->buscarContatoExistenteNoCrm(
            $pdo,
            (string) $exec['account_id'],
            $name,
            $linkedinUrl
        );

        if ($match['existsInCrm']) {
            // Marca como existente e retorna
            $pdo->prepare("
                UPDATE contato_executivo SET
                    exists_in_crm = 1,
                    matched_contact_id = :matchedContactId,
                    match_reason = :matchReason,
                    modified_at = :modifiedAt,
                    modified_by_id = :modifiedById
                WHERE id = :id
            ")->execute([
                ':id'               => $executivoId,
                ':matchedContactId' => $match['matchedContactId'],
                ':matchReason'      => $match['matchReason'],
                ':modifiedAt'       => date('Y-m-d H:i:s'),
                ':modifiedById'     => $this->getCurrentUserId(),
            ]);

            return (object) [
                'success'          => false,
                'created'          => false,
                'message'          => 'Contato já existe no CRM. Registro marcado como existente.',
                'matchedContactId' => $match['matchedContactId'],
                'matchReason'      => $match['matchReason'],
            ];
        }

        // Cria o Contact no EspoCRM
        $contact = $this->entityManager->getNewEntity('Contact');
        $contact->set('firstName', $exec['first_name'] ?? '');
        $contact->set('lastName', $exec['last_name'] ?? '');
        $contact->set('accountId', $exec['account_id']);
        $contact->set('title', $exec['cargo'] ?? '');
        $contact->set('description', $exec['summary'] ?? '');
        // Salva LinkedIn URL e cargo nos campos customizados do Contact
        if (!empty($exec['linkedin_url'])) {
            $contact->set('linkedinUrl', $exec['linkedin_url']);
        }
        if (!empty($exec['cargo'])) {
            $contact->set('cargo', $exec['cargo']);
        }
        if (!empty($exec['picture_url'])) {
            $contact->set('linkedinPhotoUrl', $exec['picture_url']);
        }

        $this->entityManager->saveEntity($contact);
        $createdContactId = $contact->getId();

        // Atribui ao bot BOT_BUSCA_CONTATO se configurado
        // TODO: adicionar ESPO_BOT_BUSCA_CONTATO_USER_ID em /opt/atria/.env quando o bot for criado
        $botUserId = $this->getBotBuscaContatoUserId();
        if ($botUserId) {
            $pdo->prepare("
                UPDATE contact SET created_by_id = :botUserId, modified_by_id = :botUserId
                WHERE id = :contactId
            ")->execute([
                ':botUserId'  => $botUserId,
                ':contactId'  => $createdContactId,
            ]);
        }

        // Atualiza registro contato_executivo
        $pdo->prepare("
            UPDATE contato_executivo SET
                is_created = 1,
                created_contact_id = :createdContactId,
                created_by_user_id = :createdByUserId,
                created_by_bot_user_id = :createdByBotUserId,
                created_from = 'linkedin_employee',
                exists_in_crm = 1,
                matched_contact_id = :createdContactId,
                match_reason = 'created_from_executive',
                modified_at = :modifiedAt,
                modified_by_id = :modifiedById
            WHERE id = :id
        ")->execute([
            ':id'                 => $executivoId,
            ':createdContactId'   => $createdContactId,
            ':createdByUserId'    => $this->getCurrentUserId(),
            ':createdByBotUserId' => $botUserId,
            ':modifiedAt'         => date('Y-m-d H:i:s'),
            ':modifiedById'       => $this->getCurrentUserId(),
        ]);

        return (object) [
            'success' => true,
            'created' => true,
            'message' => 'Contato criado com sucesso.',
            'record'  => (object) [
                'id'        => $createdContactId,
                'firstName' => $contact->get('firstName'),
                'lastName'  => $contact->get('lastName'),
                'title'     => $contact->get('title'),
                'accountId' => $contact->get('accountId'),
                'website'   => $contact->get('website'),
            ],
        ];
    }

    /**
     * Retorna o ID do bot BOT_BUSCA_CONTATO para criação de contatos.
     * TODO: criar o usuário bot no EspoCRM e adicionar ao .env:
     * ESPO_BOT_BUSCA_CONTATO_USER_ID=xxxxx
     */
    private function getBotBuscaContatoUserId(): ?string
    {
        return $this->getEnvValue('ESPO_BOT_BUSCA_CONTATO_USER_ID');
    }


    /**
     * Endpoint público para buscar e salvar contatos executivos de uma conta já enriquecida.
     * Usado pelo script de carga em lote para contas que já foram enriquecidas antes
     * da funcionalidade de Contatos Executivos existir.
     */
    public function postActionBuscarContatosExecutivos(Request $request): stdClass
    {
        $data      = $request->getParsedBody();
        $accountId = $data->id ?? null;

        if (!$accountId) {
            throw new BadRequest('ID da conta não informado.');
        }

        $account = $this->entityManager->getEntityById('Account', (string) $accountId);
        if (!$account) {
            throw new NotFound('Conta não encontrada.');
        }

        if (!(bool) $account->get('enriquecidaLinkedin')) {
            return (object) [
                'success' => false,
                'message' => 'Esta conta ainda não foi enriquecida.',
                'accountId' => $accountId,
            ];
        }

        $result = $this->buscarESalvarContatosExecutivos($request);

        return (object) [
            'success'    => $result->success ?? false,
            'message'    => $result->message ?? '',
            'accountId'  => $accountId,
            'accountName'=> $account->get('name'),
            'itemsCount' => $result->itemsCount ?? 0,
            'salvos'     => $result->salvos ?? 0,
            'existentes' => $result->existentes ?? 0,
        ];
    }


    /**
     * Chama um Actor Apify no modo ASSÍNCRONO com polling.
     *
     * Fluxo confirmado pelos testes:
     *   1. POST /acts/{actorId}/runs
     *      → resposta: { data: { id: "runId", defaultDatasetId: "datasetId", status: "RUNNING" } }
     *   2. GET  /acts/{actorId}/runs/{runId}
     *      → polling até status = SUCCEEDED (runs levam ~9-20s)
     *   3. GET  /datasets/{datasetId}/items
     *      → retorna array de itens
     */
    private function callApifyActorAsync(string $actorId, string $token, stdClass $input): array
    {
        // ── Passo 1: dispara o run ─────────────────────────────────────────────
        // Não usar rawurlencode no actorId pois o ~ é codificado para %7E e a Apify rejeita
        $runUrl = 'https://api.apify.com/v2/acts/' . $actorId .
            '/runs?token=' . rawurlencode($token);

        $payload = json_encode($input, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($payload === false) {
            throw new BadRequest('Não foi possível montar o payload para o Apify.');
        }

        $ch = curl_init($runUrl);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_CONNECTTIMEOUT => 20,
            CURLOPT_TIMEOUT        => 30,
        ]);

        $response = curl_exec($ch);
        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($response === false || $httpCode < 200 || $httpCode >= 300) {
            throw new BadRequest('Apify /runs falhou HTTP ' . $httpCode . ': ' . $response);
        }

        // Formato real: { data: { id: "runId", defaultDatasetId: "xxx", status: "RUNNING" } }
        $runData  = json_decode($response);
        $runId    = $runData->data->id ?? null;
        $datasetId = $runData->data->defaultDatasetId ?? null;

        if (!$runId || !$datasetId) {
            throw new BadRequest('Apify não retornou runId/datasetId. Resposta: ' . $response);
        }

        // ── Passo 2: polling até SUCCEEDED ────────────────────────────────────
        // Testes mostraram runs levando 9-20s — máx 120s de espera com polling a cada 5s
        $statusUrl = 'https://api.apify.com/v2/acts/' . rawurlencode($actorId) .
            '/runs/' . rawurlencode($runId) . '?token=' . rawurlencode($token);

        $maxWait     = 120;
        $interval    = 5;
        $elapsed     = 0;
        $finalStatus = 'RUNNING';

        while ($elapsed < $maxWait) {
            sleep($interval);
            $elapsed += $interval;

            $ch = curl_init($statusUrl);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CONNECTTIMEOUT => 10,
                CURLOPT_TIMEOUT        => 15,
            ]);
            $statusResp = curl_exec($ch);
            curl_close($ch);

            $statusData  = json_decode($statusResp);
            $finalStatus = $statusData->data->status ?? 'UNKNOWN';

            if ($finalStatus === 'SUCCEEDED') {
                break;
            }

            if (in_array($finalStatus, ['FAILED', 'ABORTED', 'TIMED-OUT'])) {
                throw new BadRequest('Apify run ' . $runId . ' terminou com: ' . $finalStatus);
            }
        }

        if ($finalStatus !== 'SUCCEEDED') {
            throw new BadRequest('Apify run ' . $runId . ' não concluiu em ' . $maxWait . 's. Status: ' . $finalStatus);
        }

        // ── Passo 3: busca o dataset ───────────────────────────────────────────
        // Formato: GET /datasets/{datasetId}/items → array direto de itens
        $datasetUrl = 'https://api.apify.com/v2/datasets/' . rawurlencode($datasetId) .
            '/items?token=' . rawurlencode($token) . '&format=json';

        $ch = curl_init($datasetUrl);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 20,
            CURLOPT_TIMEOUT        => 60,
        ]);
        $datasetResp = curl_exec($ch);
        $httpCode    = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($datasetResp === false || $httpCode < 200 || $httpCode >= 300) {
            throw new BadRequest('Apify dataset falhou HTTP ' . $httpCode . ' para datasetId: ' . $datasetId);
        }

        $items = json_decode($datasetResp);

        if (!is_array($items)) {
            throw new BadRequest('Dataset não retornou array. datasetId: ' . $datasetId . ' resposta: ' . substr($datasetResp, 0, 200));
        }

        return $items;
    }


}