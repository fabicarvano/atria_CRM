# Atria CRM

CRM corporativo da Decatron, construído sobre o [EspoCRM](https://www.espocrm.com/) (versão 9.3.6) com customizações proprietárias para o fluxo comercial de cybersecurity e TI.

---

## Visão Geral

O Atria CRM estende o EspoCRM com módulos próprios de enriquecimento de dados via LinkedIn/Apify, gestão de contas similares, pipeline de oportunidades com validações de qualificação, heatmap de cobertura de soluções por conta e geração automática de numeração de oportunidades.

---

## Estrutura do Repositório

```
atria/
├── .env.example              # Template de variáveis de ambiente (copiar para .env)
├── .gitignore
├── docs/                     # Documentação de funcionalidades e deploys
├── schema_banco/
│   └── atria_crm_schema.sql  # Schema do banco (atualizado pelo script)
├── scripts/
│   ├── atualiza_projeto_git.sh          # Dump do schema + git push
│   └── diagnostico_profundo_funil_oportunidades.sh
└── www/                      # Instalação do EspoCRM
    └── custom/               # ← Apenas este diretório é código proprietário
        ├── Espo/Custom/
        │   ├── Controllers/  # Endpoints de API customizados
        │   ├── Hooks/        # Lógica de negócio (eventos de entidade)
        │   └── Resources/    # Metadata JSON, layouts, i18n
        └── Scripts/          # Scripts de manutenção e migração de dados
```

> **Importante:** a pasta `www/` contém a instalação completa do EspoCRM. Apenas `www/custom/` é código proprietário do Atria. O restante é upstream e não deve ser modificado diretamente.

---

## Customizações Proprietárias (`www/custom/`)

### Controllers

| Arquivo | Descrição |
|---|---|
| `Account.php` | Enriquecimento de contas via LinkedIn (Apify), cache Redis, contas similares |
| `ContaSimilar.php` | CRUD de vínculos entre contas similares |
| `ContaSimilarPatch.php` | Atualizações parciais em lote de contas similares |
| `MapeamentoConta.php` | Heatmap de cobertura de soluções por conta |
| `CatalogoOferta.php` | Catálogo de ofertas/soluções da Decatron |
| `RegistroFabricante.php` | Registro de fabricantes parceiros |

### Hooks

| Arquivo | Trigger | Descrição |
|---|---|---|
| `Account/GerarSiglaConta.php` | beforeSave | Gera sigla automática da conta |
| `Account/GerarHeatMapConta.php` | afterSave | Recalcula heatmap de cobertura |
| `Account/AtualizarContasSimilares.php` | afterSave | Sincroniza vínculos de contas similares |
| `Opportunity/GerarNumeroOportunidade.php` | beforeSave | Numera oportunidades sequencialmente |
| `Opportunity/ValidarPipelineOportunidade.php` | beforeSave | Valida regras de avanço de estágio |
| `Opportunity/ValidateQualificationBeforeStageAdvance.php` | beforeSave | Bloqueia avanço sem qualificação completa |
| `RegistroFabricante/DataCriacaoImutavel.php` | beforeSave | Impede alteração da data de criação |

### Scripts de Manutenção

| Arquivo | Descrição |
|---|---|
| `Scripts/preencher_numeros_oportunidades.php` | Backfill de numeração em oportunidades existentes |
| `Scripts/preencher_siglas_contas.php` | Backfill de siglas em contas existentes |

---

## Requisitos

- Debian 12 (Bookworm)
- PHP 8.3 + php-fpm
- MySQL 8.x
- Redis 7.x
- Nginx
- Composer (para dependências do EspoCRM)

---

## Configuração

```bash
# 1. Clonar o repositório
git clone <repo-url> /opt/atria
cd /opt/atria

# 2. Copiar e preencher o .env
cp .env.example .env
nano .env

# 3. Instalar dependências do EspoCRM
cd www
composer install --no-dev --optimize-autoloader

# 4. Permissões
chown -R www-data:www-data /opt/atria/www
chmod -R 755 /opt/atria/www

# 5. Limpar cache após qualquer alteração em custom/
php /opt/atria/www/command.php clear-cache
```

---

## Fluxo de Desenvolvimento

```bash
# Editar arquivos em www/custom/
# ...

# Limpar cache no servidor
php /opt/atria/www/command.php clear-cache

# Atualizar schema e subir para o Git
bash scripts/atualiza_projeto_git.sh
```

O script `atualiza_projeto_git.sh` faz automaticamente:
1. Dump do schema do banco (`schema_banco/atria_crm_schema.sql`) sem dados
2. `git add . && git commit && git push`

---

## Documentação Adicional

- [`docs/DEPLOY_kanban_total.md`](docs/DEPLOY_kanban_total.md) — Deploy da soma por coluna no Kanban de Oportunidades
- [`docs/verificacao_pos_deploy.md`](docs/verificacao_pos_deploy.md) — Checklist de verificação pós-deploy
- [`schema_banco/atria_crm_schema.sql`](schema_banco/atria_crm_schema.sql) — Schema atual do banco

---

## Variáveis de Ambiente

Copie `.env.example` para `.env` e preencha:

| Variável | Descrição |
|---|---|
| `APP_URL` | URL pública do CRM |
| `APP_DIR` | Caminho absoluto da instalação (`/opt/atria/www`) |
| `DB_*` | Credenciais do MySQL |
| `REDIS_*` | Credenciais do Redis |
| `ADMIN_*` | Usuário admin inicial do EspoCRM |
| `PHP_SOCK` | Socket do PHP-FPM para o Nginx |

---

## ⚠️ O que NÃO versionar

Os itens abaixo estão no `.gitignore` e **não devem entrar no repositório**:

- `.env` — credenciais do ambiente
- `www/vendor/` — dependências do Composer (reinstalar com `composer install`)
- `www/data/config.php` e `config-internal.php` — gerados pelo EspoCRM com dados do ambiente
- `www/data/upload/` — anexos e uploads de usuários
- Arquivos `*.bak.*`, `*.bkp*` — backups manuais de desenvolvimento
