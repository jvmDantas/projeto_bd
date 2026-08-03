"""
ui/tab_procedimentos.py — Renderização da Tab 4: Procedimentos Realizados (CRUD 5)
"""

import streamlit as st
from database.connection import run_query
from services.crud_service import delete_procedimento_realizado


def render_tab_procedimentos():
    """Renderiza a listagem e deleção condicional de procedimentos realizados."""
    st.subheader("Remover procedimento realizado (apenas se não faturado)")
    try:
        realizados = run_query("""
            SELECT pr.id_atendimento, pr.codigo_procedimento, proc.nome, pr.flag_faturado
            FROM procedimento_realizado pr
            JOIN procedimento proc ON pr.codigo_procedimento = proc.codigo
            ORDER BY pr.id_atendimento, proc.nome;
        """)
        if not realizados.empty:
            st.dataframe(realizados, hide_index=True, use_container_width=True)

            st.markdown("**Selecione o procedimento a remover:**")
            col1, col2 = st.columns(2)
            opcoes = realizados.apply(
                lambda r: f"Atendimento {r.id_atendimento} — {r.nome} (faturado: {r.flag_faturado})", axis=1)
            escolha = col1.selectbox("Procedimento realizado", opcoes.index,
                                      format_func=lambda i: opcoes[i])
            linha = realizados.loc[escolha]

            if col2.button("🗑️ Remover", type="primary"):
                afetadas = delete_procedimento_realizado(linha.id_atendimento, linha.codigo_procedimento)
                if afetadas:
                    st.success("Procedimento removido com sucesso!")
                    st.rerun()
                else:
                    st.warning("Não removido: este procedimento já possui faturamento associado.")
        else:
            st.info("Nenhum procedimento realizado cadastrado.")
    except Exception as e:
        st.error(f"Erro: {e}")
