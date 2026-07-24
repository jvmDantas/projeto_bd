-- ============================================================================
-- ETAPA 2 - PONTO 1: EVOLUCAO MINIMA DO ESQUEMA
-- Executar depois de hospital_system_v2.sql.
--
-- Este script parte dos dados de demonstracao da Etapa 1. Os preenchimentos
-- abaixo sao explicitos e deterministas; se houver outros registros ainda sem
-- valor, a migracao e interrompida antes de aplicar NOT NULL.
-- ============================================================================

BEGIN;

-- A unidade e necessaria para agrupar o tempo medio de espera.
ALTER TABLE atendimento
    ADD COLUMN IF NOT EXISTS id_unidade INTEGER;

UPDATE atendimento AS a
SET id_unidade = dados.id_unidade
FROM (
    VALUES
        (1,  1),
        (2,  2),
        (3,  3),
        (4,  3),
        (5,  3),
        (6,  1),
        (7,  2),
        (8,  3),
        (9,  3),
        (10, 3),
        (11, 1),
        (12, 2),
        (13, 3),
        (14, 1),
        -- Criado pela demonstracao CRUD da Parte 3 do script da Etapa 1.
        (15, 1)
) AS dados(id_atendimento, id_unidade)
WHERE a.id_atendimento = dados.id_atendimento
  AND a.id_unidade IS NULL;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM atendimento WHERE id_unidade IS NULL) THEN
        RAISE EXCEPTION
            'Nao foi possivel preencher ATENDIMENTO.id_unidade: existem atendimentos fora do conjunto de demonstracao da Etapa 1';
    END IF;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'atendimento'::regclass
          AND conname = 'fk_atendimento_unidade'
    ) THEN
        ALTER TABLE atendimento
            ADD CONSTRAINT fk_atendimento_unidade
            FOREIGN KEY (id_unidade)
            REFERENCES unidade(id_unidade)
            ON DELETE RESTRICT;
    END IF;
END;
$$;

ALTER TABLE atendimento
    ALTER COLUMN id_unidade SET NOT NULL;

-- O instante de inicio distingue espera de duracao do procedimento.
ALTER TABLE procedimento_realizado
    ADD COLUMN IF NOT EXISTS data_hora_inicio TIMESTAMP;

UPDATE procedimento_realizado AS pr
SET data_hora_inicio = dados.data_hora_inicio
FROM (
    VALUES
        (1,  1002, TIMESTAMP '2024-01-15 09:10:00'),
        (1,  1001, TIMESTAMP '2024-01-15 09:25:00'),
        (2,  1003, TIMESTAMP '2024-01-15 10:50:00'),
        (3,  1002, TIMESTAMP '2024-01-16 08:15:00'),
        (4,  1005, TIMESTAMP '2024-01-16 14:10:00'),
        (5,  1001, TIMESTAMP '2024-01-17 09:30:00'),
        (6,  1003, TIMESTAMP '2024-01-17 11:12:00'),
        (7,  1009, TIMESTAMP '2024-01-18 08:48:00'),
        (8,  1007, TIMESTAMP '2024-01-18 14:05:00'),
        (9,  1004, TIMESTAMP '2024-01-19 09:20:00'),
        (11, 1002, TIMESTAMP '2024-01-20 09:10:00'),
        (12, 1001, TIMESTAMP '2024-01-20 11:20:00'),
        (13, 1009, TIMESTAMP '2024-01-21 08:15:00'),
        (14, 1003, TIMESTAMP '2024-01-21 14:08:00')
) AS dados(id_atendimento, codigo_procedimento, data_hora_inicio)
WHERE pr.id_atendimento = dados.id_atendimento
  AND pr.codigo_procedimento = dados.codigo_procedimento
  AND pr.data_hora_inicio IS NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM procedimento_realizado
        WHERE data_hora_inicio IS NULL
    ) THEN
        RAISE EXCEPTION
            'Nao foi possivel preencher PROCEDIMENTO_REALIZADO.data_hora_inicio: existem registros fora do conjunto de demonstracao da Etapa 1';
    END IF;
END;
$$;

ALTER TABLE procedimento_realizado
    ALTER COLUMN data_hora_inicio SET NOT NULL;

COMMIT;
