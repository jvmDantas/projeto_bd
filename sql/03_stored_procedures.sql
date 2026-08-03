-- ============================================================================
-- SQL MODULE 03: STORED PROCEDURES (PL/pgSQL)
-- ============================================================================

-- SP 1: sp_registrar_atendimento_completo
CREATE OR REPLACE PROCEDURE sp_registrar_atendimento_completo(
    p_data_hora      TIMESTAMP,
    p_duracao        INT,
    p_id_paciente    INT,
    p_id_residente   INT,
    p_id_preceptor   INT,
    p_procedimentos  JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_atendimento INT;
    v_elem           JSONB;
    v_codigo         INT;
    v_qtd            INT;
    v_tempo          INT;
    v_obs            TEXT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM PACIENTE      WHERE id_pessoa = p_id_paciente)  THEN
        RAISE EXCEPTION 'Paciente % não encontrado.', p_id_paciente;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM PAPEL_RESIDENTE WHERE id_papel = p_id_residente) THEN
        RAISE EXCEPTION 'Residente (papel %) não encontrado.', p_id_residente;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM PAPEL_PRECEPTOR WHERE id_papel = p_id_preceptor) THEN
        RAISE EXCEPTION 'Preceptor (papel %) não encontrado.', p_id_preceptor;
    END IF;

    INSERT INTO ATENDIMENTO (data_hora, duracao_minutos, id_paciente, id_papel_residente, id_papel_preceptor)
    VALUES (p_data_hora, p_duracao, p_id_paciente, p_id_residente, p_id_preceptor)
    RETURNING id_atendimento INTO v_id_atendimento;

    FOR v_elem IN SELECT * FROM jsonb_array_elements(p_procedimentos)
    LOOP
        v_codigo := (v_elem->>'codigo')::INT;
        v_qtd    := COALESCE((v_elem->>'quantidade')::INT, 1);
        v_tempo  := COALESCE((v_elem->>'tempo_real')::INT, 15);
        v_obs    := v_elem->>'observacao';

        IF NOT EXISTS (SELECT 1 FROM PROCEDIMENTO WHERE codigo = v_codigo) THEN
            RAISE EXCEPTION 'Procedimento % não cadastrado.', v_codigo;
        END IF;

        INSERT INTO PROCEDIMENTO_REALIZADO
            (id_atendimento, codigo_procedimento, quantidade, tempo_real_minutos, observacao_intercorrencia, flag_faturado)
        VALUES
            (v_id_atendimento, v_codigo, v_qtd, v_tempo, v_obs, FALSE);
    END LOOP;
END;
$$;

-- SP 2: sp_calcular_tempo_medio_espera
CREATE OR REPLACE FUNCTION sp_calcular_tempo_medio_espera()
RETURNS TABLE (
    id_unidade                 INT,
    nome_unidade               VARCHAR,
    total_atendimentos         BIGINT,
    tempo_medio_espera_minutos NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id_unidade,
        u.nome::VARCHAR                           AS nome_unidade,
        COUNT(a.id_atendimento)                   AS total_atendimentos,
        ROUND(
            COALESCE(
                AVG(
                    EXTRACT(EPOCH FROM (
                        a.data_hora + (a.duracao_minutos::NUMERIC / 2) * INTERVAL '1 minute'
                        - a.data_hora
                    )) / 60.0
                ), 0
            ), 2
        )                                         AS tempo_medio_espera_minutos
    FROM UNIDADE u
    LEFT JOIN ATENDIMENTO a ON a.id_papel_residente IN (
        SELECT ep.id_papel_residente
        FROM   ESCALA_PLANTAO ep
        WHERE  ep.id_unidade = u.id_unidade
    )
    GROUP BY u.id_unidade, u.nome
    ORDER BY u.id_unidade;
END;
$$;

-- SP 3: sp_reajustar_escala
CREATE OR REPLACE PROCEDURE sp_reajustar_escala(
    p_id_residente INT,
    p_dia_antigo   VARCHAR,
    p_turno_antigo VARCHAR,
    p_dia_novo     VARCHAR,
    p_turno_novo   VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_qtd INT;
BEGIN
    SELECT COUNT(*) INTO v_qtd
    FROM   ESCALA_PLANTAO
    WHERE  id_papel_residente = p_id_residente
      AND  LOWER(dia_semana)  = LOWER(p_dia_antigo)
      AND  LOWER(turno)       = LOWER(p_turno_antigo);

    IF v_qtd = 0 THEN
        RAISE EXCEPTION
            'Nenhuma escala encontrada para o residente % no slot "%/"%.',
            p_id_residente, p_dia_antigo, p_turno_antigo;
    END IF;

    UPDATE ESCALA_PLANTAO
    SET    dia_semana = LOWER(p_dia_novo),
           turno      = LOWER(p_turno_novo)
    WHERE  id_papel_residente = p_id_residente
      AND  LOWER(dia_semana)  = LOWER(p_dia_antigo)
      AND  LOWER(turno)       = LOWER(p_turno_antigo);
END;
$$;
