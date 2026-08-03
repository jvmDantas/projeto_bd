-- ============================================================================
-- SQL MODULE 04: TRIGGERS E FUNÇÕES DE GATILHO (PL/pgSQL)
-- ============================================================================

-- TRIGGER 1: trg_check_sobreposicao_escala
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
