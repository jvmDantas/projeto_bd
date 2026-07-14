"""
Sistema de Gestão Hospitalar - Dra. Yuska Maritan Brito
Interface Streamlit para demonstração das funcionalidades do BD (Etapa 1)

Como executar:
    pip install -r requirements.txt
    streamlit run app.py
"""

import streamlit as st
import pandas as pd
import psycopg2

st.set_page_config(page_title="Gestão Hospitalar", page_icon="🏥", layout="wide")


# ---------------------------------------------------------------------------
# CONEXÃO COM O BANCO
# ---------------------------------------------------------------------------
def get_connection():
    return psycopg2.connect(
        host=st.session_state.db_host,
        port=st.session_state.db_port,
        dbname=st.session_state.db_name,
        user=st.session_state.db_user,
        password=st.session_state.db_pass,
    )


def run_query(sql, params=None):
    """SELECT -> DataFrame"""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            cols = [c.name for c in cur.description]
            rows = cur.fetchall()
    return pd.DataFrame(rows, columns=cols)


def run_command(sql, params=None):
    """INSERT/UPDATE/DELETE -> retorna nº de linhas afetadas"""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            affected = cur.rowcount
        conn.commit()
    return affected


# ---------------------------------------------------------------------------
# SIDEBAR: CONFIGURAÇÃO DE CONEXÃO
# ---------------------------------------------------------------------------
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

st.title("🏥 Sistema de Gestão Hospitalar — Dra. Yuska Maritan Brito")
st.caption("Demonstração das funcionalidades do banco de dados — Etapa 1")

tabs = st.tabs([
    "📊 Visão Geral",
    "📝 Atendimentos",
    "👤 Pacientes",
    "💉 Procedimentos Realizados",
    "📈 Consultas Analíticas",
])

# ---------------------------------------------------------------------------
# TAB 1: VISÃO GERAL
# ---------------------------------------------------------------------------
with tabs[0]:
    st.subheader("Contagem de registros por tabela")
    try:
        overview_sql = """
            SELECT 'Pessoa' AS tabela, COUNT(*) AS registros FROM pessoa
            UNION ALL SELECT 'Paciente', COUNT(*) FROM paciente
            UNION ALL SELECT 'Profissional', COUNT(*) FROM profissional
            UNION ALL SELECT 'Papel_Residente', COUNT(*) FROM papel_residente
            UNION ALL SELECT 'Papel_Preceptor', COUNT(*) FROM papel_preceptor
            UNION ALL SELECT 'Unidade', COUNT(*) FROM unidade
            UNION ALL SELECT 'Procedimento', COUNT(*) FROM procedimento
            UNION ALL SELECT 'Atendimento', COUNT(*) FROM atendimento
            UNION ALL SELECT 'Procedimento_Realizado', COUNT(*) FROM procedimento_realizado
            UNION ALL SELECT 'Escala_Plantao', COUNT(*) FROM escala_plantao;
        """
        df = run_query(overview_sql)
        c1, c2 = st.columns([1, 2])
        with c1:
            st.dataframe(df, hide_index=True, use_container_width=True)
        with c2:
            st.bar_chart(df.set_index("tabela"))
    except Exception as e:
        st.error(f"Erro ao consultar o banco: {e}")
        st.info("Confira os dados de conexão na barra lateral e clique em 'Testar conexão'.")

# ---------------------------------------------------------------------------
# TAB 2: ATENDIMENTOS (CRUD 1, 2, 3, 6)
# ---------------------------------------------------------------------------
with tabs[1]:
    st.subheader("1️⃣ Inserir novo atendimento (com validação de FK)")
    st.caption("A inserção só ocorre se paciente, residente e preceptor existirem no banco.")

    try:
        pacientes = run_query("""
            SELECT pac.id_pessoa, pes.nome FROM paciente pac
            JOIN pessoa pes ON pac.id_pessoa = pes.id_pessoa ORDER BY pes.nome;
        """)
        residentes = run_query("""
            SELECT pr.id_papel, pes.nome FROM papel_residente pr
            JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel
            JOIN pessoa pes ON ppr.id_profissional = pes.id_pessoa ORDER BY pes.nome;
        """)
        preceptores = run_query("""
            SELECT pp.id_papel, pes.nome FROM papel_preceptor pp
            JOIN papel_profissional ppp ON pp.id_papel = ppp.id_papel
            JOIN pessoa pes ON ppp.id_profissional = pes.id_pessoa ORDER BY pes.nome;
        """)

        with st.form("form_inserir_atendimento"):
            col1, col2, col3 = st.columns(3)
            id_paciente = col1.selectbox(
                "Paciente", pacientes["id_pessoa"],
                format_func=lambda i: pacientes.set_index("id_pessoa").loc[i, "nome"])
            id_residente = col2.selectbox(
                "Residente", residentes["id_papel"],
                format_func=lambda i: residentes.set_index("id_papel").loc[i, "nome"])
            id_preceptor = col3.selectbox(
                "Preceptor", preceptores["id_papel"],
                format_func=lambda i: preceptores.set_index("id_papel").loc[i, "nome"])
            col4, col5 = st.columns(2)
            data_hora = col4.text_input("Data/Hora (YYYY-MM-DD HH:MM)", "2024-02-01 09:00")
            duracao = col5.number_input("Duração (min)", min_value=1, value=30)
            enviado = st.form_submit_button("Inserir atendimento")

        if enviado:
            sql = """
                INSERT INTO atendimento (data_hora, duracao_minutos, id_paciente, id_papel_residente, id_papel_preceptor)
                SELECT %s, %s, %s, %s, %s
                WHERE EXISTS (SELECT 1 FROM paciente WHERE id_pessoa = %s)
                  AND EXISTS (SELECT 1 FROM papel_residente WHERE id_papel = %s)
                  AND EXISTS (SELECT 1 FROM papel_preceptor WHERE id_papel = %s);
            """
            params = (data_hora, duracao, id_paciente, id_residente, id_preceptor,
                      id_paciente, id_residente, id_preceptor)
            try:
                linhas = run_command(sql, params)
                if linhas:
                    st.success("Atendimento inserido com sucesso!")
                else:
                    st.warning("Nada inserido — paciente, residente ou preceptor não encontrado.")
            except Exception as e:
                st.error(f"Erro ao inserir: {e}")
    except Exception as e:
        st.error(f"Erro ao carregar listas: {e}")

    st.divider()
    st.subheader("2️⃣ Listar atendimentos de um paciente (ordenados por data)")
    try:
        if len(pacientes):
            id_pac_consulta = st.selectbox(
                "Selecione o paciente", pacientes["id_pessoa"],
                format_func=lambda i: pacientes.set_index("id_pessoa").loc[i, "nome"],
                key="consulta_paciente")
            sql = """
                SELECT a.id_atendimento, a.data_hora, a.duracao_minutos,
                       pes_res.nome AS residente, pes_pre.nome AS preceptor
                FROM atendimento a
                JOIN papel_residente pr ON a.id_papel_residente = pr.id_papel
                JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel
                JOIN pessoa pes_res ON ppr.id_profissional = pes_res.id_pessoa
                JOIN papel_preceptor pp ON a.id_papel_preceptor = pp.id_papel
                JOIN papel_profissional ppp ON pp.id_papel = ppp.id_papel
                JOIN pessoa pes_pre ON ppp.id_profissional = pes_pre.id_pessoa
                WHERE a.id_paciente = %s
                ORDER BY a.data_hora ASC;
            """
            st.dataframe(run_query(sql, (id_pac_consulta,)), hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()
    st.subheader("3️⃣ Listar procedimentos realizados em um atendimento")
    try:
        atendimentos = run_query("SELECT id_atendimento FROM atendimento ORDER BY id_atendimento;")
        id_atd = st.selectbox("Selecione o atendimento", atendimentos["id_atendimento"], key="proc_atd")
        sql = """
            SELECT proc.nome AS procedimento, pr.quantidade, pr.tempo_real_minutos,
                   pr.observacao_intercorrencia, pr.flag_faturado
            FROM procedimento_realizado pr
            JOIN procedimento proc ON pr.codigo_procedimento = proc.codigo
            WHERE pr.id_atendimento = %s
            ORDER BY proc.nome;
        """
        st.dataframe(run_query(sql, (id_atd,)), hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()
    st.subheader("6️⃣ Tempo médio de duração dos atendimentos por residente")
    try:
        sql = """
            SELECT pes.nome AS residente, COUNT(a.id_atendimento) AS total_atendimentos,
                   ROUND(AVG(a.duracao_minutos), 2) AS tempo_medio_minutos
            FROM atendimento a
            JOIN papel_residente pr ON a.id_papel_residente = pr.id_papel
            JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel
            JOIN pessoa pes ON ppr.id_profissional = pes.id_pessoa
            GROUP BY pes.id_pessoa, pes.nome
            ORDER BY tempo_medio_minutos DESC;
        """
        df = run_query(sql)
        df["tempo_medio_minutos"] = df["tempo_medio_minutos"].astype(float)
        c1, c2 = st.columns([2, 1])
        c1.dataframe(df, hide_index=True, use_container_width=True)
        c2.bar_chart(df.set_index("residente")["tempo_medio_minutos"])
    except Exception as e:
        st.error(f"Erro: {e}")

# ---------------------------------------------------------------------------
# TAB 3: PACIENTES (CRUD 4)
# ---------------------------------------------------------------------------
with tabs[2]:
    st.subheader("4️⃣ Atualizar dados de um paciente (endereço ou convênio)")
    try:
        pacientes2 = run_query("""
            SELECT pac.id_pessoa, pes.nome, pac.endereco, pac.num_convenio
            FROM paciente pac JOIN pessoa pes ON pac.id_pessoa = pes.id_pessoa
            ORDER BY pes.nome;
        """)
        id_pac_upd = st.selectbox(
            "Paciente", pacientes2["id_pessoa"],
            format_func=lambda i: pacientes2.set_index("id_pessoa").loc[i, "nome"], key="upd_pac")
        atual = pacientes2.set_index("id_pessoa").loc[id_pac_upd]

        with st.form("form_atualizar_paciente"):
            novo_endereco = st.text_input("Endereço", atual["endereco"] or "")
            novo_convenio = st.text_input("Nº Convênio", atual["num_convenio"] or "")
            atualizar = st.form_submit_button("Atualizar paciente")

        if atualizar:
            sql = "UPDATE paciente SET endereco = %s, num_convenio = %s WHERE id_pessoa = %s;"
            run_command(sql, (novo_endereco, novo_convenio, id_pac_upd))
            st.success("Paciente atualizado com sucesso!")
            st.rerun()
    except Exception as e:
        st.error(f"Erro: {e}")

# ---------------------------------------------------------------------------
# TAB 4: PROCEDIMENTOS REALIZADOS (CRUD 5)
# ---------------------------------------------------------------------------
with tabs[3]:
    st.subheader("5️⃣ Remover procedimento realizado (apenas se não faturado)")
    try:
        realizados = run_query("""
            SELECT pr.id_atendimento, pr.codigo_procedimento, proc.nome, pr.flag_faturado
            FROM procedimento_realizado pr
            JOIN procedimento proc ON pr.codigo_procedimento = proc.codigo
            ORDER BY pr.id_atendimento, proc.nome;
        """)
        st.dataframe(realizados, hide_index=True, use_container_width=True)

        st.markdown("**Selecione o procedimento a remover:**")
        col1, col2 = st.columns(2)
        opcoes = realizados.apply(
            lambda r: f"Atendimento {r.id_atendimento} — {r.nome} (faturado: {r.flag_faturado})", axis=1)
        escolha = col1.selectbox("Procedimento realizado", opcoes.index,
                                  format_func=lambda i: opcoes[i])
        linha = realizados.loc[escolha]

        if col2.button("🗑️ Remover", type="primary"):
            sql = """
                DELETE FROM procedimento_realizado
                WHERE id_atendimento = %s AND codigo_procedimento = %s AND flag_faturado = false;
            """
            afetadas = run_command(sql, (int(linha.id_atendimento), int(linha.codigo_procedimento)))
            if afetadas:
                st.success("Procedimento removido com sucesso!")
                st.rerun()
            else:
                st.warning("Não removido: este procedimento já possui faturamento associado.")
    except Exception as e:
        st.error(f"Erro: {e}")

# ---------------------------------------------------------------------------
# TAB 5: CONSULTAS ANALÍTICAS
# ---------------------------------------------------------------------------
with tabs[4]:
    st.subheader("📌 Ranking dos residentes por número de atendimentos")
    try:
        sql = """
            SELECT pes.nome AS residente, COUNT(a.id_atendimento) AS total_atendimentos,
                   RANK() OVER (ORDER BY COUNT(a.id_atendimento) DESC) AS ranking
            FROM atendimento a
            JOIN papel_residente pr ON a.id_papel_residente = pr.id_papel
            JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel
            JOIN pessoa pes ON ppr.id_profissional = pes.id_pessoa
            GROUP BY pes.id_pessoa, pes.nome ORDER BY ranking;
        """
        df = run_query(sql)
        c1, c2 = st.columns([2, 1])
        c1.dataframe(df, hide_index=True, use_container_width=True)
        c2.bar_chart(df.set_index("residente")["total_atendimentos"])
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()
    st.subheader("📌 Preceptores com mais de 5 atendimentos em um mês")
    try:
        col1, col2 = st.columns(2)
        mes = col1.number_input("Mês", min_value=1, max_value=12, value=1)
        ano = col2.number_input("Ano", min_value=2000, max_value=2100, value=2024)
        sql = """
            SELECT pes.nome AS preceptor, COUNT(a.id_atendimento) AS total_atendimentos
            FROM atendimento a
            JOIN papel_preceptor pp ON a.id_papel_preceptor = pp.id_papel
            JOIN papel_profissional ppp ON pp.id_papel = ppp.id_papel
            JOIN pessoa pes ON ppp.id_profissional = pes.id_pessoa
            WHERE EXTRACT(MONTH FROM a.data_hora) = %s AND EXTRACT(YEAR FROM a.data_hora) = %s
            GROUP BY pes.id_pessoa, pes.nome
            HAVING COUNT(a.id_atendimento) > 5
            ORDER BY total_atendimentos DESC;
        """
        df = run_query(sql, (int(mes), int(ano)))
        if df.empty:
            st.info("Nenhum preceptor ultrapassou 5 atendimentos no período selecionado.")
        else:
            st.dataframe(df, hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()
    st.subheader("📌 Plantões escalados por residente, por unidade")
    try:
        sql = """
            SELECT u.nome AS unidade, pes.nome AS residente, COUNT(ep.id_escala) AS total_plantoes
            FROM escala_plantao ep
            JOIN unidade u ON ep.id_unidade = u.id_unidade
            JOIN papel_residente pr ON ep.id_papel_residente = pr.id_papel
            JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel
            JOIN pessoa pes ON ppr.id_profissional = pes.id_pessoa
            GROUP BY u.id_unidade, u.nome, pes.id_pessoa, pes.nome
            ORDER BY u.nome, pes.nome;
        """
        st.dataframe(run_query(sql), hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()
    st.subheader("📌 Pacientes que nunca realizaram procedimento de risco ALTO")
    try:
        sql = """
            SELECT pes.nome AS paciente, pes.cpf
            FROM paciente pac
            JOIN pessoa pes ON pac.id_pessoa = pes.id_pessoa
            WHERE pac.id_pessoa NOT IN (
                SELECT a.id_paciente FROM atendimento a
                JOIN procedimento_realizado pr ON a.id_atendimento = pr.id_atendimento
                JOIN procedimento proc ON pr.codigo_procedimento = proc.codigo
                WHERE proc.nivel_risco = 'ALTO'
            )
            ORDER BY pes.nome;
        """
        st.dataframe(run_query(sql), hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")
