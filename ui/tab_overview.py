"""
ui/tab_overview.py — Renderização da Tab 1: Visão Geral
"""

import streamlit as st
from services.analytics_service import get_overview_counts


def render_tab_overview():
    """Renderiza a visão geral com estatísticas do banco de dados."""
    st.subheader("Contagem de registros por tabela")
    try:
        df = get_overview_counts()
        c1, c2 = st.columns([1, 2])
        with c1:
            st.dataframe(df, hide_index=True, use_container_width=True)
        with c2:
            st.bar_chart(df.set_index("tabela"))
    except Exception as e:
        st.error(f"Erro ao consultar o banco: {e}")
        st.info("Confira os dados de conexão na barra lateral e clique em 'Testar conexão'.")
