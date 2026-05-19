#!/bin/bash

set -a
source /opt/atria/.env
set +a

OUT="/opt/atria/diagnostico_profundo_funil_oportunidades_$(date +%Y%m%d_%H%M%S).txt"

echo "Gerando diagnóstico profundo em: $OUT"

mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$OUT" <<'SQL'
SELECT '=== 1. DEFINICAO COMPLETA DA TABELA OPPORTUNITY ===' AS info;
SHOW CREATE TABLE opportunity;

SELECT '=== 2. COLUNAS DA OPPORTUNITY RELACIONADAS A DATA, STAGE, STATUS, CLOSED, WON, LOST ===' AS info;
SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'opportunity'
  AND (
      COLUMN_NAME LIKE '%date%'
      OR COLUMN_NAME LIKE '%stage%'
      OR COLUMN_NAME LIKE '%status%'
      OR COLUMN_NAME LIKE '%close%'
      OR COLUMN_NAME LIKE '%closed%'
      OR COLUMN_NAME LIKE '%won%'
      OR COLUMN_NAME LIKE '%lost%'
      OR COLUMN_NAME LIKE '%probability%'
      OR COLUMN_NAME LIKE '%modified%'
      OR COLUMN_NAME LIKE '%created%'
  )
ORDER BY ORDINAL_POSITION;

SELECT '=== 3. STATUS ATUAL DAS OPORTUNIDADES ===' AS info;
SELECT
    id,
    name,
    stage,
    probability,
    created_at,
    modified_at,
    close_date,
    DATEDIFF(close_date, created_at) AS dias_criacao_ate_close_date,
    amount,
    deleted
FROM opportunity
WHERE deleted = 0
ORDER BY created_at;

SELECT '=== 4. FECHAMENTO NEGATIVO OU SUSPEITO ===' AS info;
SELECT
    id,
    name,
    stage,
    created_at,
    close_date,
    DATEDIFF(close_date, created_at) AS dias_criacao_ate_close_date,
    CASE
        WHEN close_date < DATE(created_at) THEN 'SUSPEITO: close_date antes da criacao'
        WHEN stage NOT IN ('Closed Won', 'Closed Lost', 'Ganha', 'Perdida', 'Fechada Ganha', 'Fechada Perdida') THEN 'PROVAVEL PREVISAO: oportunidade ainda nao fechada'
        ELSE 'possivel fechamento real'
    END AS interpretacao
FROM opportunity
WHERE deleted = 0
ORDER BY created_at;

SELECT '=== 5. TODAS AS NOTES DE STAGE - CREATE E UPDATE ===' AS info;
SELECT
    n.parent_id AS opportunity_id,
    o.name AS oportunidade,
    n.type,
    n.created_at AS data_evento,
    JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusField')) AS status_field,
    JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusValue')) AS status_value,
    JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) AS value_stage,
    n.data
FROM note n
LEFT JOIN opportunity o ON o.id = n.parent_id
WHERE n.deleted = 0
  AND n.parent_type = 'Opportunity'
  AND (
      JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusField')) = 'stage'
      OR JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) IS NOT NULL
  )
ORDER BY n.parent_id, n.created_at;

SELECT '=== 6. LINHA DO TEMPO DE ESTAGIOS NORMALIZADA ===' AS info;
SELECT
    x.opportunity_id,
    x.oportunidade,
    x.data_evento,
    x.stage_detectado,
    x.origem
FROM (
    SELECT
        n.parent_id AS opportunity_id,
        o.name AS oportunidade,
        n.created_at AS data_evento,
        JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusValue')) AS stage_detectado,
        'create_statusValue' AS origem
    FROM note n
    LEFT JOIN opportunity o ON o.id = n.parent_id
    WHERE n.deleted = 0
      AND n.parent_type = 'Opportunity'
      AND n.type = 'Create'
      AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusField')) = 'stage'

    UNION ALL

    SELECT
        n.parent_id AS opportunity_id,
        o.name AS oportunidade,
        n.created_at AS data_evento,
        JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) AS stage_detectado,
        'update_value' AS origem
    FROM note n
    LEFT JOIN opportunity o ON o.id = n.parent_id
    WHERE n.deleted = 0
      AND n.parent_type = 'Opportunity'
      AND n.type = 'Update'
      AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) IS NOT NULL
      AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) <> ''
) x
WHERE x.stage_detectado IS NOT NULL
ORDER BY x.opportunity_id, x.data_evento;

SELECT '=== 7. TEMPO ENTRE MUDANCAS DE ESTAGIO - BASE PARA TEMPO EM CADA ESTAGIO ===' AS info;
WITH timeline AS (
    SELECT
        x.opportunity_id,
        x.oportunidade,
        x.data_evento AS entrou_em,
        x.stage_detectado AS estagio,
        LEAD(x.data_evento) OVER (
            PARTITION BY x.opportunity_id 
            ORDER BY x.data_evento
        ) AS saiu_em,
        LEAD(x.stage_detectado) OVER (
            PARTITION BY x.opportunity_id 
            ORDER BY x.data_evento
        ) AS proximo_estagio
    FROM (
        SELECT
            n.parent_id AS opportunity_id,
            o.name AS oportunidade,
            n.created_at AS data_evento,
            JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusValue')) AS stage_detectado
        FROM note n
        LEFT JOIN opportunity o ON o.id = n.parent_id
        WHERE n.deleted = 0
          AND n.parent_type = 'Opportunity'
          AND n.type = 'Create'
          AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusField')) = 'stage'

        UNION ALL

        SELECT
            n.parent_id AS opportunity_id,
            o.name AS oportunidade,
            n.created_at AS data_evento,
            JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) AS stage_detectado
        FROM note n
        LEFT JOIN opportunity o ON o.id = n.parent_id
        WHERE n.deleted = 0
          AND n.parent_type = 'Opportunity'
          AND n.type = 'Update'
          AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) IS NOT NULL
          AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) <> ''
    ) x
)
SELECT
    opportunity_id,
    oportunidade,
    estagio,
    entrou_em,
    saiu_em,
    COALESCE(saiu_em, NOW()) AS saiu_em_ou_agora,
    TIMESTAMPDIFF(MINUTE, entrou_em, COALESCE(saiu_em, NOW())) AS minutos_no_estagio,
    ROUND(TIMESTAMPDIFF(MINUTE, entrou_em, COALESCE(saiu_em, NOW())) / 60, 2) AS horas_no_estagio,
    ROUND(TIMESTAMPDIFF(MINUTE, entrou_em, COALESCE(saiu_em, NOW())) / 1440, 2) AS dias_no_estagio,
    proximo_estagio
FROM timeline
ORDER BY opportunity_id, entrou_em;

SELECT '=== 8. RESUMO MEDIO POR ESTAGIO ===' AS info;
WITH timeline AS (
    SELECT
        x.opportunity_id,
        x.oportunidade,
        x.data_evento AS entrou_em,
        x.stage_detectado AS estagio,
        LEAD(x.data_evento) OVER (
            PARTITION BY x.opportunity_id 
            ORDER BY x.data_evento
        ) AS saiu_em
    FROM (
        SELECT
            n.parent_id AS opportunity_id,
            o.name AS oportunidade,
            n.created_at AS data_evento,
            JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusValue')) AS stage_detectado
        FROM note n
        LEFT JOIN opportunity o ON o.id = n.parent_id
        WHERE n.deleted = 0
          AND n.parent_type = 'Opportunity'
          AND n.type = 'Create'
          AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusField')) = 'stage'

        UNION ALL

        SELECT
            n.parent_id AS opportunity_id,
            o.name AS oportunidade,
            n.created_at AS data_evento,
            JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) AS stage_detectado
        FROM note n
        LEFT JOIN opportunity o ON o.id = n.parent_id
        WHERE n.deleted = 0
          AND n.parent_type = 'Opportunity'
          AND n.type = 'Update'
          AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) IS NOT NULL
          AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) <> ''
    ) x
)
SELECT
    estagio,
    COUNT(*) AS total_passagens,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, entrou_em, COALESCE(saiu_em, NOW()))) / 60, 2) AS media_horas_no_estagio,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, entrou_em, COALESCE(saiu_em, NOW()))) / 1440, 2) AS media_dias_no_estagio,
    MIN(entrou_em) AS primeira_entrada,
    MAX(entrou_em) AS ultima_entrada
FROM timeline
WHERE estagio IS NOT NULL
GROUP BY estagio
ORDER BY media_horas_no_estagio DESC;

SELECT '=== 9. BUSCANDO EVENTOS DE FECHAMENTO REAL POR STAGE ===' AS info;
WITH timeline AS (
    SELECT
        x.opportunity_id,
        x.oportunidade,
        x.data_evento,
        x.stage_detectado
    FROM (
        SELECT
            n.parent_id AS opportunity_id,
            o.name AS oportunidade,
            n.created_at AS data_evento,
            JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusValue')) AS stage_detectado
        FROM note n
        LEFT JOIN opportunity o ON o.id = n.parent_id
        WHERE n.deleted = 0
          AND n.parent_type = 'Opportunity'
          AND n.type = 'Create'
          AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.statusField')) = 'stage'

        UNION ALL

        SELECT
            n.parent_id AS opportunity_id,
            o.name AS oportunidade,
            n.created_at AS data_evento,
            JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) AS stage_detectado
        FROM note n
        LEFT JOIN opportunity o ON o.id = n.parent_id
        WHERE n.deleted = 0
          AND n.parent_type = 'Opportunity'
          AND n.type = 'Update'
          AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) IS NOT NULL
          AND JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.value')) <> ''
    ) x
)
SELECT
    t.opportunity_id,
    t.oportunidade,
    o.created_at AS criada_em,
    t.data_evento AS data_fechamento_real_detectada,
    t.stage_detectado AS estagio_fechamento,
    TIMESTAMPDIFF(DAY, o.created_at, t.data_evento) AS dias_ate_fechamento_real,
    o.close_date AS close_date_cadastrado,
    DATEDIFF(o.close_date, o.created_at) AS dias_ate_close_date
FROM timeline t
JOIN opportunity o ON o.id = t.opportunity_id
WHERE LOWER(t.stage_detectado) IN (
    'closed won',
    'closed lost',
    'ganha',
    'perdida',
    'fechada ganha',
    'fechada perdida'
)
ORDER BY t.data_evento;

SELECT '=== 10. TAXA DE CONVERSAO PELO STAGE ATUAL ===' AS info;
SELECT
    COUNT(*) AS total_oportunidades,
    SUM(CASE 
        WHEN LOWER(stage) IN ('closed won', 'ganha', 'fechada ganha') THEN 1 
        ELSE 0 
    END) AS oportunidades_ganhas,
    SUM(CASE 
        WHEN LOWER(stage) IN ('closed lost', 'perdida', 'fechada perdida') THEN 1 
        ELSE 0 
    END) AS oportunidades_perdidas,
    ROUND(
        SUM(CASE 
            WHEN LOWER(stage) IN ('closed won', 'ganha', 'fechada ganha') THEN 1 
            ELSE 0 
        END) / COUNT(*) * 100,
        2
    ) AS taxa_conversao_total_percentual,
    ROUND(
        SUM(CASE 
            WHEN LOWER(stage) IN ('closed won', 'ganha', 'fechada ganha') THEN 1 
            ELSE 0 
        END) / NULLIF(SUM(CASE 
            WHEN LOWER(stage) IN ('closed won', 'ganha', 'fechada ganha', 'closed lost', 'perdida', 'fechada perdida') THEN 1 
            ELSE 0 
        END), 0) * 100,
        2
    ) AS win_rate_somente_fechadas_percentual
FROM opportunity
WHERE deleted = 0;
SQL

echo ""
echo "Diagnóstico profundo concluído."
echo "Arquivo gerado:"
echo "$OUT"
echo ""
echo "Para visualizar resumido:"
echo "grep -n -A 80 -B 3 \"=== 4. FECHAMENTO NEGATIVO OU SUSPEITO ===\" $OUT"
echo "grep -n -A 120 -B 3 \"=== 7. TEMPO ENTRE MUDANCAS DE ESTAGIO\" $OUT"
echo "grep -n -A 80 -B 3 \"=== 9. BUSCANDO EVENTOS DE FECHAMENTO REAL\" $OUT"
