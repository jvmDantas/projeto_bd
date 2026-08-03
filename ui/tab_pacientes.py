"""
ui/tab_pacientes.py — Renderização da Tab 3: Pacientes (CRUD 4)
"""

import streamlit as st
from database.connection import run_query
from services.crud_service import update_paciente


def render_tab_pacientes():
    """Renderiza formulário de edição de paciente."""
    st.subheader("Atualizar dados de um paciente (endereço ou convênio)")
    try:
        pacientes2 = run_query("""
            SELECT pac.id_pessoa, pes.nome, pac.endereco, pac.num_convenio
            FROM paciente pac JOIN pessoa pes ON pac.id_pessoa = pes.id_pessoa
            ORDER BY pes.nome;
        """)
        if not pacientes2.empty:
            id_pac_upd = st.selectbox(
                "Paciente", pacientes2["id_pessoa"],
                format_func=lambda i: pacientes2.set_index("id_pessoa").loc[i, "nome"], key="upd_pac")
            atual = pacientes2.set_index("id_pessoa").loc[id_pac_upd]

            with st.form("form_atualizar_paciente"):
                novo_endereco = st.text_input("Endereço", atual["endereco"] or "")
                novo_convenio = st.text_input("Nº Convênio", atual["num_convenio"] or "")
                atualizar = st.form_submit_button("Atualizar paciente")

            if atualizar:
                update_paciente(id_pac_upd, novo_endereco, novo_convenio)
                st.success("Paciente atualizado com sucesso!")
                st.rerun()
    except Exception as e:
        st.error(f"Erro: {e}")
