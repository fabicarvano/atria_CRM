#!/bin/bash

ENV_FILE="/opt/atria/.env"

get_env() {
  grep -oP "^${1}=\K[^\r\n]+" "$ENV_FILE" 2>/dev/null | tr -d "\"'" | head -1
}

DB_HOST=$(get_env "DB_HOST"); DB_HOST=${DB_HOST:-localhost}
DB_NAME=$(get_env "DB_NAME")
DB_USER=$(get_env "DB_USER")
DB_PASS=$(get_env "DB_PASS")

mysql_exec() {
  mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1"
}

echo "=================================================="
echo "DIAGNÓSTICO — BACKFILL ENRIQUECIDOS NOVA VERSÃO"
echo "=================================================="

echo
echo "1. Contas enriquecidas sem company_website"
mysql_exec "
SELECT id, name, website, company_website, enriquecida_linkedin, data_enriquecimento_linkedin
FROM account
WHERE deleted = 0
  AND enriquecida_linkedin = 1
  AND (company_website IS NULL OR company_website = '')
ORDER BY data_enriquecimento_linkedin DESC;
"

echo
echo "2. Contatos enriquecidos sem campos novos"
mysql_exec "
SELECT
 id,
 first_name,
 last_name,
 account_id,
 linkedin_url,
 company_name_atual,
 company_linkedin,
 company_website,
 email_corporativo,
 status_validacao_empresa,
 enriquecida_linkedin
FROM contact
WHERE deleted = 0
  AND enriquecida_linkedin = 1
  AND (
    company_name_atual IS NULL OR company_name_atual = ''
    OR company_linkedin IS NULL OR company_linkedin = ''
    OR company_website IS NULL OR company_website = ''
    OR status_validacao_empresa IS NULL OR status_validacao_empresa = ''
  )
ORDER BY modified_at DESC;
"

echo
echo "3. Dados disponíveis em contato_executivo para atualizar Contacts já criados"
mysql_exec "
SELECT
 ce.id AS executivo_id,
 ce.created_contact_id,
 ce.account_id,
 ce.linkedin_url,
 ce.email,
 ce.company_name,
 ce.company_linkedin,
 ce.company_website,
 ce.cargo,
 ce.headline,
 c.enriquecida_linkedin,
 c.company_name_atual,
 c.company_linkedin AS contact_company_linkedin,
 c.email_corporativo
FROM contato_executivo ce
JOIN contact c ON c.id = ce.created_contact_id
WHERE ce.deleted = 0
  AND ce.is_created = 1
  AND ce.created_contact_id IS NOT NULL
ORDER BY ce.created_at DESC
LIMIT 100;
"

echo
echo "4. Redis disponível para contas enriquecidas"
php <<'PHP'
<?php
function envv($k) {
    $v = getenv($k);
    if ($v !== false && trim($v) !== '') return trim($v);
    $lines = is_readable('/opt/atria/.env') ? file('/opt/atria/.env', FILE_IGNORE_NEW_LINES) : [];
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) continue;
        [$name, $val] = explode('=', $line, 2);
        if (trim($name) === $k) return trim(trim($val), "\"'");
    }
    return null;
}

try {
    $r = new Redis();
    $r->connect(envv('REDIS_HOST') ?: '127.0.0.1', (int)(envv('REDIS_PORT') ?: 6379), 2.5);
    if (envv('REDIS_PASS')) $r->auth(envv('REDIS_PASS'));

    $keys = $r->keys('account:linkedin-enrichment:*');
    echo "Total keys account enrichment: " . count($keys) . PHP_EOL;

    foreach (array_slice($keys, 0, 30) as $key) {
        $raw = $r->get($key);
        $j = json_decode($raw);
        $item = $j->items[0] ?? null;
        echo $key . " | accountId=" . ($j->accountId ?? '') .
             " | companyName=" . ($item->companyName ?? '') .
             " | websiteUrl=" . ($item->websiteUrl ?? $item->website ?? '') . PHP_EOL;
    }

    $r->close();
} catch (Throwable $e) {
    echo "ERRO Redis: " . $e->getMessage() . PHP_EOL;
}
PHP

echo
echo "5. Redis disponível para contatos enriquecidos"
php <<'PHP'
<?php
function envv($k) {
    $v = getenv($k);
    if ($v !== false && trim($v) !== '') return trim($v);
    $lines = is_readable('/opt/atria/.env') ? file('/opt/atria/.env', FILE_IGNORE_NEW_LINES) : [];
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) continue;
        [$name, $val] = explode('=', $line, 2);
        if (trim($name) === $k) return trim(trim($val), "\"'");
    }
    return null;
}

try {
    $r = new Redis();
    $r->connect(envv('REDIS_HOST') ?: '127.0.0.1', (int)(envv('REDIS_PORT') ?: 6379), 2.5);
    if (envv('REDIS_PASS')) $r->auth(envv('REDIS_PASS'));

    $keys = $r->keys('contact:linkedin-enrichment:*');
    echo "Total keys contact enrichment: " . count($keys) . PHP_EOL;

    foreach (array_slice($keys, 0, 30) as $key) {
        $raw = $r->get($key);
        $j = json_decode($raw);
        $item = $j->items[0] ?? null;
        echo $key . " | contactId=" . ($j->contactId ?? '') .
             " | companyName=" . ($item->companyName ?? '') .
             " | companyLinkedin=" . ($item->companyLinkedin ?? '') .
             " | companyWebsite=" . ($item->companyWebsite ?? '') .
             " | email=" . ($item->email ?? '') . PHP_EOL;
    }

    $r->close();
} catch (Throwable $e) {
    echo "ERRO Redis: " . $e->getMessage() . PHP_EOL;
}
PHP

echo
echo "6. Contatos com mais de uma conta ativa"
mysql_exec "
SELECT contact_id, COUNT(*) AS ativos
FROM account_contact
WHERE deleted = 0 AND IFNULL(is_inactive,0)=0
GROUP BY contact_id
HAVING COUNT(*) > 1;
"

echo
echo "=================================================="
echo "FIM DO DIAGNÓSTICO"
echo "=================================================="
