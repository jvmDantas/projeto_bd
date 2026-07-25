"""
ui/sidebar.py — Renderização da barra lateral de conexão
"""

import streamlit as st
from database.connection import run_query


def render_sidebar():
    """Renderiza a configuração de parâmetros de conexão no Sidebar."""
    st.sidebar.title("🔌 Conexão com o Banco")
    st.session_state.db_host = st.sidebar.text_input("Host", "localhost")
    st.session_state.db_port = st.sidebar.text_input("Porta", "5432")
    st.session_state.db_name = st.sidebar.text_input("Banco", "postgres")
    st.session_state.db_user = st.sidebar.text_input("Usuário", "postgres")
    st.session_state.db_pass = st.sidebar.text_input("Senha", "*Edwiges1234", type="password")

    if st.sidebar.button("Testar conexão"):
        try:
            run_query("SELECT 1;")
            st.sidebar.success("Conectado com sucesso!")
        except Exception as e:
            st.sidebar.error(f"Falha na conexão: {e}")
