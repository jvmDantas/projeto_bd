"""
services/sp_views_service.py — Serviços para Stored Procedures, Triggers e Views (Etapa 2)
"""

import json
from database.connection import run_query, run_command


def call_sp_registrar_atendimento_completo(dh, dur, pac_id, res_id, pre_id, procs_list, obs=""):
    """SP 1: Executa a procedure atômica em PL/pgSQL com lista JSONB de procedimentos."""
    procs_json = json.dumps([
        {"codigo": c, "quantidade": 1, "tempo_real": 20, "observacao": obs}
        for c in procs_list
    ])
    sql_sp = """
        CALL sp_registrar_atendimento_completo(
            %(dh)s::timestamp, %(dur)s, %(pac)s, %(res)s, %(pre)s,
            %(procs)s::jsonb
        );
    """
    return run_command(sql_sp, {
        "dh": dh, "dur": dur, "pac": int(pac_id),
        "res": int(res_id), "pre": int(pre_id), "procs": procs_json
    })


def call_sp_calcular_tempo_medio_espera():
    """SP 2: Executa a função PL/pgSQL de cálculo do tempo médio de espera por unidade."""
    return run_query("SELECT * FROM sp_calcular_tempo_medio_espera();")


def call_sp_reajustar_escala(res_id, dia_ant, trn_ant, dia_nov, trn_nov):
    """SP 3: Executa a procedure de reajuste de escalas em lote."""
    sql = "CALL sp_reajustar_escala(%(res)s, %(da)s, %(ta)s, %(dn)s, %(tn)s);"
    return run_command(sql, {
        "res": int(res_id), "da": dia_ant, "ta": trn_ant,
        "dn": dia_nov,  "tn": trn_nov
    })


def get_auditoria_logs():
    """Consulta os registros gerados automaticamente pelo Trigger trg_audita_atendimento."""
    sql = """
        SELECT id_auditoria, id_atendimento, operacao, usuario, data_hora,
               dados_antigos::text, dados_novos::text
        FROM auditoria_atendimento ORDER BY id_auditoria DESC LIMIT 50;
    """
    return run_query(sql)


def get_procedimentos_com_media():
    """Consulta a coluna media_tempo_procedimento atualizada pelo Trigger trg_atualiza_media_procedimentos."""
    sql = """
        SELECT codigo, nome, tempo_medio_minutos, nivel_risco, media_tempo_procedimento
        FROM procedimento ORDER BY codigo;
    """
    return run_query(sql)


def get_view_data(view_name):
    """Consulta segura de qualquer uma das Views criadas no banco de dados."""
    valid_views = [
        "vw_pacientes_internados",
        "vw_residentes_sem_supervisor",
        "vw_estatisticas_atendimentos_mensal"
    ]
    if view_name not in valid_views:
        raise ValueError(f"View inválida: {view_name}")
    return run_query(f"SELECT * FROM {view_name};")
