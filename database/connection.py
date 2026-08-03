"""
database/connection.py — Gerenciamento de conexões com o PostgreSQL (Psycopg2 + SQLAlchemy)
"""

import os
import streamlit as st
import pandas as pd
import psycopg2
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker


load_dotenv()


def get_db_credentials():
    """Recupera as credenciais do st.session_state com suporte seguro a threads secundárias."""
    user = os.getenv("DB_USER", "postgres")
    password = os.getenv("DB_PASSWORD", "postgres")
    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "5432")
    dbname = os.getenv("DB_NAME", "postgres")

    try:
        if hasattr(st, "session_state"):
            user = getattr(st.session_state, "db_user", user)
            password = getattr(st.session_state, "db_pass", password)
            host = getattr(st.session_state, "db_host", host)
            port = getattr(st.session_state, "db_port", port)
            dbname = getattr(st.session_state, "db_name", dbname)
    except Exception:
        pass

    return user, password, host, port, dbname


def get_connection():
    """Retorna conexão ativa Psycopg2 com os parâmetros configurados no sidebar."""
    user, password, host, port, dbname = get_db_credentials()
    return psycopg2.connect(
        host=host,
        port=port,
        dbname=dbname,
        user=user,
        password=password,
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


def get_orm_url():
    """Retorna a string de conexão SQLAlchemy baseada nos dados atuais do session_state."""
    user, password, host, port, dbname = get_db_credentials()
    return f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{dbname}"


def get_orm_session(url: str = None):
    """Abre uma sessão SQLAlchemy usando o engine cacheado pelo Streamlit."""
    if not url:
        url = get_orm_url()
    return sessionmaker(bind=get_orm_engine(url))()

