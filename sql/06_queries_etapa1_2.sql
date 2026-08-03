-- ============================================================================
-- SQL MODULE 06: CONSULTAS DE REFERÊNCIA (ETAPA 1 & ETAPA 2)
-- ============================================================================

-- 6.1 Preceptores de residentes que atenderam pacientes flamenguistas
SELECT DISTINCT
    pes_pre.nome       AS preceptor,
    prof_pre.CRM       AS crm_preceptor,
    pp.titulacao
FROM ATENDIMENTO a
JOIN PACIENTE         pac      ON a.id_paciente       = pac.id_pessoa
JOIN PESSOA           pes_pac  ON pac.id_pessoa        = pes_pac.id_pessoa
JOIN PAPEL_PRECEPTOR  pp       ON a.id_papel_preceptor = pp.id_papel
JOIN PAPEL_PROFISSIONAL ppp    ON pp.id_papel          = ppp.id_papel
JOIN PROFISSIONAL     prof_pre ON ppp.id_profissional  = prof_pre.id_pessoa
JOIN PESSOA           pes_pre  ON prof_pre.id_pessoa   = pes_pre.id_pessoa
WHERE pes_pac.is_flamengo = TRUE
ORDER BY pes_pre.nome;

-- 6.2 Último atendimento de cada paciente
WITH ultimo_atd AS (
    SELECT
        id_atendimento,
        id_paciente,
        data_hora,
        id_papel_residente,
        id_papel_preceptor,
        ROW_NUMBER() OVER (PARTITION BY id_paciente ORDER BY data_hora DESC) AS rnk
    FROM ATENDIMENTO
)
SELECT
    pes_pac.nome   AS paciente,
    ua.data_hora   AS data_hora_ultimo_atendimento,
    pes_res.nome   AS residente,
    pes_pre.nome   AS preceptor,
    COALESCE(STRING_AGG(proc.nome, ', ' ORDER BY proc.nome), 'Nenhum') AS lista_procedimentos
FROM ultimo_atd ua
JOIN PESSOA            pes_pac ON ua.id_paciente        = pes_pac.id_pessoa
JOIN PAPEL_RESIDENTE   pr      ON ua.id_papel_residente = pr.id_papel
JOIN PAPEL_PROFISSIONAL ppr    ON pr.id_papel           = ppr.id_papel
JOIN PESSOA            pes_res ON ppr.id_profissional   = pes_res.id_pessoa
JOIN PAPEL_PRECEPTOR   pp      ON ua.id_papel_preceptor = pp.id_papel
JOIN PAPEL_PROFISSIONAL ppp    ON pp.id_papel           = ppp.id_papel
JOIN PESSOA            pes_pre ON ppp.id_profissional   = pes_pre.id_pessoa
LEFT JOIN PROCEDIMENTO_REALIZADO prl ON ua.id_atendimento       = prl.id_atendimento
LEFT JOIN PROCEDIMENTO           proc ON prl.codigo_procedimento = proc.codigo
WHERE ua.rnk = 1
GROUP BY pes_pac.nome, ua.data_hora, pes_res.nome, pes_pre.nome
ORDER BY pes_pac.nome;

-- 6.3 Percentual de procedimentos de alto risco realizados por residente
SELECT
    pes.nome                                                 AS residente,
    COUNT(prl.codigo_procedimento)                           AS total_procedimentos,
    COUNT(CASE WHEN proc.nivel_risco = 'ALTO' THEN 1 END)   AS procs_alto_risco,
    ROUND(
        (COUNT(CASE WHEN proc.nivel_risco = 'ALTO' THEN 1 END)::NUMERIC
        / NULLIF(COUNT(prl.codigo_procedimento), 0)::NUMERIC)
        * 100, 2
    )                                                        AS pct_alto_risco
FROM PAPEL_RESIDENTE    pr
JOIN PAPEL_PROFISSIONAL ppr ON pr.id_papel          = ppr.id_papel
JOIN PESSOA             pes ON ppr.id_profissional  = pes.id_pessoa
LEFT JOIN ATENDIMENTO              a   ON pr.id_papel        = a.id_papel_residente
LEFT JOIN PROCEDIMENTO_REALIZADO   prl ON a.id_atendimento   = prl.id_atendimento
LEFT JOIN PROCEDIMENTO             proc ON prl.codigo_procedimento = proc.codigo
GROUP BY pes.id_pessoa, pes.nome
ORDER BY pct_alto_risco DESC NULLS LAST;
