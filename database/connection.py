"""
database/connection.py — Gerenciamento de conexões com o PostgreSQL (Psycopg2 + SQLAlchemy)
"""

import streamlit as st
import pandas as pd
import psycopg2
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker


def get_connection():
    """Retorna conexão ativa Psycopg2 com os parâmetros configurados no sidebar."""
    return psycopg2.connect(
        host=st.session_state.db_host,
        port=st.session_state.db_port,
        dbname=st.session_state.db_name,
        user=st.session_state.db_user,
        password=st.session_state.db_pass,
    )


def run_query(sql, params=None):
    """Executa SELECT via Psycopg2 e retorna DataFrame Pandas."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            cols = [c.name for c in cur.description]
            rows = cur.fetchall()
    return pd.DataFrame(rows, columns=cols)


def run_command(sql, params=None):
    """Executa INSERT/UPDATE/DELETE via Psycopg2 e retorna nº de linhas afetadas."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            affected = cur.rowcount
        conn.commit()
    return affected


@st.cache_resource
def get_orm_engine(url: str):
    """Engine SQLAlchemy cacheado por URL — reutiliza o pool de conexões entre rerenders."""
    return create_engine(url)


def get_orm_session():
    """Abre uma sessão SQLAlchemy usando o engine cacheado pelo Streamlit."""
    url = (
        f"postgresql+psycopg2://"
        f"{st.session_state.db_user}:{st.session_state.db_pass}"
        f"@{st.session_state.db_host}:{st.session_state.db_port}"
        f"/{st.session_state.db_name}"
    )
    return sessionmaker(bind=get_orm_engine(url))()
