-- ============================================================================
-- ETAPA 2 - PONTO 1: TESTES REPRODUZIVEIS DAS STORED PROCEDURES
-- Executar depois de 01_alteracoes_schema.sql e 02_stored_procedures.sql.
--
-- Todos os dados criados por este arquivo ficam em uma unica transacao e sao
-- descartados pelo ROLLBACK final. Qualquer assercao incorreta interrompe o
-- script quando ele e executado pelo psql.
-- ============================================================================

\set ON_ERROR_STOP on
\echo 'Iniciando testes das stored procedures...'

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.assert_true(
    p_condicao BOOLEAN,
    p_mensagem TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_condicao IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'FALHA: %', p_mensagem;
    END IF;
END;
$$;


-- ============================================================================
-- 1. sp_registrar_atendimento_completo
-- ============================================================================
\echo '1/3 - Testando sp_registrar_atendimento_completo'

DO $$
DECLARE
    v_id_paciente INTEGER;
    v_id_residente INTEGER;
    v_id_preceptor INTEGER;
    v_id_unidade INTEGER;
    v_id_atendimento INTEGER;
    v_total INTEGER;
    v_erro BOOLEAN;
    v_atendimentos_antes BIGINT;
    v_atendimentos_depois BIGINT;
    v_procedimentos_antes BIGINT;
    v_procedimentos_depois BIGINT;
BEGIN
    SELECT pac.id_pessoa
    INTO STRICT v_id_paciente
    FROM paciente AS pac
    INNER JOIN pessoa AS p ON p.id_pessoa = pac.id_pessoa
    WHERE p.cpf = '11111111101';

    SELECT pr.id_papel
    INTO STRICT v_id_residente
    FROM papel_residente AS pr
    INNER JOIN papel_profissional AS pp ON pp.id_papel = pr.id_papel
    INNER JOIN profissional AS prof ON prof.id_pessoa = pp.id_profissional
    WHERE prof.crm = 'CRM006';

    SELECT pp.id_papel
    INTO STRICT v_id_preceptor
    FROM papel_preceptor AS pp
    INNER JOIN papel_profissional AS papel ON papel.id_papel = pp.id_papel
    INNER JOIN profissional AS prof ON prof.id_pessoa = papel.id_profissional
    WHERE prof.crm = 'CRM001';

    SELECT id_unidade
    INTO STRICT v_id_unidade
    FROM unidade
    WHERE nome = 'Enfermaria Geral';

    -- Sucesso com um procedimento e retorno do id.
    CALL sp_registrar_atendimento_completo(
        TIMESTAMP '2030-01-10 09:00:00',
        30,
        v_id_paciente,
        v_id_residente,
        v_id_preceptor,
        v_id_unidade,
        '[{
            "codigo_procedimento": 1002,
            "quantidade": 1,
            "tempo_real_minutos": 10,
            "data_hora_inicio": "2030-01-10 09:10:00"
        }]'::JSONB,
        v_id_atendimento
    );

    PERFORM pg_temp.assert_true(
        v_id_atendimento IS NOT NULL,
        'a procedure deve devolver o id do atendimento criado'
    );

    SELECT COUNT(*)
    INTO v_total
    FROM atendimento
    WHERE id_atendimento = v_id_atendimento
      AND id_unidade = v_id_unidade;

    PERFORM pg_temp.assert_true(
        v_total = 1,
        'o atendimento com um procedimento deveria ter sido inserido'
    );

    SELECT COUNT(*)
    INTO v_total
    FROM procedimento_realizado
    WHERE id_atendimento = v_id_atendimento
      AND flag_faturado = FALSE;

    PERFORM pg_temp.assert_true(
        v_total = 1,
        'o procedimento e o valor padrao de flag_faturado deveriam ser persistidos'
    );

    -- Sucesso com varios procedimentos.
    CALL sp_registrar_atendimento_completo(
        TIMESTAMP '2030-01-10 10:00:00',
        60,
        v_id_paciente,
        v_id_residente,
        v_id_preceptor,
        v_id_unidade,
        '[
            {
                "codigo_procedimento": 1001,
                "quantidade": 1,
                "tempo_real_minutos": 25,
                "data_hora_inicio": "2030-01-10 10:12:00",
                "observacao_intercorrencia": "Teste controlado",
                "flag_faturado": true
            },
            {
                "codigo_procedimento": 1003,
                "quantidade": 2,
                "tempo_real_minutos": 18,
                "data_hora_inicio": "2030-01-10 10:40:00"
            }
        ]'::JSONB,
        v_id_atendimento
    );

    SELECT COUNT(*)
    INTO v_total
    FROM procedimento_realizado
    WHERE id_atendimento = v_id_atendimento;

    PERFORM pg_temp.assert_true(
        v_total = 2,
        'os dois procedimentos validos deveriam ter sido inseridos'
    );

    -- Paciente inexistente.
    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-11 09:00:00', 30, -999999,
            v_id_residente, v_id_preceptor, v_id_unidade,
            '[{"codigo_procedimento":1002,"quantidade":1,"tempo_real_minutos":10,"data_hora_inicio":"2030-01-11 09:05:00"}]'::JSONB,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Paciente inexistente:%';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'paciente inexistente deveria ser rejeitado');

    -- Unidade inexistente.
    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-11 10:00:00', 30, v_id_paciente,
            v_id_residente, v_id_preceptor, -999999,
            '[{"codigo_procedimento":1002,"quantidade":1,"tempo_real_minutos":10,"data_hora_inicio":"2030-01-11 10:05:00"}]'::JSONB,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Unidade inexistente:%';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'unidade inexistente deveria ser rejeitada');

    -- Procedimento inexistente.
    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-11 11:00:00', 30, v_id_paciente,
            v_id_residente, v_id_preceptor, v_id_unidade,
            '[{"codigo_procedimento":999999,"quantidade":1,"tempo_real_minutos":10,"data_hora_inicio":"2030-01-11 11:05:00"}]'::JSONB,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Codigo de procedimento inexistente:%';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'procedimento inexistente deveria ser rejeitado');

    -- Codigo repetido no JSON.
    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-11 12:00:00', 30, v_id_paciente,
            v_id_residente, v_id_preceptor, v_id_unidade,
            '[
                {"codigo_procedimento":1002,"quantidade":1,"tempo_real_minutos":10,"data_hora_inicio":"2030-01-11 12:05:00"},
                {"codigo_procedimento":1002,"quantidade":1,"tempo_real_minutos":10,"data_hora_inicio":"2030-01-11 12:20:00"}
            ]'::JSONB,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Codigo de procedimento repetido na lista:%';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'codigo duplicado deveria ser rejeitado');

    -- Quantidade invalida.
    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-11 13:00:00', 30, v_id_paciente,
            v_id_residente, v_id_preceptor, v_id_unidade,
            '[{"codigo_procedimento":1002,"quantidade":0,"tempo_real_minutos":10,"data_hora_inicio":"2030-01-11 13:05:00"}]'::JSONB,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Item %: quantidade deve ser maior que zero';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'quantidade zero deveria ser rejeitada');

    -- Inicio anterior a chegada.
    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-11 14:00:00', 30, v_id_paciente,
            v_id_residente, v_id_preceptor, v_id_unidade,
            '[{"codigo_procedimento":1002,"quantidade":1,"tempo_real_minutos":10,"data_hora_inicio":"2030-01-11 13:59:00"}]'::JSONB,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Item %: o inicio do procedimento nao pode ser anterior%';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'inicio anterior a chegada deveria ser rejeitado');

    -- Lista nula, valor nao-array, array vazio e campo obrigatorio ausente.
    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-11 15:00:00', 30, v_id_paciente,
            v_id_residente, v_id_preceptor, v_id_unidade, NULL,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM = 'A lista JSONB de procedimentos e obrigatoria';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'JSON nulo deveria ser rejeitado');

    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-11 15:00:00', 30, v_id_paciente,
            v_id_residente, v_id_preceptor, v_id_unidade, '{}'::JSONB,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM = 'A lista de procedimentos deve ser um array JSONB';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'JSON que nao e array deveria ser rejeitado');

    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-11 15:00:00', 30, v_id_paciente,
            v_id_residente, v_id_preceptor, v_id_unidade, '[]'::JSONB,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM = 'A lista de procedimentos nao pode ser vazia';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'array vazio deveria ser rejeitado');

    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-11 15:00:00', 30, v_id_paciente,
            v_id_residente, v_id_preceptor, v_id_unidade,
            '[{"codigo_procedimento":1002,"quantidade":1,"tempo_real_minutos":10}]'::JSONB,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Item %: codigo_procedimento, quantidade, tempo_real_minutos e data_hora_inicio sao obrigatorios';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'campo obrigatorio ausente deveria ser rejeitado');

    -- Atomicidade: o primeiro item e valido e o segundo e invalido. Nenhuma
    -- linha do atendimento ou dos procedimentos pode permanecer.
    SELECT COUNT(*) INTO v_atendimentos_antes FROM atendimento;
    SELECT COUNT(*) INTO v_procedimentos_antes FROM procedimento_realizado;

    v_erro := FALSE;
    BEGIN
        CALL sp_registrar_atendimento_completo(
            TIMESTAMP '2030-01-12 16:23:45', 45, v_id_paciente,
            v_id_residente, v_id_preceptor, v_id_unidade,
            '[
                {"codigo_procedimento":1002,"quantidade":1,"tempo_real_minutos":10,"data_hora_inicio":"2030-01-12 16:30:00"},
                {"codigo_procedimento":999999,"quantidade":1,"tempo_real_minutos":10,"data_hora_inicio":"2030-01-12 16:45:00"}
            ]'::JSONB,
            v_id_atendimento
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Codigo de procedimento inexistente:%';
    END;

    SELECT COUNT(*) INTO v_atendimentos_depois FROM atendimento;
    SELECT COUNT(*) INTO v_procedimentos_depois FROM procedimento_realizado;

    PERFORM pg_temp.assert_true(v_erro, 'o item intermediario invalido deveria gerar excecao');
    PERFORM pg_temp.assert_true(
        v_atendimentos_antes = v_atendimentos_depois,
        'o atendimento da chamada que falhou nao deveria permanecer'
    );
    PERFORM pg_temp.assert_true(
        v_procedimentos_antes = v_procedimentos_depois,
        'nenhum procedimento da chamada que falhou deveria permanecer'
    );
    PERFORM pg_temp.assert_true(
        NOT EXISTS (
            SELECT 1
            FROM atendimento
            WHERE data_hora = TIMESTAMP '2030-01-12 16:23:45'
        ),
        'o marcador do teste de rollback foi encontrado no atendimento'
    );

    RAISE NOTICE 'OK - registro completo, validacoes e atomicidade';
END;
$$;


-- ============================================================================
-- 2. sp_calcular_tempo_medio_espera
-- ============================================================================
\echo '2/3 - Testando sp_calcular_tempo_medio_espera'

DO $$
DECLARE
    v_id_paciente INTEGER;
    v_id_residente INTEGER;
    v_id_preceptor INTEGER;
    v_unidade_a INTEGER;
    v_unidade_b INTEGER;
    v_unidade_sem_dados INTEGER;
    v_atendimento_a1 INTEGER;
    v_atendimento_a2 INTEGER;
    v_atendimento_sem_procedimento INTEGER;
    v_atendimento_b1 INTEGER;
    v_cursor REFCURSOR := 'cur_teste_tempo_espera';
    v_id_unidade INTEGER;
    v_nome_unidade TEXT;
    v_total BIGINT;
    v_media NUMERIC;
    v_encontrou_a BOOLEAN := FALSE;
    v_encontrou_b BOOLEAN := FALSE;
    v_encontrou_sem_dados BOOLEAN := FALSE;
    v_total_linhas INTEGER := 0;
    v_total_unidades INTEGER;
BEGIN
    SELECT pac.id_pessoa
    INTO STRICT v_id_paciente
    FROM paciente AS pac
    INNER JOIN pessoa AS p ON p.id_pessoa = pac.id_pessoa
    WHERE p.cpf = '11111111102';

    SELECT pr.id_papel
    INTO STRICT v_id_residente
    FROM papel_residente AS pr
    INNER JOIN papel_profissional AS pp ON pp.id_papel = pr.id_papel
    INNER JOIN profissional AS prof ON prof.id_pessoa = pp.id_profissional
    WHERE prof.crm = 'CRM007';

    SELECT pp.id_papel
    INTO STRICT v_id_preceptor
    FROM papel_preceptor AS pp
    INNER JOIN papel_profissional AS papel ON papel.id_papel = pp.id_papel
    INNER JOIN profissional AS prof ON prof.id_pessoa = papel.id_profissional
    WHERE prof.crm = 'CRM002';

    INSERT INTO unidade (nome, tipo, capacidade_leitos)
    VALUES ('Teste Espera - Unidade A', 'Ambulatório', 5)
    RETURNING id_unidade INTO v_unidade_a;

    INSERT INTO unidade (nome, tipo, capacidade_leitos)
    VALUES ('Teste Espera - Unidade B', 'Ambulatório', 5)
    RETURNING id_unidade INTO v_unidade_b;

    INSERT INTO unidade (nome, tipo, capacidade_leitos)
    VALUES ('Teste Espera - Sem Dados', 'Ambulatório', 5)
    RETURNING id_unidade INTO v_unidade_sem_dados;

    INSERT INTO atendimento (
        data_hora, duracao_minutos, id_paciente,
        id_papel_residente, id_papel_preceptor, id_unidade
    )
    VALUES (
        TIMESTAMP '2031-02-01 09:00:00', 60, v_id_paciente,
        v_id_residente, v_id_preceptor, v_unidade_a
    )
    RETURNING id_atendimento INTO v_atendimento_a1;

    -- Insercao fora da ordem cronologica: 09:30 entra antes de 09:10.
    INSERT INTO procedimento_realizado (
        id_atendimento, codigo_procedimento, quantidade,
        tempo_real_minutos, data_hora_inicio, flag_faturado
    ) VALUES
        (v_atendimento_a1, 1003, 1, 15, TIMESTAMP '2031-02-01 09:30:00', FALSE),
        (v_atendimento_a1, 1002, 1, 10, TIMESTAMP '2031-02-01 09:10:00', FALSE);

    INSERT INTO atendimento (
        data_hora, duracao_minutos, id_paciente,
        id_papel_residente, id_papel_preceptor, id_unidade
    )
    VALUES (
        TIMESTAMP '2031-02-01 10:00:00', 60, v_id_paciente,
        v_id_residente, v_id_preceptor, v_unidade_a
    )
    RETURNING id_atendimento INTO v_atendimento_a2;

    INSERT INTO procedimento_realizado (
        id_atendimento, codigo_procedimento, quantidade,
        tempo_real_minutos, data_hora_inicio, flag_faturado
    ) VALUES
        (v_atendimento_a2, 1001, 1, 25, TIMESTAMP '2031-02-01 10:20:00', FALSE);

    -- Este atendimento deve ser ignorado por nao possuir procedimento.
    INSERT INTO atendimento (
        data_hora, duracao_minutos, id_paciente,
        id_papel_residente, id_papel_preceptor, id_unidade
    )
    VALUES (
        TIMESTAMP '2031-02-01 11:00:00', 30, v_id_paciente,
        v_id_residente, v_id_preceptor, v_unidade_a
    )
    RETURNING id_atendimento INTO v_atendimento_sem_procedimento;

    INSERT INTO atendimento (
        data_hora, duracao_minutos, id_paciente,
        id_papel_residente, id_papel_preceptor, id_unidade
    )
    VALUES (
        TIMESTAMP '2031-02-01 12:00:00', 30, v_id_paciente,
        v_id_residente, v_id_preceptor, v_unidade_b
    )
    RETURNING id_atendimento INTO v_atendimento_b1;

    -- 10 minutos e 10 segundos = 10,1666..., arredondado para 10,17.
    INSERT INTO procedimento_realizado (
        id_atendimento, codigo_procedimento, quantidade,
        tempo_real_minutos, data_hora_inicio, flag_faturado
    ) VALUES (
        v_atendimento_b1, 1002, 1, 10,
        TIMESTAMP '2031-02-01 12:10:10', FALSE
    );

    CALL sp_calcular_tempo_medio_espera(v_cursor);

    LOOP
        FETCH v_cursor
        INTO v_id_unidade, v_nome_unidade, v_total, v_media;
        EXIT WHEN NOT FOUND;

        v_total_linhas := v_total_linhas + 1;

        IF v_id_unidade = v_unidade_a THEN
            v_encontrou_a := TRUE;
            PERFORM pg_temp.assert_true(
                v_total = 2 AND v_media = 15.00,
                'Unidade A deveria considerar duas esperas e ter media 15,00'
            );
        ELSIF v_id_unidade = v_unidade_b THEN
            v_encontrou_b := TRUE;
            PERFORM pg_temp.assert_true(
                v_total = 1 AND v_media = 10.17,
                'Unidade B deveria demonstrar arredondamento para 10,17 minutos'
            );
        ELSIF v_id_unidade = v_unidade_sem_dados THEN
            v_encontrou_sem_dados := TRUE;
            PERFORM pg_temp.assert_true(
                v_total = 0 AND v_media IS NULL,
                'unidade sem dados deveria retornar total zero e media nula'
            );
        END IF;
    END LOOP;

    SELECT COUNT(*) INTO v_total_unidades FROM unidade;

    PERFORM pg_temp.assert_true(
        v_encontrou_a AND v_encontrou_b AND v_encontrou_sem_dados,
        'as tres unidades controladas deveriam aparecer no cursor'
    );
    PERFORM pg_temp.assert_true(
        v_total_linhas = v_total_unidades,
        'o cursor deveria incluir todas as unidades cadastradas'
    );

    RAISE NOTICE 'OK - media conhecida, primeiro procedimento, unidades sem dados e arredondamento';
END;
$$;


-- ============================================================================
-- 3. sp_reajustar_escala
-- ============================================================================
\echo '3/3 - Testando sp_reajustar_escala'

DO $$
DECLARE
    v_residente_6 INTEGER;
    v_residente_7 INTEGER;
    v_residente_9 INTEGER;
    v_residente_10 INTEGER;
    v_preceptor INTEGER;
    v_unidade_1 INTEGER;
    v_unidade_2 INTEGER;
    v_unidade_3 INTEGER;
    v_id_escala INTEGER;
    v_id_unidade_original INTEGER;
    v_id_preceptor_original INTEGER;
    v_quantidade INTEGER;
    v_total INTEGER;
    v_erro BOOLEAN;
BEGIN
    SELECT pr.id_papel
    INTO STRICT v_residente_6
    FROM papel_residente AS pr
    INNER JOIN papel_profissional AS pp ON pp.id_papel = pr.id_papel
    INNER JOIN profissional AS prof ON prof.id_pessoa = pp.id_profissional
    WHERE prof.crm = 'CRM006';

    SELECT pr.id_papel
    INTO STRICT v_residente_7
    FROM papel_residente AS pr
    INNER JOIN papel_profissional AS pp ON pp.id_papel = pr.id_papel
    INNER JOIN profissional AS prof ON prof.id_pessoa = pp.id_profissional
    WHERE prof.crm = 'CRM007';

    SELECT pr.id_papel
    INTO STRICT v_residente_9
    FROM papel_residente AS pr
    INNER JOIN papel_profissional AS pp ON pp.id_papel = pr.id_papel
    INNER JOIN profissional AS prof ON prof.id_pessoa = pp.id_profissional
    WHERE prof.crm = 'CRM009';

    SELECT pr.id_papel
    INTO STRICT v_residente_10
    FROM papel_residente AS pr
    INNER JOIN papel_profissional AS pp ON pp.id_papel = pr.id_papel
    INNER JOIN profissional AS prof ON prof.id_pessoa = pp.id_profissional
    WHERE prof.crm = 'CRM010';

    SELECT pp.id_papel
    INTO STRICT v_preceptor
    FROM papel_preceptor AS pp
    INNER JOIN papel_profissional AS papel ON papel.id_papel = pp.id_papel
    INNER JOIN profissional AS prof ON prof.id_pessoa = papel.id_profissional
    WHERE prof.crm = 'CRM001';

    SELECT id_unidade INTO STRICT v_unidade_1
    FROM unidade WHERE nome = 'Enfermaria Geral';
    SELECT id_unidade INTO STRICT v_unidade_2
    FROM unidade WHERE nome = 'UTI - Unidade de Terapia Intensiva';
    SELECT id_unidade INTO STRICT v_unidade_3
    FROM unidade WHERE nome = 'Pronto-Socorro 24h';

    -- Sucesso simples usando uma escala da demonstracao da Etapa 1.
    SELECT id_escala, id_unidade, id_papel_preceptor
    INTO STRICT v_id_escala, v_id_unidade_original, v_id_preceptor_original
    FROM escala_plantao
    WHERE id_papel_residente = v_residente_6
      AND dia_semana = 'segunda'
      AND turno = 'manhã';

    CALL sp_reajustar_escala(
        v_residente_6, 'segunda', 'manhã', 'terça', 'tarde', v_quantidade
    );

    PERFORM pg_temp.assert_true(v_quantidade = 1, 'o sucesso simples deveria atualizar uma escala');
    PERFORM pg_temp.assert_true(
        EXISTS (
            SELECT 1
            FROM escala_plantao
            WHERE id_escala = v_id_escala
              AND dia_semana = 'terça'
              AND turno = 'tarde'
              AND id_unidade = v_id_unidade_original
              AND id_papel_residente = v_residente_6
              AND id_papel_preceptor = v_id_preceptor_original
        ),
        'unidade, residente e preceptor deveriam ser preservados'
    );

    -- Sucesso com varias linhas de origem.
    INSERT INTO escala_plantao (
        id_unidade, dia_semana, turno, id_papel_residente, id_papel_preceptor
    ) VALUES
        (v_unidade_1, 'sábado', 'noite', v_residente_9, v_preceptor),
        (v_unidade_2, 'sábado', 'noite', v_residente_9, v_preceptor);

    CALL sp_reajustar_escala(
        v_residente_9, 'sábado', 'noite', 'domingo', 'manhã', v_quantidade
    );

    SELECT COUNT(*)
    INTO v_total
    FROM escala_plantao
    WHERE id_papel_residente = v_residente_9
      AND dia_semana = 'domingo'
      AND turno = 'manhã';

    PERFORM pg_temp.assert_true(
        v_quantidade = 2 AND v_total = 2,
        'todas as escalas da origem deveriam ser atualizadas'
    );

    -- Conflito na mesma unidade: a linha de origem deve permanecer intacta.
    INSERT INTO escala_plantao (
        id_unidade, dia_semana, turno, id_papel_residente, id_papel_preceptor
    ) VALUES
        (v_unidade_2, 'segunda', 'noite', v_residente_10, v_preceptor),
        (v_unidade_2, 'terça', 'noite', v_residente_10, v_preceptor);

    v_erro := FALSE;
    BEGIN
        CALL sp_reajustar_escala(
            v_residente_10, 'segunda', 'noite', 'terça', 'noite', v_quantidade
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Conflito no destino%';
    END;

    PERFORM pg_temp.assert_true(v_erro, 'conflito na mesma unidade deveria ser rejeitado');
    PERFORM pg_temp.assert_true(
        EXISTS (
            SELECT 1 FROM escala_plantao
            WHERE id_unidade = v_unidade_2
              AND dia_semana = 'segunda'
              AND turno = 'noite'
              AND id_papel_residente = v_residente_10
        ),
        'a origem deveria permanecer apos conflito na mesma unidade'
    );

    -- Conflito em outra unidade.
    INSERT INTO escala_plantao (
        id_unidade, dia_semana, turno, id_papel_residente, id_papel_preceptor
    ) VALUES
        (v_unidade_1, 'segunda', 'manhã', v_residente_10, v_preceptor),
        (v_unidade_2, 'quarta', 'noite', v_residente_10, v_preceptor);

    v_erro := FALSE;
    BEGIN
        CALL sp_reajustar_escala(
            v_residente_10, 'segunda', 'manhã', 'quarta', 'noite', v_quantidade
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Conflito no destino%';
    END;

    PERFORM pg_temp.assert_true(v_erro, 'conflito entre unidades deveria ser rejeitado');
    PERFORM pg_temp.assert_true(
        EXISTS (
            SELECT 1 FROM escala_plantao
            WHERE id_unidade = v_unidade_1
              AND dia_semana = 'segunda'
              AND turno = 'manhã'
              AND id_papel_residente = v_residente_10
        ),
        'a origem deveria permanecer apos conflito em outra unidade'
    );

    -- Residente inexistente.
    v_erro := FALSE;
    BEGIN
        CALL sp_reajustar_escala(
            -999999, 'segunda', 'manhã', 'terça', 'manhã', v_quantidade
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Papel de residente inexistente:%';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'residente inexistente deveria ser rejeitado');

    -- Origem sem escalas.
    v_erro := FALSE;
    BEGIN
        CALL sp_reajustar_escala(
            v_residente_10, 'domingo', 'noite', 'sexta', 'manhã', v_quantidade
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Nao ha escalas para o residente%';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'origem sem escala deveria ser rejeitada');

    -- Origem igual ao destino.
    v_erro := FALSE;
    BEGIN
        CALL sp_reajustar_escala(
            v_residente_10, 'segunda', 'noite', 'segunda', 'noite', v_quantidade
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM = 'Origem e destino da escala devem ser diferentes';
    END;
    PERFORM pg_temp.assert_true(v_erro, 'origem igual ao destino deveria ser rejeitada');

    -- Rollback sem atualizacao parcial: duas origens e um conflito no destino.
    INSERT INTO escala_plantao (
        id_unidade, dia_semana, turno, id_papel_residente, id_papel_preceptor
    ) VALUES
        (v_unidade_1, 'terça', 'manhã', v_residente_7, v_preceptor),
        (v_unidade_2, 'terça', 'manhã', v_residente_7, v_preceptor),
        (v_unidade_3, 'quinta', 'noite', v_residente_7, v_preceptor);

    v_erro := FALSE;
    BEGIN
        CALL sp_reajustar_escala(
            v_residente_7, 'terça', 'manhã', 'quinta', 'noite', v_quantidade
        );
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM LIKE 'Conflito no destino%';
    END;

    SELECT COUNT(*)
    INTO v_total
    FROM escala_plantao
    WHERE id_papel_residente = v_residente_7
      AND dia_semana = 'terça'
      AND turno = 'manhã';

    PERFORM pg_temp.assert_true(v_erro, 'o conflito deveria interromper o reajuste multiplo');
    PERFORM pg_temp.assert_true(
        v_total = 2,
        'as duas escalas de origem deveriam permanecer sem atualizacao parcial'
    );

    RAISE NOTICE 'OK - reajustes, conflitos, validacoes e ausencia de atualizacao parcial';
END;
$$;

ROLLBACK;

\echo 'Todos os testes passaram; os dados de teste foram revertidos.'
