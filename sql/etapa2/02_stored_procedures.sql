-- ============================================================================
-- ETAPA 2 - PONTO 1: STORED PROCEDURES
-- Executar depois de sql/etapa2/01_alteracoes_schema.sql.
--
-- As procedures nao executam COMMIT nem ROLLBACK. Qualquer excecao e propagada
-- ao chamador, que permanece responsavel pelo controle da transacao.
-- ============================================================================

-- Registra um atendimento e todos os seus procedimentos como uma unica
-- operacao atomica. O id criado e devolvido em p_id_atendimento.
CREATE OR REPLACE PROCEDURE sp_registrar_atendimento_completo(
    IN p_data_hora TIMESTAMP,
    IN p_duracao_minutos INTEGER,
    IN p_id_paciente INTEGER,
    IN p_id_papel_residente INTEGER,
    IN p_id_papel_preceptor INTEGER,
    IN p_id_unidade INTEGER,
    IN p_procedimentos JSONB,
    OUT p_id_atendimento INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item JSONB;
    v_posicao INTEGER;
    v_data_hora_inicio TIMESTAMP;
    v_codigo_inexistente INTEGER;
    v_codigo_duplicado INTEGER;
BEGIN
    p_id_atendimento := NULL;

    IF p_data_hora IS NULL THEN
        RAISE EXCEPTION 'A data e hora de chegada do atendimento e obrigatoria';
    END IF;

    IF p_duracao_minutos IS NULL OR p_duracao_minutos <= 0 THEN
        RAISE EXCEPTION 'A duracao do atendimento deve ser maior que zero';
    END IF;

    IF p_id_paciente IS NULL
       OR NOT EXISTS (
            SELECT 1 FROM paciente WHERE id_pessoa = p_id_paciente
       ) THEN
        RAISE EXCEPTION 'Paciente inexistente: %', p_id_paciente;
    END IF;

    IF p_id_papel_residente IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM papel_residente
            WHERE id_papel = p_id_papel_residente
       ) THEN
        RAISE EXCEPTION 'Papel de residente inexistente: %', p_id_papel_residente;
    END IF;

    IF p_id_papel_preceptor IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM papel_preceptor
            WHERE id_papel = p_id_papel_preceptor
       ) THEN
        RAISE EXCEPTION 'Papel de preceptor inexistente: %', p_id_papel_preceptor;
    END IF;

    IF p_id_unidade IS NULL
       OR NOT EXISTS (
            SELECT 1 FROM unidade WHERE id_unidade = p_id_unidade
       ) THEN
        RAISE EXCEPTION 'Unidade inexistente: %', p_id_unidade;
    END IF;

    IF p_procedimentos IS NULL THEN
        RAISE EXCEPTION 'A lista JSONB de procedimentos e obrigatoria';
    END IF;

    IF jsonb_typeof(p_procedimentos) <> 'array' THEN
        RAISE EXCEPTION 'A lista de procedimentos deve ser um array JSONB';
    END IF;

    IF jsonb_array_length(p_procedimentos) = 0 THEN
        RAISE EXCEPTION 'A lista de procedimentos nao pode ser vazia';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_procedimentos) AS elemento(item)
        WHERE jsonb_typeof(item) <> 'object'
    ) THEN
        RAISE EXCEPTION 'Cada item da lista de procedimentos deve ser um objeto JSON';
    END IF;

    -- Valida campos e tipos antes de converter o array em registros SQL.
    FOR v_item, v_posicao IN
        SELECT item, ordinalidade::INTEGER
        FROM jsonb_array_elements(p_procedimentos)
             WITH ORDINALITY AS elemento(item, ordinalidade)
    LOOP
        IF NOT (v_item ? 'codigo_procedimento')
           OR v_item->'codigo_procedimento' = 'null'::JSONB
           OR NOT (v_item ? 'quantidade')
           OR v_item->'quantidade' = 'null'::JSONB
           OR NOT (v_item ? 'tempo_real_minutos')
           OR v_item->'tempo_real_minutos' = 'null'::JSONB
           OR NOT (v_item ? 'data_hora_inicio')
           OR v_item->'data_hora_inicio' = 'null'::JSONB THEN
            RAISE EXCEPTION
                'Item %: codigo_procedimento, quantidade, tempo_real_minutos e data_hora_inicio sao obrigatorios',
                v_posicao;
        END IF;

        IF jsonb_typeof(v_item->'codigo_procedimento') <> 'number'
           OR (v_item->>'codigo_procedimento') !~ '^-?[0-9]+$' THEN
            RAISE EXCEPTION 'Item %: codigo_procedimento deve ser um inteiro', v_posicao;
        END IF;

        IF jsonb_typeof(v_item->'quantidade') <> 'number'
           OR (v_item->>'quantidade') !~ '^-?[0-9]+$' THEN
            RAISE EXCEPTION 'Item %: quantidade deve ser um inteiro', v_posicao;
        END IF;

        IF (v_item->>'quantidade')::INTEGER <= 0 THEN
            RAISE EXCEPTION 'Item %: quantidade deve ser maior que zero', v_posicao;
        END IF;

        IF jsonb_typeof(v_item->'tempo_real_minutos') <> 'number'
           OR (v_item->>'tempo_real_minutos') !~ '^-?[0-9]+$' THEN
            RAISE EXCEPTION 'Item %: tempo_real_minutos deve ser um inteiro', v_posicao;
        END IF;

        IF (v_item->>'tempo_real_minutos')::INTEGER <= 0 THEN
            RAISE EXCEPTION 'Item %: tempo_real_minutos deve ser maior que zero', v_posicao;
        END IF;

        IF jsonb_typeof(v_item->'data_hora_inicio') <> 'string' THEN
            RAISE EXCEPTION 'Item %: data_hora_inicio deve ser uma data e hora em formato textual', v_posicao;
        END IF;

        BEGIN
            v_data_hora_inicio := (v_item->>'data_hora_inicio')::TIMESTAMP;
        EXCEPTION
            WHEN invalid_datetime_format OR datetime_field_overflow THEN
                RAISE EXCEPTION 'Item %: data_hora_inicio invalida: %',
                    v_posicao,
                    v_item->>'data_hora_inicio';
        END;

        IF v_data_hora_inicio < p_data_hora THEN
            RAISE EXCEPTION
                'Item %: o inicio do procedimento nao pode ser anterior a chegada do paciente',
                v_posicao;
        END IF;

        IF v_item ? 'observacao_intercorrencia'
           AND v_item->'observacao_intercorrencia' <> 'null'::JSONB
           AND jsonb_typeof(v_item->'observacao_intercorrencia') <> 'string' THEN
            RAISE EXCEPTION 'Item %: observacao_intercorrencia deve ser textual ou nula', v_posicao;
        END IF;

        IF v_item ? 'flag_faturado'
           AND v_item->'flag_faturado' <> 'null'::JSONB
           AND jsonb_typeof(v_item->'flag_faturado') <> 'boolean' THEN
            RAISE EXCEPTION 'Item %: flag_faturado deve ser booleano', v_posicao;
        END IF;
    END LOOP;

    SELECT (item->>'codigo_procedimento')::INTEGER
    INTO v_codigo_duplicado
    FROM jsonb_array_elements(p_procedimentos) AS elemento(item)
    GROUP BY (item->>'codigo_procedimento')::INTEGER
    HAVING COUNT(*) > 1
    ORDER BY (item->>'codigo_procedimento')::INTEGER
    LIMIT 1;

    IF v_codigo_duplicado IS NOT NULL THEN
        RAISE EXCEPTION
            'Codigo de procedimento repetido na lista: %; use a coluna quantidade para representar multiplicidade',
            v_codigo_duplicado;
    END IF;

    SELECT (item->>'codigo_procedimento')::INTEGER
    INTO v_codigo_inexistente
    FROM jsonb_array_elements(p_procedimentos) AS elemento(item)
    WHERE NOT EXISTS (
        SELECT 1
        FROM procedimento AS p
        WHERE p.codigo = (item->>'codigo_procedimento')::INTEGER
    )
    ORDER BY (item->>'codigo_procedimento')::INTEGER
    LIMIT 1;

    IF v_codigo_inexistente IS NOT NULL THEN
        RAISE EXCEPTION 'Codigo de procedimento inexistente: %', v_codigo_inexistente;
    END IF;

    INSERT INTO atendimento (
        data_hora,
        duracao_minutos,
        id_paciente,
        id_papel_residente,
        id_papel_preceptor,
        id_unidade
    )
    VALUES (
        p_data_hora,
        p_duracao_minutos,
        p_id_paciente,
        p_id_papel_residente,
        p_id_papel_preceptor,
        p_id_unidade
    )
    RETURNING id_atendimento INTO p_id_atendimento;

    INSERT INTO procedimento_realizado (
        id_atendimento,
        codigo_procedimento,
        quantidade,
        tempo_real_minutos,
        data_hora_inicio,
        observacao_intercorrencia,
        flag_faturado
    )
    SELECT
        p_id_atendimento,
        item.codigo_procedimento,
        item.quantidade,
        item.tempo_real_minutos,
        item.data_hora_inicio,
        item.observacao_intercorrencia,
        COALESCE(item.flag_faturado, FALSE)
    FROM jsonb_to_recordset(p_procedimentos) AS item(
        codigo_procedimento INTEGER,
        quantidade INTEGER,
        tempo_real_minutos INTEGER,
        data_hora_inicio TIMESTAMP,
        observacao_intercorrencia TEXT,
        flag_faturado BOOLEAN
    );
END;
$$;


-- Abre um cursor tabular com a media, em minutos, entre a chegada e o inicio
-- do primeiro procedimento de cada atendimento. Todas as unidades aparecem.
CREATE OR REPLACE PROCEDURE sp_calcular_tempo_medio_espera(
    INOUT p_cursor REFCURSOR DEFAULT 'cur_tempo_medio_espera'
)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_cursor FOR
        WITH primeiro_procedimento AS (
            SELECT
                pr.id_atendimento,
                MIN(pr.data_hora_inicio) AS primeira_data_hora_inicio
            FROM procedimento_realizado AS pr
            GROUP BY pr.id_atendimento
        ),
        esperas AS (
            SELECT
                a.id_atendimento,
                a.id_unidade,
                EXTRACT(
                    EPOCH FROM (pp.primeira_data_hora_inicio - a.data_hora)
                ) / 60.0 AS espera_minutos
            FROM atendimento AS a
            INNER JOIN primeiro_procedimento AS pp
                ON pp.id_atendimento = a.id_atendimento
        )
        SELECT
            u.id_unidade,
            u.nome AS nome_unidade,
            COUNT(e.id_atendimento) AS total_atendimentos_considerados,
            ROUND(AVG(e.espera_minutos)::NUMERIC, 2) AS tempo_medio_espera_minutos
        FROM unidade AS u
        LEFT JOIN esperas AS e
            ON e.id_unidade = u.id_unidade
        GROUP BY u.id_unidade, u.nome
        ORDER BY u.id_unidade;
END;
$$;


-- Move todas as escalas do residente na origem para o novo dia e turno. O
-- bloqueio do papel do residente serializa reajustes concorrentes para ele.
CREATE OR REPLACE PROCEDURE sp_reajustar_escala(
    IN p_id_papel_residente INTEGER,
    IN p_dia_origem VARCHAR,
    IN p_turno_origem VARCHAR,
    IN p_dia_destino VARCHAR,
    IN p_turno_destino VARCHAR,
    OUT p_quantidade_atualizadas INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_unidade_conflitante INTEGER;
BEGIN
    p_quantidade_atualizadas := 0;

    IF p_id_papel_residente IS NULL THEN
        RAISE EXCEPTION 'O identificador do papel de residente e obrigatorio';
    END IF;

    IF p_dia_origem IS NULL
       OR p_dia_origem NOT IN (
            'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'
       ) THEN
        RAISE EXCEPTION 'Dia de origem invalido: %', p_dia_origem;
    END IF;

    IF p_dia_destino IS NULL
       OR p_dia_destino NOT IN (
            'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'
       ) THEN
        RAISE EXCEPTION 'Dia de destino invalido: %', p_dia_destino;
    END IF;

    IF p_turno_origem IS NULL
       OR p_turno_origem NOT IN ('manhã', 'tarde', 'noite') THEN
        RAISE EXCEPTION 'Turno de origem invalido: %', p_turno_origem;
    END IF;

    IF p_turno_destino IS NULL
       OR p_turno_destino NOT IN ('manhã', 'tarde', 'noite') THEN
        RAISE EXCEPTION 'Turno de destino invalido: %', p_turno_destino;
    END IF;

    IF p_dia_origem = p_dia_destino
       AND p_turno_origem = p_turno_destino THEN
        RAISE EXCEPTION 'Origem e destino da escala devem ser diferentes';
    END IF;

    -- A linha do residente existe mesmo quando a escala de destino ainda nao
    -- existe, por isso e o ponto estavel de serializacao desta operacao.
    PERFORM 1
    FROM papel_residente
    WHERE id_papel = p_id_papel_residente
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Papel de residente inexistente: %', p_id_papel_residente;
    END IF;

    PERFORM id_escala
    FROM escala_plantao
    WHERE id_papel_residente = p_id_papel_residente
      AND dia_semana = p_dia_origem
      AND turno = p_turno_origem
    ORDER BY id_escala
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Nao ha escalas para o residente % na origem %/%',
            p_id_papel_residente,
            p_dia_origem,
            p_turno_origem;
    END IF;

    -- Rejeita tanto o conflito da UNIQUE atual quanto uma escala do mesmo
    -- residente em outra unidade, em compatibilidade com o futuro trigger.
    SELECT ep.id_unidade
    INTO v_id_unidade_conflitante
    FROM escala_plantao AS ep
    WHERE ep.id_papel_residente = p_id_papel_residente
      AND ep.dia_semana = p_dia_destino
      AND ep.turno = p_turno_destino
    ORDER BY ep.id_unidade
    LIMIT 1;

    IF v_id_unidade_conflitante IS NOT NULL THEN
        RAISE EXCEPTION
            'Conflito no destino %/% para o residente % (unidade %)',
            p_dia_destino,
            p_turno_destino,
            p_id_papel_residente,
            v_id_unidade_conflitante;
    END IF;

    UPDATE escala_plantao
    SET dia_semana = p_dia_destino,
        turno = p_turno_destino
    WHERE id_papel_residente = p_id_papel_residente
      AND dia_semana = p_dia_origem
      AND turno = p_turno_origem;

    GET DIAGNOSTICS p_quantidade_atualizadas = ROW_COUNT;
END;
$$;
