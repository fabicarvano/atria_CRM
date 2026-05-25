#!/bin/bash
set -e

BASE="/opt/atria/www"
CTRL="$BASE/custom/Espo/Custom/Controllers/Contact.php"
TS=$(date +%Y%m%d_%H%M%S)

echo "=================================================="
echo "FASE 3.1 — Backend Contact.php"
echo "=================================================="

echo
echo "1. Backup..."
cp "$CTRL" "$CTRL.bak_fase3_1_$TS"
echo "OK: backup criado: $CTRL.bak_fase3_1_$TS"

echo
echo "2. Aplicando patch incremental..."
python3 <<'PY'
from pathlib import Path

p = Path("/opt/atria/www/custom/Espo/Custom/Controllers/Contact.php")
s = p.read_text()

# 1. Adiciona parsing de empresa/email depois de firstName/lastName.
old = """        $firstName   = trim((string)($item->firstName  ?? ''));
        $lastName    = trim((string)($item->lastName   ?? ''));

        $nivel = $this->inferirNivel($cargo ?: $headline);"""

new = """        $firstName   = trim((string)($item->firstName  ?? ''));
        $lastName    = trim((string)($item->lastName   ?? ''));
        $email       = trim((string)($item->email      ?? ''));
        $companyName = trim((string)($item->companyName ?? ''));
        $companyLinkedin = trim((string)($item->companyLinkedin ?? ''));
        $companyWebsite  = trim((string)($item->companyWebsite  ?? ''));

        if ($companyLinkedin !== '') {
            $companyLinkedin = $this->normalizeLinkedinUrl($companyLinkedin);
        }

        $nivel = $this->inferirNivel($cargo ?: $headline);"""

if old not in s:
    raise SystemExit("ERRO: bloco de parsing não encontrado")

s = s.replace(old, new, 1)

# 2. Adiciona set dos novos campos após location/isInfluencer.
old = """        if ($headline !== '') $contact->set('headline',         $headline);
        if ($location !== '') $contact->set('locationLinkedin', $location);
        $contact->set('isPremium',    $isPremium);
        $contact->set('isCreator',    $isCreator);
        $contact->set('isInfluencer', $isInfluencer);
        if ($nivel !== '')    $contact->set('nivelHierarquico', $nivel);"""

new = """        if ($headline !== '') $contact->set('headline',         $headline);
        if ($location !== '') $contact->set('locationLinkedin', $location);
        $contact->set('isPremium',    $isPremium);
        $contact->set('isCreator',    $isCreator);
        $contact->set('isInfluencer', $isInfluencer);
        if ($nivel !== '')    $contact->set('nivelHierarquico', $nivel);

        if ($companyName !== '')     $contact->set('companyNameAtual', $companyName);
        if ($companyLinkedin !== '') $contact->set('companyLinkedin', $companyLinkedin);
        if ($companyWebsite !== '')  $contact->set('companyWebsite', $companyWebsite);

        if ($email !== '') {
            $contact->set('emailCorporativo', $email);
            $contact->set('fonteEmail', 'apify_linkedin_profile');
            $contact->set('dataEnriquecimentoEmail', date('Y-m-d H:i:s'));
        }"""

if old not in s:
    raise SystemExit("ERRO: bloco de set dos campos não encontrado")

s = s.replace(old, new, 1)

# 3. Antes das flags, adiciona validação/movimentação de empresa.
old = """        // Flags de controle
        $contact->set('enriquecidaLinkedin',        true);"""

new = """        $validacao = $this->validarEMoverEmpresaDoContato($contact, $item, $companyName, $companyLinkedin, $companyWebsite, $cargo, $email);

        // Flags de controle
        $contact->set('enriquecidaLinkedin',        true);"""

if old not in s:
    raise SystemExit("ERRO: ponto de inserção da validação não encontrado")

s = s.replace(old, new, 1)

# 4. Troca mensagem fixa por mensagem dinâmica.
old = """        return (object)[
            'success' => true,
            'message' => 'Contato enriquecido com sucesso.',
            'record'  => (object)["""

new = """        $message = $this->montarMensagemEnriquecimento($email, $validacao);

        return (object)[
            'success' => true,
            'message' => $message,
            'record'  => (object)["""

if old not in s:
    raise SystemExit("ERRO: bloco de retorno não encontrado")

s = s.replace(old, new, 1)

# 5. Adiciona novos campos no retorno.
old = """                'fonteEnriquecimento'        => $contact->get('fonteEnriquecimento'),
            ],
        ];"""

new = """                'fonteEnriquecimento'        => $contact->get('fonteEnriquecimento'),
                'companyNameAtual'            => $contact->get('companyNameAtual'),
                'companyLinkedin'             => $contact->get('companyLinkedin'),
                'companyWebsite'              => $contact->get('companyWebsite'),
                'emailCorporativo'            => $contact->get('emailCorporativo'),
                'fonteEmail'                  => $contact->get('fonteEmail'),
                'dataEnriquecimentoEmail'     => $contact->get('dataEnriquecimentoEmail'),
                'accountIdAnterior'           => $contact->get('accountIdAnterior'),
                'statusValidacaoEmpresa'      => $contact->get('statusValidacaoEmpresa'),
                'accountId'                   => $contact->get('accountId'),
            ],
        ];"""

if old not in s:
    raise SystemExit("ERRO: bloco de retorno record não encontrado")

s = s.replace(old, new, 1)

# 6. Adiciona helpers antes de normalizeUrl.
marker = """    private function normalizeUrl(string $url): string
    {"""

helpers = r'''
    private function validarEMoverEmpresaDoContato($contact, object $item, string $companyName, string $companyLinkedin, string $companyWebsite, string $cargo, string $email): array
    {
        $resultado = [
            'status' => 'pendente_validacao',
            'acao' => 'nenhuma',
            'accountAnteriorId' => null,
            'accountNovoId' => null,
            'accountCriada' => false,
        ];

        $accountIdAtual = (string)($contact->get('accountId') ?? '');

        if ($accountIdAtual === '' || $companyLinkedin === '') {
            $contact->set('statusValidacaoEmpresa', 'empresa_nao_identificada');

            $this->registrarHistoricoEmpresa($contact, null, null, $companyName, $companyLinkedin, $companyWebsite, $cargo, $email, 'empresa_nao_identificada', 'apify_linkedin_profile', $item);

            $resultado['status'] = 'empresa_nao_identificada';
            return $resultado;
        }

        $accountAtual = $this->entityManager->getEntityById('Account', $accountIdAtual);
        $linkedinContaAtual = $accountAtual ? (string)($accountAtual->get('website') ?? '') : '';

        $normAtual = $this->normalizeComparableLinkedin($linkedinContaAtual);
        $normNova = $this->normalizeComparableLinkedin($companyLinkedin);

        if ($normAtual !== '' && $normNova !== '' && $normAtual === $normNova) {
            $contact->set('statusValidacaoEmpresa', 'empresa_validada');

            if ($accountAtual && $companyWebsite !== '' && trim((string)($accountAtual->get('companyWebsite') ?? '')) === '') {
                $accountAtual->set('companyWebsite', $companyWebsite);
                $this->entityManager->saveEntity($accountAtual);
            }

            $this->registrarHistoricoEmpresa($contact, $accountAtual, $accountAtual, $companyName, $companyLinkedin, $companyWebsite, $cargo, $email, 'empresa_validada', 'apify_linkedin_profile', $item);

            $resultado['status'] = 'empresa_validada';
            $resultado['accountAnteriorId'] = $accountIdAtual;
            $resultado['accountNovoId'] = $accountIdAtual;

            return $resultado;
        }

        $novaConta = $this->buscarContaPorLinkedin($companyLinkedin);

        if (!$novaConta) {
            $novaConta = $this->criarContaPorEmpresaLinkedin($companyName, $companyLinkedin, $companyWebsite);
            $resultado['accountCriada'] = true;
        }

        if ($novaConta) {
            $contact->set('accountIdAnterior', $accountIdAtual);
            $contact->set('accountId', $novaConta->getId());
            $contact->set('statusValidacaoEmpresa', 'empresa_divergente_corrigida');

            $this->registrarHistoricoEmpresa($contact, $accountAtual, $novaConta, $companyName, $companyLinkedin, $companyWebsite, $cargo, $email, $resultado['accountCriada'] ? 'conta_criada_automaticamente' : 'empresa_divergente_corrigida', 'apify_linkedin_profile', $item);

            $resultado['status'] = 'empresa_divergente_corrigida';
            $resultado['acao'] = $resultado['accountCriada'] ? 'conta_criada' : 'contato_movido';
            $resultado['accountAnteriorId'] = $accountIdAtual;
            $resultado['accountNovoId'] = $novaConta->getId();

            return $resultado;
        }

        $contact->set('statusValidacaoEmpresa', 'pendente_validacao');

        return $resultado;
    }

    private function buscarContaPorLinkedin(string $companyLinkedin)
    {
        $target = $this->normalizeComparableLinkedin($companyLinkedin);

        if ($target === '') {
            return null;
        }

        $pdo = $this->getPdo();

        $stmt = $pdo->prepare("
            SELECT id, website
            FROM account
            WHERE deleted = 0
              AND website IS NOT NULL
              AND website <> ''
        ");
        $stmt->execute();

        while ($row = $stmt->fetch(\PDO::FETCH_ASSOC)) {
            if ($this->normalizeComparableLinkedin((string)$row['website']) === $target) {
                return $this->entityManager->getEntityById('Account', (string)$row['id']);
            }
        }

        return null;
    }

    private function criarContaPorEmpresaLinkedin(string $companyName, string $companyLinkedin, string $companyWebsite)
    {
        $name = trim($companyName) !== '' ? trim($companyName) : $this->nomeContaPorLinkedin($companyLinkedin);

        if ($name === '') {
            return null;
        }

        $account = $this->entityManager->getNewEntity('Account');
        $account->set('name', $name);
        $account->set('website', $this->normalizeLinkedinUrl($companyLinkedin));

        if ($companyWebsite !== '') {
            $account->set('companyWebsite', $companyWebsite);
        }

        $account->set('fonteEnriquecimento', 'apify_linkedin_profile_contact');
        $account->set('enriquecidaLinkedin', false);

        $this->entityManager->saveEntity($account);

        return $account;
    }

    private function registrarHistoricoEmpresa($contact, $accountAnterior, $accountNovo, string $companyName, string $companyLinkedin, string $companyWebsite, string $cargo, string $email, string $motivo, string $fonte, object $raw): void
    {
        try {
            $pdo = $this->getPdo();

            $rawJson = json_encode($raw, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

            $stmt = $pdo->prepare("
                INSERT INTO contact_company_history (
                    id,
                    contact_id,
                    account_id_anterior,
                    account_id_novo,
                    empresa_anterior,
                    empresa_atual,
                    linkedin_empresa_anterior,
                    linkedin_empresa_atual,
                    company_website,
                    cargo,
                    email,
                    motivo,
                    fonte,
                    raw_json,
                    created_at,
                    created_by_id
                ) VALUES (
                    :id,
                    :contactId,
                    :accountAnteriorId,
                    :accountNovoId,
                    :empresaAnterior,
                    :empresaAtual,
                    :linkedinAnterior,
                    :linkedinAtual,
                    :companyWebsite,
                    :cargo,
                    :email,
                    :motivo,
                    :fonte,
                    :rawJson,
                    :createdAt,
                    :createdById
                )
            ");

            $stmt->execute([
                ':id' => substr(bin2hex(random_bytes(9)), 0, 17),
                ':contactId' => $contact->getId(),
                ':accountAnteriorId' => $accountAnterior ? $accountAnterior->getId() : null,
                ':accountNovoId' => $accountNovo ? $accountNovo->getId() : null,
                ':empresaAnterior' => $accountAnterior ? (string)$accountAnterior->get('name') : null,
                ':empresaAtual' => $companyName !== '' ? $companyName : null,
                ':linkedinAnterior' => $accountAnterior ? (string)$accountAnterior->get('website') : null,
                ':linkedinAtual' => $companyLinkedin !== '' ? $companyLinkedin : null,
                ':companyWebsite' => $companyWebsite !== '' ? $companyWebsite : null,
                ':cargo' => $cargo !== '' ? $cargo : null,
                ':email' => $email !== '' ? $email : null,
                ':motivo' => $motivo,
                ':fonte' => $fonte,
                ':rawJson' => $rawJson ?: null,
                ':createdAt' => date('Y-m-d H:i:s'),
                ':createdById' => $this->getUserId(),
            ]);
        } catch (\Throwable $e) {
        }
    }

    private function montarMensagemEnriquecimento(string $email, array $validacao): string
    {
        $partes = [];

        if (($validacao['acao'] ?? '') === 'conta_criada') {
            $partes[] = 'Nova conta criada automaticamente e contato vinculado.';
        } elseif (($validacao['acao'] ?? '') === 'contato_movido') {
            $partes[] = 'Contato movido automaticamente para a empresa correta.';
        } else {
            $partes[] = 'Contato enriquecido com sucesso.';
        }

        if ($email !== '') {
            $partes[] = 'E-mail encontrado.';
        } else {
            $partes[] = 'Contato enriquecido sem e-mail encontrado.';
        }

        return implode(' ', $partes);
    }

    private function normalizeLinkedinUrl(string $url): string
    {
        $url = trim($url);

        if ($url === '') {
            return '';
        }

        if (!str_starts_with($url, 'http://') && !str_starts_with($url, 'https://')) {
            $url = 'https://' . $url;
        }

        return rtrim($url, '/');
    }

    private function normalizeComparableLinkedin(string $url): string
    {
        $url = mb_strtolower(trim($url));

        if ($url === '') {
            return '';
        }

        $url = preg_replace('#^https?://#', '', $url);
        $url = preg_replace('#^www\.#', '', $url);
        $url = rtrim($url, '/');

        return $url;
    }

    private function nomeContaPorLinkedin(string $url): string
    {
        $normalized = $this->normalizeComparableLinkedin($url);
        $parts = explode('/company/', $normalized);

        if (count($parts) > 1) {
            return ucwords(str_replace(['-', '_'], ' ', trim($parts[1], '/')));
        }

        return '';
    }

    private function getPdo(): \PDO
    {
        return new \PDO(
            'mysql:host=' . ($this->getEnv('DB_HOST') ?: 'localhost') . ';dbname=' . $this->getEnv('DB_NAME') . ';charset=utf8mb4',
            $this->getEnv('DB_USER'),
            $this->getEnv('DB_PASS') ?: '',
            [\PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION]
        );
    }

'''

if marker not in s:
    raise SystemExit("ERRO: marker normalizeUrl não encontrado")

s = s.replace(marker, helpers + marker, 1)

p.write_text(s)
print("OK: Contact.php incrementado")
PY

echo
echo "3. Validando PHP..."
php -l "$CTRL"

echo
echo "4. Conferindo pontos alterados..."
grep -n -C 4 "companyName\\|companyLinkedin\\|companyWebsite\\|emailCorporativo\\|validarEMoverEmpresaDoContato\\|registrarHistoricoEmpresa\\|montarMensagemEnriquecimento" "$CTRL"

echo
echo "5. Rebuild..."
cd "$BASE"
php command.php clear-cache
php command.php rebuild

echo
echo "6. Teste rápido do endpoint com contato de teste..."
CONTACT_ID="6a10e2d28d4292835"

echo "Contato antes:"
mysql -u$(grep -oP '^DB_USER=\K.*' /opt/atria/.env | tr -d '"') \
  -p$(grep -oP '^DB_PASS=\K.*' /opt/atria/.env | tr -d '"') \
  $(grep -oP '^DB_NAME=\K.*' /opt/atria/.env | tr -d '"') \
  -e "SELECT id, account_id, company_linkedin, company_website, company_name_atual, email_corporativo, status_validacao_empresa, enriquecida_linkedin FROM contact WHERE id='${CONTACT_ID}';"

echo
echo "=================================================="
echo "SUCESSO: FASE 3.1 aplicada"
echo "Agora teste pelo botão Enriquecer no contato."
echo "=================================================="
