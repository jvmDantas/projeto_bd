-- ============================================================================
-- PARTE 1: CREATE TABLE (todas as constraints: PK, FK, CHECK, NOT NULL, UNIQUE)
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
(2,  1003, 1, 18, NULL,                                          false),
(3,  1002, 1, 9,  NULL,                                          false),
(4,  1005, 1, 65, 'Drenagem realizada com sucesso',               true),
(5,  1001, 2, 40, NULL,                                          false),
(6,  1003, 1, 16, 'Reação alérgica menor ao medicamento',         false),
(7,  1009, 1, 22, NULL,                                          false),
(8,  1007, 1, 42, 'Amostra coletada para análise patológica',     true),
(9,  1004, 1, 48, 'Procedimento de risco alto, sem intercorrência', true),
(11, 1002, 1, 11, NULL,                                          false),
(12, 1001, 1, 32, NULL,                                          false),
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
-- FIM DO SCRIPT
-- ============================================================================