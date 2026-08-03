-- ============================================================================
-- SQL MODULE 01: ESTRUTURA DDL (CREATE TABLE + CONSTRAINTS)
-- ============================================================================

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

CREATE TABLE INTERNACAO (
    id_internacao SERIAL PRIMARY KEY,
    id_paciente INT NOT NULL REFERENCES PACIENTE(id_pessoa) ON DELETE CASCADE,
    id_unidade INT NOT NULL REFERENCES UNIDADE(id_unidade) ON DELETE RESTRICT,
    data_hora_entrada TIMESTAMP NOT NULL,
    data_hora_saida TIMESTAMP,
    motivo TEXT,
    CHECK (data_hora_saida IS NULL OR data_hora_entrada <= data_hora_saida)
);

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
