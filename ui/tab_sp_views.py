"""
ui/tab_sp_views.py — Renderização da Tab 6: SPs, Triggers & Views (Etapa 2)
"""

import streamlit as st
from services.crud_service import load_lookup_options
from services.sp_views_service import (
    call_sp_registrar_atendimento_completo, call_sp_calcular_tempo_medio_espera,
    call_sp_reajustar_escala, get_auditoria_logs, get_procedimentos_com_media, get_view_data
)

_DIAS   = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo']
_TURNOS = ['manhã', 'tarde', 'noite']


def render_tab_sp_views():
    """Renderiza a interface para execução de SPs, visualização de Triggers e Views."""
    st.subheader("🗄️ Stored Procedures, Triggers & Views — Etapa 2")

    # ── SP 1: sp_registrar_atendimento_completo ──────────────────────────────
    st.markdown("### SP 1 — `sp_registrar_atendimento_completo`")
    st.caption(
        "Insere atendimento + procedimentos em uma única transação PL/pgSQL. "
        "Qualquer falha reverte tudo (ROLLBACK implícito)."
    )
    try:
        pac_opts, res_opts, pre_opts, proc_opts = load_lookup_options()

        with st.form("form_sp_atendimento"):
            c1, c2, c3 = st.columns(3)
            sp_pac = c1.selectbox(
                "Paciente", pac_opts["id_pessoa"],
                format_func=lambda i: pac_opts.set_index("id_pessoa").loc[i, "nome"])
            sp_res = c2.selectbox(
                "Residente", res_opts["id_papel"],
                format_func=lambda i: res_opts.set_index("id_papel").loc[i, "nome"])
            sp_pre = c3.selectbox(
                "Preceptor", pre_opts["id_papel"],
                format_func=lambda i: pre_opts.set_index("id_papel").loc[i, "nome"])
            c4, c5 = st.columns(2)
            sp_dh  = c4.text_input("Data/Hora (YYYY-MM-DD HH:MM)", "2024-03-01 10:00")
            sp_dur = c5.number_input("Duração (min)", min_value=1, value=30)
            sp_procs = st.multiselect(
                "Procedimentos realizados",
                proc_opts["codigo"].tolist(),
                format_func=lambda c: proc_opts.set_index("codigo").loc[c, "nome"])
            sp_obs = st.text_input("Observação", "")
            sp_btn = st.form_submit_button("▶ Executar SP (Transação)")

        if sp_btn:
            if not sp_procs:
                st.warning("Selecione ao menos um procedimento.")
            else:
                try:
                    call_sp_registrar_atendimento_completo(sp_dh, sp_dur, sp_pac, sp_res, sp_pre, sp_procs, sp_obs)
                    st.success("✅ SP executada com sucesso! Atendimento + procedimentos inseridos.")
                except Exception as ex:
                    st.error(f"❌ Rollback — {ex}")
    except Exception as e:
        st.error(f"Erro ao carregar opções: {e}")

    st.divider()

    # ── SP 2: sp_calcular_tempo_medio_espera ─────────────────────────────────
    st.markdown("### SP 2 — `sp_calcular_tempo_medio_espera`")
    st.caption("Calcula o tempo médio de espera por unidade (chegada → início do procedimento).")
    if st.button("▶ Chamar sp_calcular_tempo_medio_espera", key="btn_sp2"):
        try:
            df_esp = call_sp_calcular_tempo_medio_espera()
            st.dataframe(df_esp, hide_index=True, use_container_width=True)
        except Exception as e:
            st.error(f"Erro: {e}")

    st.divider()

    # ── SP 3: sp_reajustar_escala ─────────────────────────────────────────────
    st.markdown("### SP 3 — `sp_reajustar_escala`")
    st.caption(
        "Move todas as escalas de um residente de um dia/turno para outro. "
        "A trigger `trg_check_sobreposicao_escala` impede conflitos."
    )
    try:
        _, res_opts2, _, _ = load_lookup_options()
        with st.form("form_sp_reajustar"):
            c1, c2, c3 = st.columns(3)
            rj_res = c1.selectbox(
                "Residente", res_opts2["id_papel"],
                format_func=lambda i: res_opts2.set_index("id_papel").loc[i, "nome"],
                key="rj_res")
            rj_dia_ant = c2.selectbox("Dia origem",   _DIAS,   key="rj_dia_ant")
            rj_trn_ant = c3.selectbox("Turno origem", _TURNOS, key="rj_trn_ant")
            c4, c5 = st.columns(2)
            rj_dia_nov = c4.selectbox("Dia destino",   _DIAS,   key="rj_dia_nov")
            rj_trn_nov = c5.selectbox("Turno destino", _TURNOS, key="rj_trn_nov")
            rj_btn = st.form_submit_button("▶ Executar sp_reajustar_escala")

        if rj_btn:
            try:
                call_sp_reajustar_escala(rj_res, rj_dia_ant, rj_trn_ant, rj_dia_nov, rj_trn_nov)
                st.success("✅ Escala reajustada com sucesso!")
            except Exception as ex:
                st.error(f"❌ Conflito detectado — {ex}")
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()

    # ── TRIGGER: trg_audita_atendimento ──────────────────────────────────────
    st.markdown("### Trigger — `trg_audita_atendimento`")
    st.caption("Registros criados automaticamente após INSERT/UPDATE/DELETE em ATENDIMENTO.")
    try:
        df_audit = get_auditoria_logs()
        if df_audit.empty:
            st.info("Nenhum registro de auditoria ainda. Insira ou edite um atendimento.")
        else:
            st.dataframe(df_audit, hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()

    # ── TRIGGER: trg_atualiza_media_procedimentos ────────────────────────────
    st.markdown("### Trigger — `trg_atualiza_media_procedimentos`")
    st.caption(
        "Coluna `media_tempo_procedimento` atualizada automaticamente "
        "após cada INSERT em PROCEDIMENTO_REALIZADO."
    )
    try:
        df_med = get_procedimentos_com_media()
        st.dataframe(df_med, hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()

    # ── VIEWS ─────────────────────────────────────────────────────────────────
    st.markdown("### Views")
    view_choice = st.radio(
        "Selecione a view:",
        ["vw_pacientes_internados",
         "vw_residentes_sem_supervisor",
         "vw_estatisticas_atendimentos_mensal"],
        horizontal=True, key="view_radio"
    )
    try:
        df_view = get_view_data(view_choice)
        st.dataframe(df_view, hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro ao consultar view: {e}")
