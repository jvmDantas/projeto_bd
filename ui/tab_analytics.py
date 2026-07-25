"""
ui/tab_analytics.py — Renderização da Tab 5: Consultas Analíticas
"""

import streamlit as st
from services.analytics_service import (
    get_ranking_residentes, get_preceptores_mais_de_5,
    get_plantoes_por_unidade_residente, get_pacientes_sem_risco_alto
)


def render_tab_analytics():
    """Renderiza os relatórios analíticos em SQL puro."""
    st.subheader("Ranking dos residentes por número de atendimentos")
    try:
        df = get_ranking_residentes()
        c1, c2 = st.columns([2, 1])
        c1.dataframe(df, hide_index=True, use_container_width=True)
        if not df.empty and "residente" in df.columns:
            c2.bar_chart(df.set_index("residente")["total_atendimentos"])
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()
    st.subheader("Preceptores com mais de 5 atendimentos em um mês")
    try:
        col1, col2 = st.columns(2)
        mes = col1.number_input("Mês", min_value=1, max_value=12, value=1)
        ano = col2.number_input("Ano", min_value=2000, max_value=2100, value=2024)
        df = get_preceptores_mais_de_5(mes, ano)
        if df.empty:
            st.info("Nenhum preceptor ultrapassou 5 atendimentos no período selecionado.")
        else:
            st.dataframe(df, hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()
    st.subheader("Plantões escalados por residente, por unidade")
    try:
        st.dataframe(get_plantoes_por_unidade_residente(), hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()
    st.subheader("Pacientes que nunca realizaram procedimento de risco ALTO")
    try:
        st.dataframe(get_pacientes_sem_risco_alto(), hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")
