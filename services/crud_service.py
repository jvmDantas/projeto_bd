"""
services/crud_service.py — Serviços para as operações CRUD (Etapa 1)
"""

from database.connection import run_query, run_command


def load_lookup_options():
    """Carrega as tabelas de opções para preenchimento de selectboxes nos formulários."""
    pac = run_query(
        "SELECT pac.id_pessoa, pes.nome FROM paciente pac "
        "JOIN pessoa pes ON pac.id_pessoa = pes.id_pessoa ORDER BY pes.nome;"
    )
    res = run_query(
        "SELECT pr.id_papel, pes.nome FROM papel_residente pr "
        "JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel "
        "JOIN pessoa pes ON ppr.id_profissional = pes.id_pessoa ORDER BY pes.nome;"
    )
    pre = run_query(
        "SELECT pp.id_papel, pes.nome FROM papel_preceptor pp "
        "JOIN papel_profissional ppp ON pp.id_papel = ppp.id_papel "
        "JOIN pessoa pes ON ppp.id_profissional = pes.id_pessoa ORDER BY pes.nome;"
    )
    proc = run_query("SELECT codigo, nome FROM procedimento ORDER BY codigo;")
    return pac, res, pre, proc


def insert_atendimento(data_hora, duracao, id_paciente, id_residente, id_preceptor):
    """CRUD 1: Insere novo atendimento com verificação de existência das FKs."""
    sql = """
        INSERT INTO atendimento (data_hora, duracao_minutos, id_paciente, id_papel_residente, id_papel_preceptor)
        SELECT %s, %s, %s, %s, %s
        WHERE EXISTS (SELECT 1 FROM paciente WHERE id_pessoa = %s)
          AND EXISTS (SELECT 1 FROM papel_residente WHERE id_papel = %s)
          AND EXISTS (SELECT 1 FROM papel_preceptor WHERE id_papel = %s);
    """
    params = (data_hora, duracao, id_paciente, id_residente, id_preceptor,
              id_paciente, id_residente, id_preceptor)
    return run_command(sql, params)


def get_atendimentos_by_paciente(id_paciente):
    """CRUD 2: Lista atendimentos de um paciente específico por data crescente."""
    sql = """
        SELECT a.id_atendimento, a.data_hora, a.duracao_minutos,
               pes_res.nome AS residente, pes_pre.nome AS preceptor
        FROM atendimento a
        JOIN papel_residente pr ON a.id_papel_residente = pr.id_papel
        JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel
        JOIN pessoa pes_res ON ppr.id_profissional = pes_res.id_pessoa
        JOIN papel_preceptor pp ON a.id_papel_preceptor = pp.id_papel
        JOIN papel_profissional ppp ON pp.id_papel = ppp.id_papel
        JOIN pessoa pes_pre ON ppp.id_profissional = pes_pre.id_pessoa
        WHERE a.id_paciente = %s
        ORDER BY a.data_hora ASC;
    """
    return run_query(sql, (id_paciente,))


def get_procedimentos_by_atendimento(id_atendimento):
    """CRUD 3: Lista procedimentos realizados em determinado atendimento."""
    sql = """
        SELECT proc.nome AS procedimento, pr.quantidade, pr.tempo_real_minutos,
               pr.observacao_intercorrencia, pr.flag_faturado
        FROM procedimento_realizado pr
        JOIN procedimento proc ON pr.codigo_procedimento = proc.codigo
        WHERE pr.id_atendimento = %s
        ORDER BY proc.nome;
    """
    return run_query(sql, (id_atendimento,))


def update_paciente(id_paciente, novo_endereco, novo_convenio):
    """CRUD 4: Atualiza os dados de contato/convênio de um paciente."""
    sql = "UPDATE paciente SET endereco = %s, num_convenio = %s WHERE id_pessoa = %s;"
    return run_command(sql, (novo_endereco, novo_convenio, id_paciente))


def delete_procedimento_realizado(id_atendimento, codigo_procedimento):
    """CRUD 5: Remove um procedimento realizado se ainda não houver faturamento."""
    sql = """
        DELETE FROM procedimento_realizado
        WHERE id_atendimento = %s AND codigo_procedimento = %s AND flag_faturado = false;
    """
    return run_command(sql, (int(id_atendimento), int(codigo_procedimento)))
