#!/bin/bash
set -e

TS=$(date +%Y%m%d_%H%M%S)
PHP="/opt/atria/completar_contas_enriquecidas_${TS}.php"
LOG="/opt/atria/completar_contas_enriquecidas_${TS}.log"

cat > "$PHP" <<'PHP'
<?php

function envv($key) {
    $lines = is_readable('/opt/atria/.env') ? file('/opt/atria/.env', FILE_IGNORE_NEW_LINES) : [];
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) continue;
        [$k, $v] = explode('=', $line, 2);
        if (trim($k) === $key) return trim(trim($v), "\"'");
    }
    return getenv($key) ?: null;
}

function id17() {
    return substr(bin2hex(random_bytes(9)), 0, 17);
}

function normLinkedin($url) {
    $url = trim((string)$url);
    if ($url === '') return '';
    if (!str_starts_with($url, 'http://') && !str_starts_with($url, 'https://')) {
        $url = 'https://' . $url;
    }
    return rtrim($url, '/');
}

function callCompanyActor($token, $linkedinUrl) {
    $actorId = 'AjfNXEI9qTA2IdaAX';
    $url = "https://api.apify.com/v2/acts/{$actorId}/run-sync-get-dataset-items?token=" . rawurlencode($token);

    $payload = json_encode(['profileUrls' => [$linkedinUrl]], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_POSTFIELDS => $payload,
        CURLOPT_CONNECTTIMEOUT => 20,
        CURLOPT_TIMEOUT => 180,
    ]);

    $resp = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);

    if ($resp === false) throw new Exception("Erro cURL: {$err}");
    if ($code < 200 || $code >= 300) throw new Exception("Apify HTTP {$code}: " . substr($resp, 0, 300));

    $data = json_decode($resp);
    if (!is_array($data) || empty($data[0])) throw new Exception("Apify não retornou item válido.");

    return $data[0];
}

$pdo = new PDO(
    'mysql:host=' . (envv('DB_HOST') ?: 'localhost') . ';dbname=' . envv('DB_NAME') . ';charset=utf8mb4',
    envv('DB_USER'),
    envv('DB_PASS') ?: '',
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$token = envv('APIFY_API_TOKEN');
if (!$token) {
    throw new Exception('APIFY_API_TOKEN ausente no .env');
}

echo "==================================================\n";
echo "BACKFILL — CONTAS ENRIQUECIDAS\n";
echo "==================================================\n\n";

$stmt = $pdo->query("
    SELECT id, name, website, company_website, industria_linkedin, employee_count_linkedin, logo_url, enriquecida_linkedin
    FROM account
    WHERE deleted = 0
      AND enriquecida_linkedin = 1
    ORDER BY name
");

$accounts = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Contas marcadas como enriquecidas: " . count($accounts) . "\n\n";

foreach ($accounts as $a) {
    $status = empty($a['company_website']) ? 'PARCIAL' : 'COMPLETA';
    echo "- {$a['name']} | {$a['id']} | {$status} | website={$a['website']} | company_website={$a['company_website']}\n";
}

echo "\n==================================================\n";
echo "INICIANDO COMPLEMENTAÇÃO\n";
echo "==================================================\n\n";

$ok = 0;
$skip = 0;
$fail = 0;

foreach ($accounts as $a) {
    $id = $a['id'];
    $name = $a['name'];
    $linkedin = normLinkedin($a['website'] ?? '');

    if ($linkedin === '') {
        echo "SKIP {$name}: sem LinkedIn no campo website.\n";
        $skip++;
        continue;
    }

    if (!empty($a['company_website'])) {
        echo "SKIP {$name}: já possui company_website.\n";
        $skip++;
        continue;
    }

    echo "PROCESSANDO {$name} ({$id})...\n";

    try {
        $item = callCompanyActor($token, $linkedin);

        $companyName = trim((string)($item->companyName ?? $item->name ?? ''));
        $websiteUrl = trim((string)($item->websiteUrl ?? $item->website ?? $item->companyWebsite ?? ''));
        $industry = trim((string)($item->industry ?? ''));
        $employeeCount = isset($item->employeeCount) ? (int)$item->employeeCount : null;
        $description = trim((string)($item->description ?? ''));
        $logoUrl = trim((string)($item->logoResolutionResult ?? $item->logoUrl ?? $item->logo ?? ''));

        $upd = $pdo->prepare("
            UPDATE account
            SET
                company_website = COALESCE(NULLIF(:companyWebsite, ''), company_website),
                industria_linkedin = COALESCE(NULLIF(:industry, ''), industria_linkedin),
                employee_count_linkedin = COALESCE(:employeeCount, employee_count_linkedin),
                logo_url = COALESCE(NULLIF(:logoUrl, ''), logo_url),
                description = CASE
                    WHEN (description IS NULL OR description = '') AND :description <> '' THEN :description
                    ELSE description
                END,
                enriquecida_linkedin = 1,
                fonte_enriquecimento = 'apify_linkedin_company_backfill',
                data_enriquecimento_linkedin = NOW()
            WHERE id = :id
        ");

        $upd->execute([
            ':companyWebsite' => $websiteUrl,
            ':industry' => $industry,
            ':employeeCount' => $employeeCount,
            ':logoUrl' => $logoUrl,
            ':description' => $description,
            ':id' => $id,
        ]);

        $similares = $item->similarOrganizations ?? [];
        if (is_array($similares)) {
            foreach ($similares as $s) {
                $simName = trim((string)($s->name ?? $s->companyName ?? ''));
                $simLinkedin = normLinkedin((string)($s->linkedinUrl ?? $s->url ?? ''));
                if ($simName === '' && $simLinkedin === '') continue;

                $raw = json_encode($s, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

                $exists = $pdo->prepare("
                    SELECT id FROM conta_similar
                    WHERE deleted = 0
                      AND account_id = :accountId
                      AND (
                        (:linkedinUrl <> '' AND linkedin_url = :linkedinUrl)
                        OR (:name <> '' AND name = :name)
                      )
                    LIMIT 1
                ");
                $exists->execute([
                    ':accountId' => $id,
                    ':linkedinUrl' => $simLinkedin,
                    ':name' => $simName,
                ]);

                $row = $exists->fetch(PDO::FETCH_ASSOC);

                if ($row) {
                    $q = $pdo->prepare("
                        UPDATE conta_similar
                        SET
                            name = COALESCE(NULLIF(:name, ''), name),
                            linkedin_url = COALESCE(NULLIF(:linkedinUrl, ''), linkedin_url),
                            website_url = COALESCE(NULLIF(:websiteUrl, ''), website_url),
                            industry = COALESCE(NULLIF(:industry, ''), industry),
                            employee_count = COALESCE(:employeeCount, employee_count),
                            description = COALESCE(NULLIF(:description, ''), description),
                            logo_url = COALESCE(NULLIF(:logoUrl, ''), logo_url),
                            raw_json = :rawJson,
                            modified_at = NOW()
                        WHERE id = :id
                    ");
                    $q->execute([
                        ':id' => $row['id'],
                        ':name' => $simName,
                        ':linkedinUrl' => $simLinkedin,
                        ':websiteUrl' => trim((string)($s->websiteUrl ?? $s->website ?? '')),
                        ':industry' => trim((string)($s->industry ?? '')),
                        ':employeeCount' => isset($s->employeeCount) ? (int)$s->employeeCount : null,
                        ':description' => trim((string)($s->description ?? '')),
                        ':logoUrl' => trim((string)($s->logoResolutionResult ?? $s->logoUrl ?? $s->logo ?? '')),
                        ':rawJson' => $raw,
                    ]);
                } else {
                    $q = $pdo->prepare("
                        INSERT INTO conta_similar (
                            id, name, deleted, account_id, linkedin_url, website_url,
                            industry, employee_count, description, logo_url,
                            source, raw_json, exists_in_crm, is_created,
                            created_at, modified_at
                        ) VALUES (
                            :id, :name, 0, :accountId, :linkedinUrl, :websiteUrl,
                            :industry, :employeeCount, :description, :logoUrl,
                            'apify_linkedin_company_backfill', :rawJson, 0, 0,
                            NOW(), NOW()
                        )
                    ");
                    $q->execute([
                        ':id' => id17(),
                        ':name' => $simName,
                        ':accountId' => $id,
                        ':linkedinUrl' => $simLinkedin,
                        ':websiteUrl' => trim((string)($s->websiteUrl ?? $s->website ?? '')),
                        ':industry' => trim((string)($s->industry ?? '')),
                        ':employeeCount' => isset($s->employeeCount) ? (int)$s->employeeCount : null,
                        ':description' => trim((string)($s->description ?? '')),
                        ':logoUrl' => trim((string)($s->logoResolutionResult ?? $s->logoUrl ?? $s->logo ?? '')),
                        ':rawJson' => $raw,
                    ]);
                }
            }
        }

        echo "OK {$name}: company_website={$websiteUrl}, industry={$industry}, employeeCount={$employeeCount}\n";
        $ok++;

        sleep(2);

    } catch (Throwable $e) {
        echo "ERRO {$name}: " . $e->getMessage() . "\n";
        $fail++;
    }
}

echo "\n==================================================\n";
echo "RESULTADO\n";
echo "OK: {$ok}\n";
echo "SKIP: {$skip}\n";
echo "ERRO: {$fail}\n";
echo "==================================================\n";

echo "\nValidação final:\n";

$q = $pdo->query("
    SELECT id, name, website, company_website, industria_linkedin, employee_count_linkedin, enriquecida_linkedin
    FROM account
    WHERE deleted = 0
      AND enriquecida_linkedin = 1
    ORDER BY name
");

foreach ($q->fetchAll(PDO::FETCH_ASSOC) as $r) {
    $status = empty($r['company_website']) ? 'AINDA_PARCIAL' : 'COMPLETA';
    echo "{$status} | {$r['name']} | company_website={$r['company_website']} | funcionarios={$r['employee_count_linkedin']}\n";
}
PHP

echo "Executando backfill..."
php "$PHP" | tee "$LOG"

echo
echo "Log salvo em: $LOG"
echo "Script PHP salvo em: $PHP"
