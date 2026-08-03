-- ============================================================================
-- SQL MODULE 05: VISÕES DE DADOS (VIEWS)
-- ============================================================================

-- VIEW 1: vw_pacientes_internados
CREATE OR REPLACE VIEW vw_pacientes_internados AS
SELECT
    i.id_internacao,
    pac.id_pessoa          AS id_paciente,
    pes.nome               AS paciente,
    pes.CPF,
    u.nome                 AS unidade,
    i.data_hora_entrada,
    i.motivo
FROM INTERNACAO i
JOIN (
    SELECT id_paciente, MAX(data_hora_entrada) AS ultima_entrada
    FROM   INTERNACAO
    GROUP  BY id_paciente
) ult ON i.id_paciente = ult.id_paciente
      AND i.data_hora_entrada = ult.ultima_entrada
JOIN PACIENTE pac ON i.id_paciente = pac.id_pessoa
JOIN PESSOA   pes ON pac.id_pessoa = pes.id_pessoa
JOIN UNIDADE  u   ON i.id_unidade  = u.id_unidade
WHERE i.data_hora_saida IS NULL;

-- VIEW 2: vw_residentes_sem_supervisor
CREATE OR REPLACE VIEW vw_residentes_sem_supervisor AS
SELECT
    ep.id_escala,
    pes_res.nome                                AS residente,
    u.nome                                      AS unidade,
    ep.dia_semana,
    ep.turno,
    pes_pre.nome                                AS preceptor,
    COALESCE(pp.titulacao, 'Sem Titulação')     AS titulacao_preceptor,
    CASE
        WHEN ppp.data_fim IS NOT NULL
         AND ppp.data_fim < CURRENT_DATE THEN 'Supervisão encerrada'
        ELSE 'Titulação insuficiente'
    END                                         AS motivo
FROM ESCALA_PLANTAO ep
JOIN PAPEL_RESIDENTE   pr   ON ep.id_papel_residente = pr.id_papel
JOIN PAPEL_PROFISSIONAL ppr  ON pr.id_papel           = ppr.id_papel
JOIN PESSOA            pes_res ON ppr.id_profissional = pes_res.id_pessoa
JOIN PAPEL_PRECEPTOR   pp   ON ep.id_papel_preceptor  = pp.id_papel
JOIN PAPEL_PROFISSIONAL ppp  ON pp.id_papel           = ppp.id_papel
JOIN PESSOA            pes_pre ON ppp.id_profissional = pes_pre.id_pessoa
JOIN UNIDADE           u    ON ep.id_unidade          = u.id_unidade
WHERE
    UPPER(COALESCE(pp.titulacao, '')) <> 'DOUTOR'
    OR (ppp.data_fim IS NOT NULL AND ppp.data_fim < CURRENT_DATE);

-- VIEW 3: vw_estatisticas_atendimentos_mensal
CREATE OR REPLACE VIEW vw_estatisticas_atendimentos_mensal AS
WITH stats AS (
    SELECT
        EXTRACT(YEAR  FROM a.data_hora)::INT  AS ano,
        EXTRACT(MONTH FROM a.data_hora)::INT  AS mes,
        COUNT(a.id_atendimento)               AS total_atendimentos,
        ROUND(AVG(a.duracao_minutos), 2)      AS media_duracao_minutos
    FROM ATENDIMENTO a
    GROUP BY EXTRACT(YEAR FROM a.data_hora), EXTRACT(MONTH FROM a.data_hora)
),
proc_rank AS (
    SELECT
        EXTRACT(YEAR  FROM a.data_hora)::INT  AS ano,
        EXTRACT(MONTH FROM a.data_hora)::INT  AS mes,
        proc.nome                             AS procedimento,
        COUNT(*)                              AS qtd,
        ROW_NUMBER() OVER (
            PARTITION BY EXTRACT(YEAR FROM a.data_hora), EXTRACT(MONTH FROM a.data_hora)
            ORDER BY COUNT(*) DESC
        )                                     AS rnk
    FROM ATENDIMENTO a
    JOIN PROCEDIMENTO_REALIZADO pr ON a.id_atendimento       = pr.id_atendimento
    JOIN PROCEDIMENTO proc         ON pr.codigo_procedimento = proc.codigo
    GROUP BY
        EXTRACT(YEAR  FROM a.data_hora),
        EXTRACT(MONTH FROM a.data_hora),
        proc.nome
)
SELECT
    s.ano,
    s.mes,
    s.total_atendimentos,
    s.media_duracao_minutos,
    COALESCE(p.procedimento, 'Sem registros') AS procedimento_mais_comum
FROM stats s
LEFT JOIN proc_rank p ON s.ano = p.ano AND s.mes = p.mes AND p.rnk = 1
ORDER BY s.ano DESC, s.mes DESC;
