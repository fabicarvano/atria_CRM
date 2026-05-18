#!/bin/bash

set -a
source /opt/atria/.env
set +a

OUT="/opt/atria/diagnostico_indicadores_oportunidades_v2_$(date +%Y%m%d_%H%M%S).txt"

echo "Gerando diagnóstico em: $OUT"

mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$OUT" <<'SQL'
SELECT '=== 1. COLUNAS DA TABELA OPPORTUNITY ===' AS info;

SHOW COLUMNS FROM opportunity;

SELECT '=== 2. AMOSTRA DE OPORTUNIDADES ===' AS info;

SELECT 
    id,
    name,
    stage,
    created_at,
    modified_at,
    close_date,
    amount,
    deleted
FROM opportunity
ORDER BY created_at DESC
LIMIT 20;

SELECT '=== 3. VALORES EXISTENTES DE STAGE ===' AS info;

SELECT 
    stage,
    COUNT(*) AS total
FROM opportunity
WHERE deleted = 0
GROUP BY stage
ORDER BY total DESC;

SELECT '=== 4. VERIFICANDO CAMPOS DE DATA PARA ABERTURA E FECHAMENTO ===' AS info;

SELECT 
    COUNT(*) AS total_oportunidades,
    SUM(CASE WHEN created_at IS NOT NULL THEN 1 ELSE 0 END) AS com_data_criacao,
    SUM(CASE WHEN close_date IS NOT NULL THEN 1 ELSE 0 END) AS com_data_fechamento,
    MIN(created_at) AS primeira_criada,
    MAX(created_at) AS ultima_criada,
    MIN(close_date) AS primeiro_fechamento,
    MAX(close_date) AS ultimo_fechamento
FROM opportunity
WHERE deleted = 0;

SELECT '=== 5. TEMPO ENTRE ABERTURA E FECHAMENTO ===' AS info;

SELECT 
    id,
    name,
    stage,
    created_at,
    close_date,
    DATEDIFF(close_date, created_at) AS dias_entre_abertura_e_fechamento
FROM opportunity
WHERE deleted = 0
  AND created_at IS NOT NULL
  AND close_date IS NOT NULL
ORDER BY created_at DESC
LIMIT 30;

SELECT '=== 6. MEDIA DE TEMPO ENTRE ABERTURA E FECHAMENTO POR STAGE ===' AS info;

SELECT 
    stage,
    COUNT(*) AS total,
    ROUND(AVG(DATEDIFF(close_date, created_at)), 2) AS media_dias_fechamento
FROM opportunity
WHERE deleted = 0
  AND created_at IS NOT NULL
  AND close_date IS NOT NULL
GROUP BY stage
ORDER BY media_dias_fechamento DESC;

SELECT '=== 7. CONVERSAO SIMPLES POR STAGE ===' AS info;

SELECT 
    COUNT(*) AS total_oportunidades,
    SUM(CASE 
        WHEN LOWER(stage) LIKE '%won%' 
          OR LOWER(stage) LIKE '%ganh%' 
          OR LOWER(stage) LIKE '%fechada ganha%'
        THEN 1 ELSE 0 
    END) AS oportunidades_ganhas,
    ROUND(
        SUM(CASE 
            WHEN LOWER(stage) LIKE '%won%' 
              OR LOWER(stage) LIKE '%ganh%' 
              OR LOWER(stage) LIKE '%fechada ganha%'
            THEN 1 ELSE 0 
        END) / COUNT(*) * 100,
        2
    ) AS taxa_conversao_percentual
FROM opportunity
WHERE deleted = 0;

SELECT '=== 8. TABELAS POSSIVEIS DE HISTORICO / STREAM / AUDITORIA ===' AS info;

SELECT 
    table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND (
      table_name LIKE '%note%'
      OR table_name LIKE '%stream%'
      OR table_name LIKE '%audit%'
      OR table_name LIKE '%log%'
      OR table_name LIKE '%history%'
      OR table_name LIKE '%opportunity%'
  )
ORDER BY table_name;

SELECT '=== 9. COLUNAS DA TABELA NOTE ===' AS info;

SHOW COLUMNS FROM note;

SELECT '=== 10. AMOSTRA DE NOTES DE OPORTUNIDADE ===' AS info;

SELECT 
    id,
    type,
    parent_type,
    parent_id,
    related_type,
    related_id,
    created_at,
    created_by_id,
    data
FROM note
WHERE deleted = 0
  AND (
      parent_type = 'Opportunity'
      OR related_type = 'Opportunity'
  )
ORDER BY created_at DESC
LIMIT 30;

SELECT '=== 11. BUSCANDO POSSIVEIS ALTERACOES DE STAGE EM NOTE.DATA ===' AS info;

SELECT 
    id,
    type,
    parent_type,
    parent_id,
    related_type,
    related_id,
    created_at,
    data
FROM note
WHERE deleted = 0
  AND data LIKE '%stage%'
ORDER BY created_at DESC
LIMIT 50;

SELECT '=== 12. BUSCANDO POSSIVEIS ALTERACOES DE STAGE EM NOTE POR TEXTO ===' AS info;

SELECT 
    id,
    type,
    parent_type,
    parent_id,
    related_type,
    related_id,
    created_at,
    data
FROM note
WHERE deleted = 0
  AND (
      data LIKE '%Estágio%'
      OR data LIKE '%stage%'
      OR data LIKE '%Stage%'
      OR data LIKE '%status%'
      OR data LIKE '%Status%'
  )
ORDER BY created_at DESC
LIMIT 50;
SQL

echo ""
echo "Diagnóstico concluído."
echo "Arquivo gerado:"
echo "$OUT"
echo ""
echo "Para visualizar:"
echo "cat $OUT"
