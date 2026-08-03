"""
ui/sidebar.py — Renderização da barra lateral de conexão
"""

import streamlit as st
from database.connection import get_db_credentials, run_query


def render_sidebar():
    """Renderiza a configuração de parâmetros de conexão no Sidebar."""
    st.sidebar.title("🔌 Conexão com o Banco")
    default_user, default_password, default_host, default_port, default_dbname = get_db_credentials()
    st.session_state.db_host = st.sidebar.text_input("Host", default_host)
    st.session_state.db_port = st.sidebar.text_input("Porta", default_port)
    st.session_state.db_name = st.sidebar.text_input("Banco", default_dbname)
    st.session_state.db_user = st.sidebar.text_input("Usuário", default_user)
    st.session_state.db_pass = st.sidebar.text_input("Senha", default_password, type="password")

    if st.sidebar.button("Testar conexão"):
        try:
            run_query("SELECT 1;")
            st.sidebar.success("Conectado com sucesso!")
        except Exception as e:
            st.sidebar.error(f"Falha na conexão: {e}")
