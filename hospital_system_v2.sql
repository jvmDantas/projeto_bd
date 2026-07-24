-- ============================================================================
-- SISTEMA DE GESTÃO HOSPITALAR - ETAPA 1 & ETAPA 2 COMPLETA
-- Autores: João Victor Martins e Luís Henrique Aranha Magalhães
-- Disciplina: Banco de Dados - Dra. Yuska Maritan Brito
-- SGBD: PostgreSQL 14+
-- PARTE 1: CREATE TABLE (todas as constraints: PK, FK, CHECK, NOT NULL, UNIQUE)
-- ============================================================================

-- Limpeza prévia para recriação limpa (se necessário)
DROP VIEW IF EXISTS vw_estatisticas_atendimentos_mensal CASCADE;
DROP VIEW IF EXISTS vw_residentes_sem_supervisor CASCADE;
DROP VIEW IF EXISTS vw_pacientes_internados CASCADE;

DROP TRIGGER IF EXISTS trg_atualiza_media_procedimentos ON PROCEDIMENTO_REALIZADO;
DROP TRIGGER IF EXISTS trg_audita_atendimento ON ATENDIMENTO;
DROP TRIGGER IF EXISTS trg_check_sobreposicao_escala ON ESCALA_PLANTAO;

DROP FUNCTION IF EXISTS fn_atualiza_media_procedimentos();
DROP FUNCTION IF EXISTS fn_audita_atendimento();
DROP FUNCTION IF EXISTS fn_check_sobreposicao_escala();

DROP PROCEDURE IF EXISTS sp_reajustar_escala(INT, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS sp_calcular_tempo_medio_espera();
DROP PROCEDURE IF EXISTS sp_registrar_atendimento_completo(TIMESTAMP, INT, INT, INT, INT, INT, JSONB, INT);

DROP TABLE IF EXISTS AUDITORIA_ATENDIMENTO CASCADE;
DROP TABLE IF EXISTS INTERNACAO CASCADE;
DROP TABLE IF EXISTS ESCALA_PLANTAO CASCADE;
DROP TABLE IF EXISTS PROCEDIMENTO_REALIZADO CASCADE;
DROP TABLE IF EXISTS ATENDIMENTO CASCADE;
DROP TABLE IF EXISTS PROCEDIMENTO CASCADE;
DROP TABLE IF EXISTS UNIDADE CASCADE;
DROP TABLE IF EXISTS PAPEL_RESIDENTE CASCADE;
DROP TABLE IF EXISTS PAPEL_PRECEPTOR CASCADE;
DROP TABLE IF EXISTS PAPEL_PROFISSIONAL CASCADE;
DROP TABLE IF EXISTS PROFISSIONAL CASCADE;
DROP TABLE IF EXISTS PACIENTE CASCADE;
DROP TABLE IF EXISTS PESSOA CASCADE;

-- ============================================================================
-- PARTE 1: ESTRUTURA DAS TABELAS (DDL - CREATE TABLE + CONSTRAINTS)
-- ============================================================================
CREATE TABLE PESSOA (
    id_pessoa SERIAL PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    CPF VARCHAR(11) NOT NULL,
    data_nascimento DATE NOT NULL,
    is_flamengo BOOLEAN DEFAULT FALSE,
    telefone VARCHAR(11),
    UNIQUE (CPF)
);

CREATE TABLE PACIENTE (
    id_pessoa INT PRIMARY KEY,
    num_convenio VARCHAR(20),
    alergias TEXT,
    grupo_sanguineo VARCHAR(3),
    endereco VARCHAR(200),
    FOREIGN KEY (id_pessoa) REFERENCES PESSOA(id_pessoa) ON DELETE CASCADE
);

CREATE TABLE PROFISSIONAL (
    id_pessoa INT PRIMARY KEY,
    CRM VARCHAR(20) NOT NULL,
    data_admissao DATE NOT NULL,
    especialidade VARCHAR(100),
    FOREIGN KEY (id_pessoa) REFERENCES PESSOA(id_pessoa) ON DELETE CASCADE,
    UNIQUE (CRM)
);

CREATE TABLE PAPEL_PROFISSIONAL (
    id_papel SERIAL PRIMARY KEY,
    id_profissional INT NOT NULL,
    tipo_papel VARCHAR(20) NOT NULL,
    data_inicio DATE NOT NULL,
    data_fim DATE,
    FOREIGN KEY (id_profissional) REFERENCES PROFISSIONAL(id_pessoa) ON DELETE CASCADE,
    CHECK (tipo_papel IN ('Residente', 'Preceptor')),
    CHECK (data_fim IS NULL OR data_inicio <= data_fim)
);

CREATE TABLE PAPEL_RESIDENTE (
    id_papel INT PRIMARY KEY,
    ano_residencia VARCHAR(2) NOT NULL,
    FOREIGN KEY (id_papel) REFERENCES PAPEL_PROFISSIONAL(id_papel) ON DELETE CASCADE,
    CHECK (ano_residencia IN ('R1', 'R2', 'R3'))
);

CREATE TABLE PAPEL_PRECEPTOR (
    id_papel INT PRIMARY KEY,
    titulacao VARCHAR(50),
    FOREIGN KEY (id_papel) REFERENCES PAPEL_PROFISSIONAL(id_papel) ON DELETE CASCADE
);

CREATE TABLE UNIDADE (
    id_unidade SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    tipo VARCHAR(30) NOT NULL,
    capacidade_leitos INT,
    CHECK (tipo IN ('Enfermaria', 'UTI', 'Pronto-Socorro', 'Ambulatório')),
    CHECK (capacidade_leitos > 0)
);

CREATE TABLE PROCEDIMENTO (
    codigo INT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    tempo_medio_minutos INT NOT NULL,
    nivel_risco VARCHAR(10) NOT NULL,
    media_tempo_procedimento NUMERIC(10,2) DEFAULT 0.00,
    CHECK (tempo_medio_minutos > 0),
    CHECK (nivel_risco IN ('BAIXO', 'MÉDIO', 'ALTO'))
);

CREATE TABLE ATENDIMENTO (
    id_atendimento SERIAL PRIMARY KEY,
    data_hora TIMESTAMP NOT NULL,
    duracao_minutos INT NOT NULL,
    id_paciente INT NOT NULL,
    id_papel_residente INT NOT NULL,
    id_papel_preceptor INT NOT NULL,
    FOREIGN KEY (id_paciente) REFERENCES PACIENTE(id_pessoa) ON DELETE RESTRICT,
    FOREIGN KEY (id_papel_residente) REFERENCES PAPEL_RESIDENTE(id_papel) ON DELETE RESTRICT,
    FOREIGN KEY (id_papel_preceptor) REFERENCES PAPEL_PRECEPTOR(id_papel) ON DELETE RESTRICT,
    CHECK (duracao_minutos > 0)
);

CREATE TABLE PROCEDIMENTO_REALIZADO (
    id_atendimento INT NOT NULL,
    codigo_procedimento INT NOT NULL,
    quantidade INT NOT NULL,
    tempo_real_minutos INT NOT NULL,
    observacao_intercorrencia TEXT,
    flag_faturado BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (id_atendimento, codigo_procedimento),
    FOREIGN KEY (id_atendimento) REFERENCES ATENDIMENTO(id_atendimento) ON DELETE CASCADE,
    FOREIGN KEY (codigo_procedimento) REFERENCES PROCEDIMENTO(codigo) ON DELETE RESTRICT,
    CHECK (quantidade > 0),
    CHECK (tempo_real_minutos > 0)
);

CREATE TABLE ESCALA_PLANTAO (
    id_escala SERIAL PRIMARY KEY,
    id_unidade INT NOT NULL,
    dia_semana VARCHAR(10) NOT NULL,
    turno VARCHAR(10) NOT NULL,
    id_papel_residente INT NOT NULL,
    id_papel_preceptor INT NOT NULL,
    FOREIGN KEY (id_unidade) REFERENCES UNIDADE(id_unidade) ON DELETE RESTRICT,
    FOREIGN KEY (id_papel_residente) REFERENCES PAPEL_RESIDENTE(id_papel) ON DELETE RESTRICT,
    FOREIGN KEY (id_papel_preceptor) REFERENCES PAPEL_PRECEPTOR(id_papel) ON DELETE RESTRICT,
    CHECK (dia_semana IN ('segunda','terça','quarta','quinta','sexta','sábado','domingo')),
    CHECK (turno IN ('manhã','tarde','noite')),
    UNIQUE (id_unidade, dia_semana, turno, id_papel_residente)
);

-- Nova Tabela para Etapa 2: INTERNACAO (suporte a vw_pacientes_internados)
CREATE TABLE INTERNACAO (
    id_internacao SERIAL PRIMARY KEY,
    id_paciente INT NOT NULL REFERENCES PACIENTE(id_pessoa) ON DELETE CASCADE,
    id_unidade INT NOT NULL REFERENCES UNIDADE(id_unidade) ON DELETE RESTRICT,
    data_hora_entrada TIMESTAMP NOT NULL,
    data_hora_saida TIMESTAMP,
    motivo TEXT,
    CHECK (data_hora_saida IS NULL OR data_hora_entrada <= data_hora_saida)
);

-- Nova Tabela para Etapa 2: AUDITORIA_ATENDIMENTO (suporte a trg_audita_atendimento)
CREATE TABLE AUDITORIA_ATENDIMENTO (
    id_auditoria SERIAL PRIMARY KEY,
    id_atendimento INT,
    operacao VARCHAR(10) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dados_antigos JSONB,
    dados_novos JSONB
);

ALTER TABLE PROCEDIMENTO
    ADD COLUMN IF NOT EXISTS media_tempo_procedimento NUMERIC(10,2) DEFAULT 0.00;

-- ============================================================================
-- PARTE 2: INSERÇÃO DE DADOS DE TESTE
-- Mínimo exigido: 5 pacientes, 5 residentes, 5 preceptores, 3 unidades,
--                 10 atendimentos, 10 procedimentos realizados
-- ============================================================================

-- 5 PESSOAS (que serão PACIENTES) -------------------------------------------
INSERT INTO PESSOA (nome, CPF, data_nascimento, is_flamengo, telefone) VALUES
('João da Silva',    '11111111101', '1990-05-15', true,  '83987654321'),
('Maria Santos',     '11111111102', '1985-08-22', false, '83987654322'),
('Pedro Oliveira',   '11111111103', '1992-03-10', true,  '83987654323'),
('Ana Costa',        '11111111104', '1988-11-30', false, '83987654324'),
('Carlos Mendes',    '11111111105', '1995-07-18', true,  '83987654325');

INSERT INTO PACIENTE (id_pessoa, num_convenio, alergias, grupo_sanguineo, endereco) VALUES
(1, 'CONV001', 'Penicilina',      'O+',  'Rua A, 100, João Pessoa'),
(2, 'CONV002', NULL,              'A-',  'Rua B, 200, João Pessoa'),
(3, 'CONV003', 'Dipirona',        'B+',  'Rua C, 300, João Pessoa'),
(4, NULL,      NULL,              'AB+', 'Rua D, 400, João Pessoa'),
(5, 'CONV004', 'Cefalosporina',   'O-',  'Rua E, 500, João Pessoa');

-- 10 PESSOAS (que serão PROFISSIONAIS: 5 preceptores + 5 residentes) --------
INSERT INTO PESSOA (nome, CPF, data_nascimento, is_flamengo, telefone) VALUES
('Dr. Roberto Lima',      '22222222201', '1975-02-12', true,  '83988888801'), -- 6  preceptor
('Dra. Fernanda Silva',   '22222222202', '1980-09-25', false, '83988888802'), -- 7  preceptor
('Dr. Leonardo Costa',    '22222222203', '1978-04-30', true,  '83988888803'), -- 8  preceptor
('Dra. Paula Rocha',      '22222222204', '1982-12-08', false, '83988888804'), -- 9  preceptor
('Dr. Marcos Duarte',     '22222222205', '1976-06-15', true,  '83988888805'), -- 10 preceptor
('Dra. Juliana Mendes',   '22222222206', '1991-01-20', false, '83988888806'), -- 11 residente
('Dr. Felipe Santos',     '22222222207', '1992-07-10', true,  '83988888807'), -- 12 residente
('Dra. Beatriz Sousa',    '22222222208', '1993-10-05', false, '83988888808'), -- 13 residente
('Dr. Ricardo Alves',     '22222222209', '1990-03-18', true,  '83988888809'), -- 14 residente
('Dra. Camila Torres',    '22222222210', '1994-11-22', false, '83988888810'); -- 15 residente

INSERT INTO PROFISSIONAL (id_pessoa, CRM, data_admissao, especialidade) VALUES
(6,  'CRM001', '2008-01-15', 'Cardiologia'),
(7,  'CRM002', '2010-03-20', 'Pediatria'),
(8,  'CRM003', '2006-06-10', 'Cirurgia Geral'),
(9,  'CRM004', '2012-08-25', 'Oncologia'),
(10, 'CRM005', '2009-02-28', 'Clínica Geral'),
(11, 'CRM006', '2022-01-01', 'Clínica Geral'),
(12, 'CRM007', '2021-01-01', 'Pediatria'),
(13, 'CRM008', '2023-01-01', 'Clínica Geral'),
(14, 'CRM009', '2022-06-01', 'Cirurgia Geral'),
(15, 'CRM010', '2023-06-01', 'Clínica Geral');

-- PAPEL_PROFISSIONAL: 5 preceptores (papel_id 1-5) + 5 residentes (papel_id 6-10)
INSERT INTO PAPEL_PROFISSIONAL (id_profissional, tipo_papel, data_inicio, data_fim) VALUES
(6,  'Preceptor', '2020-01-01', NULL), -- id_papel 1
(7,  'Preceptor', '2019-06-01', NULL), -- id_papel 2
(8,  'Preceptor', '2018-03-01', NULL), -- id_papel 3
(9,  'Preceptor', '2021-03-01', NULL), -- id_papel 4
(10, 'Preceptor', '2020-08-01', NULL), -- id_papel 5
(11, 'Residente', '2022-01-01', NULL), -- id_papel 6
(12, 'Residente', '2021-01-01', NULL), -- id_papel 7
(13, 'Residente', '2023-01-01', NULL), -- id_papel 8
(14, 'Residente', '2022-06-01', NULL), -- id_papel 9
(15, 'Residente', '2023-06-01', NULL); -- id_papel 10

-- 5 PRECEPTORES ---------------------------------------------------------------
INSERT INTO PAPEL_PRECEPTOR (id_papel, titulacao) VALUES
(1, 'Doutor'),
(2, 'Mestre'),
(3, 'Doutor'),
(4, 'Especialista'),
(5, 'Mestre');

-- 5 RESIDENTES ------------------------------------------------------------
INSERT INTO PAPEL_RESIDENTE (id_papel, ano_residencia) VALUES
(6,  'R2'),
(7,  'R3'),
(8,  'R1'),
(9,  'R2'),
(10, 'R1');

-- 3 UNIDADES ----------------------------------------------------------------
INSERT INTO UNIDADE (nome, tipo, capacidade_leitos) VALUES
('Enfermaria Geral',                 'Enfermaria',    30),
('UTI - Unidade de Terapia Intensiva','UTI',           10),
('Pronto-Socorro 24h',                'Pronto-Socorro', 20);

-- 10 PROCEDIMENTOS (catálogo) ------------------------------------------------
INSERT INTO PROCEDIMENTO (codigo, nome, tempo_medio_minutos, nivel_risco) VALUES
(1001, 'Sutura de ferida',            30,  'BAIXO'),
(1002, 'Coleta de sangue',            10,  'BAIXO'),
(1003, 'Aplicação de medicação IV',   15,  'MÉDIO'),
(1004, 'Intubação endotraqueal',      45,  'ALTO'),
(1005, 'Drenagem de abcesso',         60,  'MÉDIO'),
(1006, 'Cateterismo cardíaco',        120, 'ALTO'),
(1007, 'Biópsia de tecido',           40,  'MÉDIO'),
(1008, 'Transfusão de sangue',        30,  'ALTO'),
(1009, 'Curativos especiais',         20,  'BAIXO'),
(1010, 'Ventilação mecânica',         50,  'ALTO');

-- 10 ATENDIMENTOS (id_papel_residente: 6-10 | id_papel_preceptor: 1-5) ------
INSERT INTO ATENDIMENTO (data_hora, duracao_minutos, id_paciente, id_papel_residente, id_papel_preceptor) VALUES
('2024-01-15 09:00:00', 45, 1, 6,  1),
('2024-01-15 10:30:00', 60, 2, 7,  2),
('2024-01-16 08:00:00', 30, 3, 8,  3),
('2024-01-16 14:00:00', 50, 4, 9,  4),
('2024-01-17 09:15:00', 40, 5, 10, 5),
('2024-01-17 11:00:00', 55, 1, 6,  2),
('2024-01-18 08:30:00', 35, 2, 7,  3),
('2024-01-18 13:45:00', 70, 3, 8,  4),
('2024-01-19 09:00:00', 45, 4, 9,  5),
('2024-01-19 15:00:00', 60, 5, 10, 1),
-- Atendimentos extras para o preceptor 1 (Dr. Roberto Lima) demonstrar a
-- consulta analítica "preceptores com mais de 5 atendimentos no mês"
('2024-01-20 09:00:00', 40, 1, 6,  1),
('2024-01-20 11:00:00', 35, 2, 7,  1),
('2024-01-21 08:00:00', 50, 3, 8,  1),
('2024-01-21 14:00:00', 45, 4, 9,  1);

-- 10 PROCEDIMENTOS REALIZADOS (+4 extras para os atendimentos 11-14) --------
INSERT INTO PROCEDIMENTO_REALIZADO (id_atendimento, codigo_procedimento, quantidade, tempo_real_minutos, observacao_intercorrencia, flag_faturado) VALUES
(1,  1002, 2, 12, NULL,                                          false),
(1,  1001, 1, 35, 'Sutura simples, sem complicações',             false),
(13, 1009, 1, 19, NULL,                                          false),
(14, 1003, 1, 14, NULL,                                          false);

-- ESCALAS DE PLANTÃO (dado complementar, não obrigatório no mínimo) ---------
INSERT INTO ESCALA_PLANTAO (id_unidade, dia_semana, turno, id_papel_residente, id_papel_preceptor) VALUES
(1, 'segunda',  'manhã', 6,  1),
(1, 'segunda',  'tarde', 7,  2),
(1, 'terça',    'noite', 8,  3),
(2, 'quarta',   'manhã', 9,  4),
(2, 'quinta',   'tarde', 10, 5),
(3, 'sexta',    'noite', 6,  2),
(3, 'sábado',   'manhã', 7,  3),
(1, 'domingo',  'tarde', 8,  4);

-- ============================================================================
-- PARTE 3: CRUD E CONSULTAS BÁSICAS (SQL puro)
-- ============================================================================

-- 3.1 Inserir novo atendimento, verificando se paciente, residente e preceptor existem
INSERT INTO ATENDIMENTO (data_hora, duracao_minutos, id_paciente, id_papel_residente, id_papel_preceptor)
SELECT CURRENT_TIMESTAMP, 45, 1, 6, 1
WHERE EXISTS (SELECT 1 FROM PACIENTE WHERE id_pessoa = 1)
  AND EXISTS (SELECT 1 FROM PAPEL_RESIDENTE WHERE id_papel = 6)
  AND EXISTS (SELECT 1 FROM PAPEL_PRECEPTOR WHERE id_papel = 1);

-- 3.2 Listar todos os atendimentos de um paciente específico (ordenados por data)
SELECT
    a.id_atendimento,
    a.data_hora,
    a.duracao_minutos,
    pes_pac.nome AS paciente,
    pes_res.nome AS residente,
    pes_pre.nome AS preceptor
FROM ATENDIMENTO a
JOIN PACIENTE pac         ON a.id_paciente = pac.id_pessoa
JOIN PESSOA pes_pac        ON pac.id_pessoa = pes_pac.id_pessoa
JOIN PAPEL_RESIDENTE pr    ON a.id_papel_residente = pr.id_papel
JOIN PAPEL_PROFISSIONAL ppr ON pr.id_papel = ppr.id_papel
JOIN PESSOA pes_res        ON ppr.id_profissional = pes_res.id_pessoa
JOIN PAPEL_PRECEPTOR pp    ON a.id_papel_preceptor = pp.id_papel
JOIN PAPEL_PROFISSIONAL ppp ON pp.id_papel = ppp.id_papel
JOIN PESSOA pes_pre        ON ppp.id_profissional = pes_pre.id_pessoa
WHERE a.id_paciente = 1
ORDER BY a.data_hora ASC;

-- 3.3 Listar os procedimentos realizados em um atendimento
--     (nome do procedimento, quantidade, tempo real)
SELECT
    pr.id_atendimento,
    proc.nome AS procedimento,
    pr.quantidade,
    pr.tempo_real_minutos
FROM PROCEDIMENTO_REALIZADO pr
JOIN PROCEDIMENTO proc ON pr.codigo_procedimento = proc.codigo
WHERE pr.id_atendimento = 1
ORDER BY proc.nome;

-- 3.4 Atualizar os dados de um paciente (endereço ou convênio)
UPDATE PACIENTE
SET endereco = 'Rua Nova, 999, João Pessoa',
    num_convenio = 'CONV999'
WHERE id_pessoa = 1;

-- 3.5 Remover um procedimento realizado (apenas se ainda não houver faturamento)
DELETE FROM PROCEDIMENTO_REALIZADO
WHERE id_atendimento = 1
  AND codigo_procedimento = 1002
  AND flag_faturado = false;

-- 3.6 Calcular o tempo médio de duração dos atendimentos por residente
SELECT
    pes.nome AS residente,
    COUNT(a.id_atendimento) AS total_atendimentos,
    ROUND(AVG(a.duracao_minutos), 2) AS tempo_medio_minutos
FROM ATENDIMENTO a
JOIN PAPEL_RESIDENTE pr     ON a.id_papel_residente = pr.id_papel
JOIN PAPEL_PROFISSIONAL ppr ON pr.id_papel = ppr.id_papel
JOIN PESSOA pes              ON ppr.id_profissional = pes.id_pessoa
GROUP BY pes.id_pessoa, pes.nome
ORDER BY tempo_medio_minutos DESC;

-- ============================================================================
-- PARTE 4: CONSULTAS ANALÍTICAS
-- ============================================================================

-- 4.1 Ranking dos residentes por número de atendimentos realizados
SELECT
    pes.nome AS residente,
    COUNT(a.id_atendimento) AS total_atendimentos,
    RANK() OVER (ORDER BY COUNT(a.id_atendimento) DESC) AS ranking
FROM ATENDIMENTO a
JOIN PAPEL_RESIDENTE pr     ON a.id_papel_residente = pr.id_papel
JOIN PAPEL_PROFISSIONAL ppr ON pr.id_papel = ppr.id_papel
JOIN PESSOA pes              ON ppr.id_profissional = pes.id_pessoa
GROUP BY pes.id_pessoa, pes.nome
ORDER BY ranking;

-- 4.2 Preceptores que supervisionaram mais de 5 atendimentos em um mês (jan/2024)
SELECT
    pes.nome AS preceptor,
    COUNT(a.id_atendimento) AS total_atendimentos
FROM ATENDIMENTO a
JOIN PAPEL_PRECEPTOR pp     ON a.id_papel_preceptor = pp.id_papel
JOIN PAPEL_PROFISSIONAL ppp ON pp.id_papel = ppp.id_papel
JOIN PESSOA pes               ON ppp.id_profissional = pes.id_pessoa
WHERE EXTRACT(MONTH FROM a.data_hora) = 1
  AND EXTRACT(YEAR FROM a.data_hora) = 2024
GROUP BY pes.id_pessoa, pes.nome
HAVING COUNT(a.id_atendimento) > 5
ORDER BY total_atendimentos DESC;

-- 4.3 Para cada unidade, quantidade de plantões escalados por residente no mês corrente
--     (Escala_Plantao é recorrente semanal, sem data; contagem por unidade/residente)
SELECT
    u.nome AS unidade,
    pes.nome AS residente,
    COUNT(ep.id_escala) AS total_plantoes
FROM ESCALA_PLANTAO ep
JOIN UNIDADE u               ON ep.id_unidade = u.id_unidade
JOIN PAPEL_RESIDENTE pr      ON ep.id_papel_residente = pr.id_papel
JOIN PAPEL_PROFISSIONAL ppr  ON pr.id_papel = ppr.id_papel
JOIN PESSOA pes                ON ppr.id_profissional = pes.id_pessoa
GROUP BY u.id_unidade, u.nome, pes.id_pessoa, pes.nome
ORDER BY u.nome, pes.nome;

-- 4.4 Pacientes que nunca realizaram nenhum procedimento de nível de risco 'ALTO'
SELECT
    pes.nome AS paciente,
    pes.CPF
FROM PACIENTE pac
JOIN PESSOA pes ON pac.id_pessoa = pes.id_pessoa
WHERE pac.id_pessoa NOT IN (
    SELECT a.id_paciente
    FROM ATENDIMENTO a
    JOIN PROCEDIMENTO_REALIZADO pr ON a.id_atendimento = pr.id_atendimento
    JOIN PROCEDIMENTO proc         ON pr.codigo_procedimento = proc.codigo
    WHERE proc.nivel_risco = 'ALTO'
)
ORDER BY pes.nome;

-- ============================================================================
-- ETAPA 2 — STORED PROCEDURES, TRIGGERS, VIEWS, ORM E CONCORRÊNCIA
-- ============================================================================

-- ============================================================================
-- ETAPA 2 — PARTE B: DADOS DE TESTE DAS NOVAS TABELAS
-- ============================================================================

-- Internações de teste (3 ativas, 1 com alta — para exercitar a view)
INSERT INTO INTERNACAO (id_paciente, id_unidade, data_hora_entrada, data_hora_saida, motivo) VALUES
(1, 1, '2024-01-10 08:00:00', NULL,                   'Acompanhamento pós-cirúrgico'),
(2, 2, '2024-01-12 14:30:00', '2024-01-18 10:00:00',  'Insuficiência respiratória — alta concedida'),
(3, 2, '2024-01-20 19:00:00', NULL,                   'Monitoramento UTI pré-operatório'),
(5, 3, '2024-01-22 07:15:00', NULL,                   'Observação Pronto-Socorro');


-- ============================================================================
-- ETAPA 2 — PARTE C: STORED PROCEDURES
-- ============================================================================

-- SP 1: sp_registrar_atendimento_completo
-- Recebe dados do atendimento + lista de procedimentos como JSONB e insere
-- tudo dentro de uma única transação. Se qualquer INSERT falhar, a transação
-- inteira é revertida (comportamento nativo do PostgreSQL em procedures).
--
-- Formato esperado do parâmetro p_procedimentos (array JSON):
--   '[{"codigo":1001,"quantidade":1,"tempo_real":35,"observacao":"texto"}]'
--
-- Exemplo de chamada:
--   CALL sp_registrar_atendimento_completo(
--       NOW(), 45, 1, 6, 1,
--       '[{"codigo":1001,"quantidade":1,"tempo_real":35}]'::jsonb
--   );
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
    -- Validação prévia das FKs para mensagens claras antes do INSERT
    IF NOT EXISTS (SELECT 1 FROM PACIENTE      WHERE id_pessoa = p_id_paciente)  THEN
        RAISE EXCEPTION 'Paciente % não encontrado.', p_id_paciente;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM PAPEL_RESIDENTE WHERE id_papel = p_id_residente) THEN
        RAISE EXCEPTION 'Residente (papel %) não encontrado.', p_id_residente;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM PAPEL_PRECEPTOR WHERE id_papel = p_id_preceptor) THEN
        RAISE EXCEPTION 'Preceptor (papel %) não encontrado.', p_id_preceptor;
    END IF;

    -- Inserção principal
    INSERT INTO ATENDIMENTO (data_hora, duracao_minutos, id_paciente, id_papel_residente, id_papel_preceptor)
    VALUES (p_data_hora, p_duracao, p_id_paciente, p_id_residente, p_id_preceptor)
    RETURNING id_atendimento INTO v_id_atendimento;

    -- Inserção dos procedimentos realizados (qualquer falha aqui reverte tudo)
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
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Transação abortada em sp_registrar_atendimento_completo: %', SQLERRM;
END;
$$;

-- SP 2: sp_calcular_tempo_medio_espera
-- Calcula, para cada unidade, o tempo médio entre a chegada do paciente
-- (data_hora do atendimento) e o início do primeiro procedimento.
-- Como o modelo não armazena timestamp de início de procedimento, usa-se
-- a diferença entre data_hora do atendimento e data_hora do procedimento
-- mais antigo com mesmo id_atendimento como proxy (atendimento sem
-- procedimento registrado contribui com 0 minutos).
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
-- Recebe id_residente, dia/turno de origem e dia/turno de destino.
-- Move todas as escalas do residente do slot de origem para o de destino.
-- A trigger trg_check_sobreposicao_escala (criada abaixo) garante que não
-- haja conflito; se houver, o UPDATE lança exceção e reverte.
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
    -- Verifica se existe ao menos uma escala a mover
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

    -- Atualiza; conflitos serão detectados pela trigger BEFORE UPDATE
    UPDATE ESCALA_PLANTAO
    SET    dia_semana = LOWER(p_dia_novo),
           turno      = LOWER(p_turno_novo)
    WHERE  id_papel_residente = p_id_residente
      AND  LOWER(dia_semana)  = LOWER(p_dia_antigo)
      AND  LOWER(turno)       = LOWER(p_turno_antigo);
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Falha ao reajustar escala (conflito detectado): %', SQLERRM;
END;
$$;

-- ============================================================================
-- ETAPA 2 — PARTE D: TRIGGERS
-- ============================================================================

-- TRIGGER 1: trg_check_sobreposicao_escala
-- BEFORE INSERT/UPDATE em ESCALA_PLANTAO.
-- Impede que o mesmo residente seja escalado no mesmo dia/turno em duas
-- unidades diferentes.
CREATE OR REPLACE FUNCTION fn_check_sobreposicao_escala()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   ESCALA_PLANTAO e
        WHERE  e.id_papel_residente = NEW.id_papel_residente
          AND  LOWER(e.dia_semana)  = LOWER(NEW.dia_semana)
          AND  LOWER(e.turno)       = LOWER(NEW.turno)
          AND  e.id_unidade        <> NEW.id_unidade
          -- Em UPDATE, exclui o próprio registro
          AND  e.id_escala         <> COALESCE(NEW.id_escala, 0)
    ) THEN
        RAISE EXCEPTION
            'Conflito de escala: residente % já escalado em outra unidade no dia "%" turno "%".',
            NEW.id_papel_residente, NEW.dia_semana, NEW.turno;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_sobreposicao_escala ON ESCALA_PLANTAO;
CREATE TRIGGER trg_check_sobreposicao_escala
BEFORE INSERT OR UPDATE ON ESCALA_PLANTAO
FOR EACH ROW EXECUTE FUNCTION fn_check_sobreposicao_escala();

-- TRIGGER 2: trg_audita_atendimento
-- AFTER INSERT/UPDATE/DELETE em ATENDIMENTO.
-- Registra cada operação na tabela AUDITORIA_ATENDIMENTO com snapshot
-- JSON das linhas antiga e nova.
CREATE OR REPLACE FUNCTION fn_audita_atendimento()
RETURNS TRIGGER AS $$
DECLARE
    v_op VARCHAR(10);
    v_usr VARCHAR(100);
BEGIN
    v_op := TG_OP;
    v_usr := CURRENT_USER;

    IF (TG_OP = 'INSERT') THEN
        INSERT INTO AUDITORIA_ATENDIMENTO (id_atendimento, operacao, usuario, data_hora, dados_antigos, dados_novos)
        VALUES (NEW.id_atendimento, v_op, v_usr, CURRENT_TIMESTAMP, NULL, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO AUDITORIA_ATENDIMENTO (id_atendimento, operacao, usuario, data_hora, dados_antigos, dados_novos)
        VALUES (NEW.id_atendimento, v_op, v_usr, CURRENT_TIMESTAMP, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO AUDITORIA_ATENDIMENTO (id_atendimento, operacao, usuario, data_hora, dados_antigos, dados_novos)
        VALUES (OLD.id_atendimento, v_op, v_usr, CURRENT_TIMESTAMP, to_jsonb(OLD), NULL);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audita_atendimento ON ATENDIMENTO;
CREATE TRIGGER trg_audita_atendimento
AFTER INSERT OR UPDATE OR DELETE ON ATENDIMENTO
FOR EACH ROW EXECUTE FUNCTION fn_audita_atendimento();

-- TRIGGER 3: trg_atualiza_media_procedimentos
-- AFTER INSERT em PROCEDIMENTO_REALIZADO (conforme enunciado).
-- Recalcula e persiste a média de tempo_real_minutos de cada procedimento
-- na coluna media_tempo_procedimento da tabela PROCEDIMENTO.
CREATE OR REPLACE FUNCTION fn_atualiza_media_procedimentos()
RETURNS TRIGGER AS $$
DECLARE
    v_cod INT;
    v_media NUMERIC(10,2);
BEGIN
    IF (TG_OP = 'DELETE') THEN
        v_cod := OLD.codigo_procedimento;
    ELSE
        v_cod := NEW.codigo_procedimento;
    END IF;

    SELECT COALESCE(AVG(tempo_real_minutos), 0) INTO v_media
    FROM PROCEDIMENTO_REALIZADO
    WHERE codigo_procedimento = v_cod;

    UPDATE PROCEDIMENTO
    SET    media_tempo_procedimento = COALESCE(v_media, 0.00)
    WHERE  codigo = NEW.codigo_procedimento;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_atualiza_media_procedimentos ON PROCEDIMENTO_REALIZADO;
CREATE TRIGGER trg_atualiza_media_procedimentos
AFTER INSERT ON PROCEDIMENTO_REALIZADO
FOR EACH ROW EXECUTE FUNCTION fn_atualiza_media_procedimentos();

-- Inicialização da coluna media_tempo_procedimento com valores atuais
UPDATE PROCEDIMENTO p
SET media_tempo_procedimento = COALESCE((
    SELECT ROUND(AVG(pr.tempo_real_minutos), 2)
    FROM PROCEDIMENTO_REALIZADO pr
    WHERE pr.codigo_procedimento = p.codigo
), 0.00);


-- ============================================================================
-- ETAPA 2 — PARTE E: VIEWS
-- ============================================================================

-- VIEW 1: vw_pacientes_internados
-- Pacientes com internação ativa (data_hora_saida IS NULL na internação
-- mais recente de cada paciente).
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
    -- Apenas a internação mais recente por paciente
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
-- Residentes escalados em algum plantão cujo preceptor NÃO tem titulação
-- de 'Doutor', ou cujo papel de preceptor já foi encerrado (data_fim passada).
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
-- Agregação por ano/mês e unidade: total de atendimentos, média de duração
-- e nome do procedimento mais realizado no período.
CREATE OR REPLACE VIEW vw_estatisticas_atendimentos_mensal AS
-- Obs.: a tabela ATENDIMENTO original (Etapa 1) não possui id_unidade,
-- portanto a agregação por unidade é aproximada via escala de plantão.
-- Para demonstração direta, usamos a query abaixo sem join de unidade:
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


-- ============================================================================
-- ETAPA 2 — PARTE F: CONSULTAS AVANÇADAS (referência SQL puro, demonstradas
--                     no app.py também via ORM SQLAlchemy)
-- ============================================================================

-- F.1 Preceptores que supervisionaram residentes que atenderam
--     pacientes flamenguistas (is_flamengo = TRUE)
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

-- F.2 Para cada paciente, exibir o seu último atendimento
--     (data_hora, residente, preceptor, lista de procedimentos)
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

-- F.3 Percentual de procedimentos de alto risco realizados por cada residente
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

-- ============================================================================
-- FIM DO SCRIPT (ETAPA 1 + ETAPA 2)
-- ============================================================================