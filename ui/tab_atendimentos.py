"""
ui/tab_atendimentos.py — Renderização da Tab 2: Atendimentos (CRUD 1, 2, 3, 6)
"""

import streamlit as st
from services.crud_service import (
    load_lookup_options, insert_atendimento, get_atendimentos_by_paciente,
    get_procedimentos_by_atendimento
)
from services.analytics_service import get_tempo_medio_por_residente


def render_tab_atendimentos():
    """Renderiza os formulários e consultas de atendimentos."""
    st.subheader("Inserir novo atendimento")
    st.caption("A inserção só ocorre se paciente, residente e preceptor existirem no banco.")

    try:
        pacientes, residentes, preceptores, _ = load_lookup_options()

        with st.form("form_inserir_atendimento"):
            col1, col2, col3 = st.columns(3)
            id_paciente = col1.selectbox(
                "Paciente", pacientes["id_pessoa"],
                format_func=lambda i: pacientes.set_index("id_pessoa").loc[i, "nome"])
            id_residente = col2.selectbox(
                "Residente", residentes["id_papel"],
                format_func=lambda i: residentes.set_index("id_papel").loc[i, "nome"])
            id_preceptor = col3.selectbox(
                "Preceptor", preceptores["id_papel"],
                format_func=lambda i: preceptores.set_index("id_papel").loc[i, "nome"])
            col4, col5 = st.columns(2)
            data_hora = col4.text_input("Data/Hora (YYYY-MM-DD HH:MM)", "2024-02-01 09:00")
            duracao = col5.number_input("Duração (min)", min_value=1, value=30)
            enviado = st.form_submit_button("Inserir atendimento")

        if enviado:
            try:
                linhas = insert_atendimento(data_hora, duracao, id_paciente, id_residente, id_preceptor)
                if linhas:
                    st.success("Atendimento inserido com sucesso!")
                else:
                    st.warning("Nada inserido — paciente, residente ou preceptor não encontrado.")
            except Exception as e:
                st.error(f"Erro ao inserir: {e}")
    except Exception as e:
        st.error(f"Erro ao carregar listas: {e}")

    st.divider()
    st.subheader("Listar atendimentos de um paciente (ordenados por data)")
    try:
        if len(pacientes):
            id_pac_consulta = st.selectbox(
                "Selecione o paciente", pacientes["id_pessoa"],
                format_func=lambda i: pacientes.set_index("id_pessoa").loc[i, "nome"],
                key="consulta_paciente")
            st.dataframe(get_atendimentos_by_paciente(id_pac_consulta), hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()
    st.subheader("Listar procedimentos realizados em um atendimento")
    try:
        from database.connection import run_query
        atendimentos = run_query("SELECT id_atendimento FROM atendimento ORDER BY id_atendimento;")
        if not atendimentos.empty:
            id_atd = st.selectbox("Selecione o atendimento", atendimentos["id_atendimento"], key="proc_atd")
            st.dataframe(get_procedimentos_by_atendimento(id_atd), hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()
    st.subheader("Tempo médio de duração dos atendimentos por residente")
    try:
        df = get_tempo_medio_por_residente()
        c1, c2 = st.columns([2, 1])
        c1.dataframe(df, hide_index=True, use_container_width=True)
        if not df.empty and "residente" in df.columns:
            c2.bar_chart(df.set_index("residente")["tempo_medio_minutos"])
    except Exception as e:
        st.error(f"Erro: {e}")
