"""
ui/tab_orm_advanced.py — Renderização da Tab 7: Consultas Avançadas com ORM (Etapa 2)
"""

import streamlit as st
import pandas as pd
from services.orm_service import (
    get_preceptores_flamenguistas_orm,
    get_ultimo_atendimento_pacientes_orm,
    get_pct_alto_risco_residentes_orm
)


def render_tab_orm_advanced():
    """Renderiza as consultas avançadas implementadas via DSL SQLAlchemy."""
    st.subheader("🔗 ORM SQLAlchemy — Mapeamento e Consultas Avançadas")
    st.caption(
        "Todas as consultas abaixo usam exclusivamente a DSL do SQLAlchemy "
        "(sem SQL cru). Demonstra eager/lazy loading, sessões e filtros ORM."
    )

    try:
        orm_choice = st.radio(
            "Consulta:",
            ["1. Preceptores de residentes que atenderam pacientes flamenguistas",
             "2. Último atendimento de cada paciente (residente, preceptor, procedimentos)",
             "3. Percentual de procedimentos de alto risco por residente"],
            key="orm_radio"
        )

        if orm_choice.startswith("1."):
            rows = get_preceptores_flamenguistas_orm()
            st.dataframe(rows, hide_index=True, use_container_width=True)

        elif orm_choice.startswith("2."):
            resultado = get_ultimo_atendimento_pacientes_orm()
            st.dataframe(resultado, hide_index=True, use_container_width=True)

        elif orm_choice.startswith("3."):
            df_pct = get_pct_alto_risco_residentes_orm()
            c1, c2 = st.columns([2, 1])
            c1.dataframe(df_pct, hide_index=True, use_container_width=True)
            if not df_pct.empty and "residente" in df_pct.columns:
                c2.bar_chart(df_pct.set_index("residente")["pct_alto_risco"])

    except Exception as e:
        st.error(f"Erro na consulta ORM: {e}")
