"""
app.py — Ponto de entrada do Sistema de Gestão Hospitalar (Streamlit UI)

Como executar:
    pip install -r requirements.txt
    streamlit run app.py
"""

import os
from pathlib import Path
from urllib.parse import urlparse

import streamlit as st
from ui.sidebar import render_sidebar
from ui.tab_overview import render_tab_overview
from ui.tab_atendimentos import render_tab_atendimentos
from ui.tab_pacientes import render_tab_pacientes
from ui.tab_procedimentos import render_tab_procedimentos
from ui.tab_analytics import render_tab_analytics
from ui.tab_sp_views import render_tab_sp_views
from ui.tab_orm_advanced import render_tab_orm_advanced
from ui.tab_concurrency import render_tab_concurrency

# Configuração da página Streamlit
st.set_page_config(page_title="Gestão Hospitalar", page_icon="🏥", layout="wide")

# Renderização do menu lateral (Sidebar)
render_sidebar()

# Título Principal
st.title("🏥 Sistema de Gestão Hospitalar — Dra. Yuska Maritan Brito")
st.caption("Demonstração das funcionalidades do banco de dados — Etapa 1 + Etapa 2")

# Definição e roteamento das abas
tabs = st.tabs([
    "📊 Visão Geral",
    "📝 Atendimentos",
    "👤 Pacientes",
    "💉 Procedimentos Realizados",
    "📈 Consultas Analíticas",
    "🗄️ SPs, Triggers & Views",
    "🔗 ORM & Consultas Avançadas",
    "⚡ Concorrência & Transações",
])

with tabs[0]: render_tab_overview()
with tabs[1]: render_tab_atendimentos()
with tabs[2]: render_tab_pacientes()
with tabs[3]: render_tab_procedimentos()
with tabs[4]: render_tab_analytics()
with tabs[5]: render_tab_sp_views()
with tabs[6]: render_tab_orm_advanced()
with tabs[7]: render_tab_concurrency()
