-- ============================================================================
-- SQL MODULE 02: INSERÇÃO DE DADOS DE TESTE (SEED DATA)
-- ============================================================================

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

INSERT INTO PESSOA (nome, CPF, data_nascimento, is_flamengo, telefone) VALUES
('Dr. Roberto Lima',      '22222222201', '1975-02-12', true,  '83988888801'),
('Dra. Fernanda Silva',   '22222222202', '1980-09-25', false, '83988888802'),
('Dr. Leonardo Costa',    '22222222203', '1978-04-30', true,  '83988888803'),
('Dra. Paula Rocha',      '22222222204', '1982-12-08', false, '83988888804'),
('Dr. Marcos Duarte',     '22222222205', '1976-06-15', true,  '83988888805'),
('Dra. Juliana Mendes',   '22222222206', '1991-01-20', false, '83988888806'),
('Dr. Felipe Santos',     '22222222207', '1992-07-10', true,  '83988888807'),
('Dra. Beatriz Sousa',    '22222222208', '1993-10-05', false, '83988888808'),
('Dr. Ricardo Alves',     '22222222209', '1990-03-18', true,  '83988888809'),
('Dra. Camila Torres',    '22222222210', '1994-11-22', false, '83988888810');

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

INSERT INTO PAPEL_PROFISSIONAL (id_profissional, tipo_papel, data_inicio, data_fim) VALUES
(6,  'Preceptor', '2020-01-01', NULL),
(7,  'Preceptor', '2019-06-01', NULL),
(8,  'Preceptor', '2018-03-01', NULL),
(9,  'Preceptor', '2021-03-01', NULL),
(10, 'Preceptor', '2020-08-01', NULL),
(11, 'Residente', '2022-01-01', NULL),
(12, 'Residente', '2021-01-01', NULL),
(13, 'Residente', '2023-01-01', NULL),
(14, 'Residente', '2022-06-01', NULL),
(15, 'Residente', '2023-06-01', NULL);

INSERT INTO PAPEL_PRECEPTOR (id_papel, titulacao) VALUES
(1, 'Doutor'),
(2, 'Mestre'),
(3, 'Doutor'),
(4, 'Especialista'),
(5, 'Mestre');

INSERT INTO PAPEL_RESIDENTE (id_papel, ano_residencia) VALUES
(6,  'R2'),
(7,  'R3'),
(8,  'R1'),
(9,  'R2'),
(10, 'R1');

INSERT INTO UNIDADE (nome, tipo, capacidade_leitos) VALUES
('Enfermaria Geral',                 'Enfermaria',    30),
('UTI - Unidade de Terapia Intensiva','UTI',           10),
('Pronto-Socorro 24h',                'Pronto-Socorro', 20);

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
('2024-01-20 09:00:00', 40, 1, 6,  1),
('2024-01-20 11:00:00', 35, 2, 7,  1),
('2024-01-21 08:00:00', 50, 3, 8,  1),
('2024-01-21 14:00:00', 45, 4, 9,  1);

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

INSERT INTO ESCALA_PLANTAO (id_unidade, dia_semana, turno, id_papel_residente, id_papel_preceptor) VALUES
(1, 'segunda',  'manhã', 6,  1),
(1, 'segunda',  'tarde', 7,  2),
(1, 'terça',    'noite', 8,  3),
(2, 'quarta',   'manhã', 9,  4),
(2, 'quinta',   'tarde', 10, 5),
(3, 'sexta',    'noite', 6,  2),
(3, 'sábado',   'manhã', 7,  3),
(1, 'domingo',  'tarde', 8,  4);

INSERT INTO INTERNACAO (id_paciente, id_unidade, data_hora_entrada, data_hora_saida, motivo) VALUES
(1, 1, '2024-01-10 08:00:00', NULL,                   'Acompanhamento pós-cirúrgico'),
(2, 2, '2024-01-12 14:30:00', '2024-01-18 10:00:00',  'Insuficiência respiratória — alta concedida'),
(3, 2, '2024-01-20 19:00:00', NULL,                   'Monitoramento UTI pré-operatório'),
(5, 3, '2024-01-22 07:15:00', NULL,                   'Observação Pronto-Socorro');
