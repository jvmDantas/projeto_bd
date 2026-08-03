"""
services/analytics_service.py — Serviços para consultas analíticas em SQL puro (Etapa 1)
"""

from database.connection import run_query


def get_overview_counts():
    """Retorna contagem de registros por tabela para a Visão Geral."""
    sql = """
        SELECT 'Pessoa' AS tabela, COUNT(*) AS registros FROM pessoa
        UNION ALL SELECT 'Paciente', COUNT(*) FROM paciente
        UNION ALL SELECT 'Profissional', COUNT(*) FROM profissional
        UNION ALL SELECT 'Papel_Residente', COUNT(*) FROM papel_residente
        UNION ALL SELECT 'Papel_Preceptor', COUNT(*) FROM papel_preceptor
        UNION ALL SELECT 'Unidade', COUNT(*) FROM unidade
        UNION ALL SELECT 'Procedimento', COUNT(*) FROM procedimento
        UNION ALL SELECT 'Atendimento', COUNT(*) FROM atendimento
        UNION ALL SELECT 'Procedimento_Realizado', COUNT(*) FROM procedimento_realizado
        UNION ALL SELECT 'Escala_Plantao', COUNT(*) FROM escala_plantao;
    """
    return run_query(sql)


def get_tempo_medio_por_residente():
    """CRUD 6 / Analítica: Tempo médio de duração dos atendimentos por residente."""
    sql = """
        SELECT pes.nome AS residente, COUNT(a.id_atendimento) AS total_atendimentos,
               ROUND(AVG(a.duracao_minutos), 2) AS tempo_medio_minutos
        FROM atendimento a
        JOIN papel_residente pr ON a.id_papel_residente = pr.id_papel
        JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel
        JOIN pessoa pes ON ppr.id_profissional = pes.id_pessoa
        GROUP BY pes.id_pessoa, pes.nome
        ORDER BY tempo_medio_minutos DESC;
    """
    df = run_query(sql)
    if not df.empty and 'tempo_medio_minutos' in df.columns:
        df['tempo_medio_minutos'] = df['tempo_medio_minutos'].astype(float)
    return df


def get_ranking_residentes():
    """Analítica 4.1: Ranking dos residentes por número de atendimentos."""
    sql = """
        SELECT pes.nome AS residente, COUNT(a.id_atendimento) AS total_atendimentos,
               RANK() OVER (ORDER BY COUNT(a.id_atendimento) DESC) AS ranking
        FROM atendimento a
        JOIN papel_residente pr ON a.id_papel_residente = pr.id_papel
        JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel
        JOIN pessoa pes ON ppr.id_profissional = pes.id_pessoa
        GROUP BY pes.id_pessoa, pes.nome ORDER BY ranking;
    """
    return run_query(sql)


def get_preceptores_mais_de_5(mes, ano):
    """Analítica 4.2: Preceptores com mais de 5 atendimentos em um determinado mês/ano."""
    sql = """
        SELECT pes.nome AS preceptor, COUNT(a.id_atendimento) AS total_atendimentos
        FROM atendimento a
        JOIN papel_preceptor pp ON a.id_papel_preceptor = pp.id_papel
        JOIN papel_profissional ppp ON pp.id_papel = ppp.id_papel
        JOIN pessoa pes ON ppp.id_profissional = pes.id_pessoa
        WHERE EXTRACT(MONTH FROM a.data_hora) = %s AND EXTRACT(YEAR FROM a.data_hora) = %s
        GROUP BY pes.id_pessoa, pes.nome
        HAVING COUNT(a.id_atendimento) > 5
        ORDER BY total_atendimentos DESC;
    """
    return run_query(sql, (int(mes), int(ano)))


def get_plantoes_por_unidade_residente():
    """Analítica 4.3: Plantões escalados por residente em cada unidade."""
    sql = """
        SELECT u.nome AS unidade, pes.nome AS residente, COUNT(ep.id_escala) AS total_plantoes
        FROM escala_plantao ep
        JOIN unidade u ON ep.id_unidade = u.id_unidade
        JOIN papel_residente pr ON ep.id_papel_residente = pr.id_papel
        JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel
        JOIN pessoa pes ON ppr.id_profissional = pes.id_pessoa
        GROUP BY u.id_unidade, u.nome, pes.id_pessoa, pes.nome
        ORDER BY u.nome, pes.nome;
    """
    return run_query(sql)


def get_pacientes_sem_risco_alto():
    """Analítica 4.4: Pacientes que nunca realizaram procedimento de risco ALTO."""
    sql = """
        SELECT pes.nome AS paciente, pes.cpf
        FROM paciente pac
        JOIN pessoa pes ON pac.id_pessoa = pes.id_pessoa
        WHERE pac.id_pessoa NOT IN (
            SELECT a.id_paciente FROM atendimento a
            JOIN procedimento_realizado pr ON a.id_atendimento = pr.id_atendimento
            JOIN procedimento proc ON pr.codigo_procedimento = proc.codigo
            WHERE proc.nivel_risco = 'ALTO'
        )
        ORDER BY pes.nome;
    """
    return run_query(sql)
