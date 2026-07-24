"""
Sistema de Gestão Hospitalar - Dra. Yuska Maritan Brito

Como executar:
    pip install -r requirements.txt
    streamlit run app.py
"""

import json
import threading
import time
import streamlit as st
import pandas as pd
import psycopg2
from sqlalchemy import (
    create_engine, Column, Integer, String, Boolean, Date, DateTime,
    Numeric, Text, ForeignKey, func, text, case, distinct
)
from sqlalchemy.orm import declarative_base, relationship, sessionmaker, joinedload, selectinload

# Constantes de domínio — usadas nos formulários de escala (Tab 6)
_DIAS   = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo']
_TURNOS = ['manhã', 'tarde', 'noite']

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
st.caption("Demonstração das funcionalidades do banco de dados — Etapa 1 + Etapa 2")

tabs = st.tabs([
    "📊 Visão Geral",
    "📝 Atendimentos",
    "👤 Pacientes",
    "💉 Procedimentos Realizados",
    "📈 Consultas Analíticas",
    # ── Etapa 2 ──────────────────────────────────
    "🗄️ SPs, Triggers & Views",
    "🔗 ORM & Consultas Avançadas",
    "⚡ Concorrência & Transações",
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
    st.subheader("Inserir novo atendimento")
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
    st.subheader("Listar atendimentos de um paciente (ordenados por data)")
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
    st.subheader("Listar procedimentos realizados em um atendimento")
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
    st.subheader("Tempo médio de duração dos atendimentos por residente")
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
    st.subheader("Atualizar dados de um paciente (endereço ou convênio)")
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
    st.subheader("Remover procedimento realizado (apenas se não faturado)")
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
    st.subheader("Ranking dos residentes por número de atendimentos")
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
    st.subheader("Preceptores com mais de 5 atendimentos em um mês")
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
    st.subheader("Plantões escalados por residente, por unidade")
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
    st.subheader("Pacientes que nunca realizaram procedimento de risco ALTO")
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


# ===========================================================================
# ETAPA 2 — ORM: MAPEAMENTO OBJETO-RELACIONAL (SQLAlchemy)
# ===========================================================================

_Base = declarative_base()


class _Pessoa(_Base):
    __tablename__ = 'pessoa'
    id_pessoa       = Column(Integer, primary_key=True)
    nome            = Column(String(150), nullable=False)
    cpf             = Column(String(11),  nullable=False, unique=True)
    data_nascimento = Column(Date,        nullable=False)
    is_flamengo     = Column(Boolean,     default=False)
    telefone        = Column(String(11))
    paciente        = relationship('_Paciente',    back_populates='pessoa',        uselist=False)
    profissional    = relationship('_Profissional', back_populates='pessoa',       uselist=False)


class _Paciente(_Base):
    __tablename__ = 'paciente'
    id_pessoa    = Column(Integer, ForeignKey('pessoa.id_pessoa'), primary_key=True)
    num_convenio = Column(String(20))
    alergias     = Column(Text)
    grupo_sanguineo = Column(String(3))
    endereco     = Column(String(200))
    pessoa       = relationship('_Pessoa',      back_populates='paciente')
    atendimentos = relationship('_Atendimento', back_populates='paciente')


class _Profissional(_Base):
    __tablename__ = 'profissional'
    id_pessoa     = Column(Integer, ForeignKey('pessoa.id_pessoa'), primary_key=True)
    crm           = Column(String(20), nullable=False, unique=True)
    data_admissao = Column(Date,       nullable=False)
    especialidade = Column(String(100))
    pessoa        = relationship('_Pessoa',            back_populates='profissional')
    papeis        = relationship('_PapelProfissional', back_populates='profissional')


class _PapelProfissional(_Base):
    __tablename__   = 'papel_profissional'
    id_papel        = Column(Integer, primary_key=True)
    id_profissional = Column(Integer, ForeignKey('profissional.id_pessoa'), nullable=False)
    tipo_papel      = Column(String(20), nullable=False)
    data_inicio     = Column(Date,       nullable=False)
    data_fim        = Column(Date)
    profissional    = relationship('_Profissional',  back_populates='papeis')
    residente       = relationship('_PapelResidente', back_populates='papel_prof', uselist=False)
    preceptor       = relationship('_PapelPreceptor', back_populates='papel_prof', uselist=False)


class _PapelResidente(_Base):
    __tablename__  = 'papel_residente'
    id_papel       = Column(Integer, ForeignKey('papel_profissional.id_papel'), primary_key=True)
    ano_residencia = Column(String(2), nullable=False)
    papel_prof     = relationship('_PapelProfissional', back_populates='residente')
    atendimentos   = relationship('_Atendimento',       back_populates='residente')
    escalas        = relationship('_EscalaPlantao',     back_populates='residente')


class _PapelPreceptor(_Base):
    __tablename__ = 'papel_preceptor'
    id_papel      = Column(Integer, ForeignKey('papel_profissional.id_papel'), primary_key=True)
    titulacao     = Column(String(50))
    papel_prof    = relationship('_PapelProfissional', back_populates='preceptor')
    atendimentos  = relationship('_Atendimento',       back_populates='preceptor')
    escalas       = relationship('_EscalaPlantao',     back_populates='preceptor')


class _Unidade(_Base):
    __tablename__     = 'unidade'
    id_unidade        = Column(Integer, primary_key=True)
    nome              = Column(String(100), nullable=False)
    tipo              = Column(String(30),  nullable=False)
    capacidade_leitos = Column(Integer)
    escalas           = relationship('_EscalaPlantao', back_populates='unidade')


class _Procedimento(_Base):
    __tablename__            = 'procedimento'
    codigo                   = Column(Integer, primary_key=True)
    nome                     = Column(String(150), nullable=False)
    tempo_medio_minutos      = Column(Integer,     nullable=False)
    nivel_risco              = Column(String(10),  nullable=False)
    media_tempo_procedimento = Column(Numeric(10, 2), default=0.00)
    realizados               = relationship('_ProcedimentoRealizado', back_populates='procedimento')


class _Atendimento(_Base):
    __tablename__      = 'atendimento'
    id_atendimento     = Column(Integer, primary_key=True)
    data_hora          = Column(DateTime, nullable=False)
    duracao_minutos    = Column(Integer,  nullable=False)
    id_paciente        = Column(Integer, ForeignKey('paciente.id_pessoa'),       nullable=False)
    id_papel_residente = Column(Integer, ForeignKey('papel_residente.id_papel'), nullable=False)
    id_papel_preceptor = Column(Integer, ForeignKey('papel_preceptor.id_papel'), nullable=False)
    paciente           = relationship('_Paciente',      back_populates='atendimentos')
    residente          = relationship('_PapelResidente', back_populates='atendimentos')
    preceptor          = relationship('_PapelPreceptor', back_populates='atendimentos')
    realizados         = relationship('_ProcedimentoRealizado', back_populates='atendimento',
                                      cascade='all, delete-orphan')


class _ProcedimentoRealizado(_Base):
    __tablename__             = 'procedimento_realizado'
    id_atendimento            = Column(Integer, ForeignKey('atendimento.id_atendimento'),  primary_key=True)
    codigo_procedimento       = Column(Integer, ForeignKey('procedimento.codigo'),          primary_key=True)
    quantidade                = Column(Integer, nullable=False)
    tempo_real_minutos        = Column(Integer, nullable=False)
    observacao_intercorrencia = Column(Text)
    flag_faturado             = Column(Boolean, default=False)
    atendimento               = relationship('_Atendimento',  back_populates='realizados')
    procedimento              = relationship('_Procedimento', back_populates='realizados')


class _EscalaPlantao(_Base):
    __tablename__      = 'escala_plantao'
    id_escala          = Column(Integer, primary_key=True)
    id_unidade         = Column(Integer, ForeignKey('unidade.id_unidade'),          nullable=False)
    dia_semana         = Column(String(10), nullable=False)
    turno              = Column(String(10), nullable=False)
    id_papel_residente = Column(Integer, ForeignKey('papel_residente.id_papel'),    nullable=False)
    id_papel_preceptor = Column(Integer, ForeignKey('papel_preceptor.id_papel'),    nullable=False)
    unidade            = relationship('_Unidade',        back_populates='escalas')
    residente          = relationship('_PapelResidente', back_populates='escalas')
    preceptor          = relationship('_PapelPreceptor', back_populates='escalas')


class _AuditoriaAtendimento(_Base):
    __tablename__  = 'auditoria_atendimento'
    id_auditoria   = Column(Integer, primary_key=True)
    id_atendimento = Column(Integer)
    operacao       = Column(String(10),  nullable=False)
    usuario        = Column(String(100), nullable=False)
    data_hora      = Column(DateTime)
    dados_antigos  = Column(Text)   # JSONB no banco, Text no ORM (compatível)
    dados_novos    = Column(Text)


@st.cache_resource
def _get_orm_engine(url: str):
    """Engine SQLAlchemy cacheado por URL — reutiliza o pool de conexões entre rerenders."""
    return create_engine(url)


def _get_orm_session():
    """Abre uma sessão usando o engine cacheado pelo Streamlit."""
    url = (
        f"postgresql+psycopg2://"
        f"{st.session_state.db_user}:{st.session_state.db_pass}"
        f"@{st.session_state.db_host}:{st.session_state.db_port}"
        f"/{st.session_state.db_name}"
    )
    return sessionmaker(bind=_get_orm_engine(url))()


def _load_lookup_opts():
    """Carrega as quatro tabelas de opções usadas nos formulários de SP.
    Centraliza as queries para evitar duplicação entre Tab 6 SP1 e SP3.
    Retorna: (pac_opts, res_opts, pre_opts, proc_opts)
    """
    pac = run_query(
        "SELECT pac.id_pessoa, pes.nome FROM paciente pac "
        "JOIN pessoa pes ON pac.id_pessoa = pes.id_pessoa ORDER BY pes.nome;"
    )
    res = run_query(
        "SELECT pr.id_papel, pes.nome FROM papel_residente pr "
        "JOIN papel_profissional ppr ON pr.id_papel = ppr.id_papel "
        "JOIN pessoa pes ON ppr.id_profissional = pes.id_pessoa ORDER BY pes.nome;"
    )
    pre = run_query(
        "SELECT pp.id_papel, pes.nome FROM papel_preceptor pp "
        "JOIN papel_profissional ppp ON pp.id_papel = ppp.id_papel "
        "JOIN pessoa pes ON ppp.id_profissional = pes.id_pessoa ORDER BY pes.nome;"
    )
    proc = run_query("SELECT codigo, nome FROM procedimento ORDER BY codigo;")
    return pac, res, pre, proc


# ---------------------------------------------------------------------------
# TAB 6: SPs, TRIGGERS & VIEWS  (Etapa 2)
# ---------------------------------------------------------------------------
with tabs[5]:
    st.subheader("🗄️ Stored Procedures, Triggers & Views — Etapa 2")

    # ── SP 1: sp_registrar_atendimento_completo ──────────────────────────────
    st.markdown("### SP 1 — `sp_registrar_atendimento_completo`")
    st.caption(
        "Insere atendimento + procedimentos em uma única transação PL/pgSQL. "
        "Qualquer falha reverte tudo (ROLLBACK implícito)."
    )
    try:
        pac_opts, res_opts, pre_opts, proc_opts = _load_lookup_opts()

        with st.form("form_sp_atendimento"):
            c1, c2, c3 = st.columns(3)
            sp_pac = c1.selectbox(
                "Paciente", pac_opts["id_pessoa"],
                format_func=lambda i: pac_opts.set_index("id_pessoa").loc[i, "nome"])
            sp_res = c2.selectbox(
                "Residente", res_opts["id_papel"],
                format_func=lambda i: res_opts.set_index("id_papel").loc[i, "nome"])
            sp_pre = c3.selectbox(
                "Preceptor", pre_opts["id_papel"],
                format_func=lambda i: pre_opts.set_index("id_papel").loc[i, "nome"])
            c4, c5 = st.columns(2)
            sp_dh  = c4.text_input("Data/Hora (YYYY-MM-DD HH:MM)", "2024-03-01 10:00")
            sp_dur = c5.number_input("Duração (min)", min_value=1, value=30)
            sp_procs = st.multiselect(
                "Procedimentos realizados",
                proc_opts["codigo"].tolist(),
                format_func=lambda c: proc_opts.set_index("codigo").loc[c, "nome"])
            sp_obs = st.text_input("Observação", "")
            sp_btn = st.form_submit_button("▶ Executar SP (Transação)")

        if sp_btn:
            if not sp_procs:
                st.warning("Selecione ao menos um procedimento.")
            else:
                procs_json = json.dumps([
                    {"codigo": c, "quantidade": 1, "tempo_real": 20, "observacao": sp_obs}
                    for c in sp_procs
                ])
                sql_sp = """
                    CALL sp_registrar_atendimento_completo(
                        %(dh)s::timestamp, %(dur)s, %(pac)s, %(res)s, %(pre)s,
                        %(procs)s::jsonb
                    );
                """
                try:
                    run_command(sql_sp, {
                        "dh": sp_dh, "dur": sp_dur, "pac": int(sp_pac),
                        "res": int(sp_res), "pre": int(sp_pre), "procs": procs_json
                    })
                    st.success("✅ SP executada com sucesso! Atendimento + procedimentos inseridos.")
                except Exception as ex:
                    st.error(f"❌ Rollback — {ex}")
    except Exception as e:
        st.error(f"Erro ao carregar opções: {e}")

    st.divider()

    # ── SP 2: sp_calcular_tempo_medio_espera ─────────────────────────────────
    st.markdown("### SP 2 — `sp_calcular_tempo_medio_espera`")
    st.caption("Calcula o tempo médio de espera por unidade (chegada → início do procedimento).")
    if st.button("▶ Chamar sp_calcular_tempo_medio_espera", key="btn_sp2"):
        try:
            df_esp = run_query("SELECT * FROM sp_calcular_tempo_medio_espera();")
            st.dataframe(df_esp, hide_index=True, use_container_width=True)
        except Exception as e:
            st.error(f"Erro: {e}")

    st.divider()

    # ── SP 3: sp_reajustar_escala ─────────────────────────────────────────────
    st.markdown("### SP 3 — `sp_reajustar_escala`")
    st.caption(
        "Move todas as escalas de um residente de um dia/turno para outro. "
        "A trigger `trg_check_sobreposicao_escala` impede conflitos."
    )
    try:
        _, res_opts2, _, _ = _load_lookup_opts()
        with st.form("form_sp_reajustar"):
            c1, c2, c3 = st.columns(3)
            rj_res = c1.selectbox(
                "Residente", res_opts2["id_papel"],
                format_func=lambda i: res_opts2.set_index("id_papel").loc[i, "nome"],
                key="rj_res")
            dias, turnos = _DIAS, _TURNOS
            rj_dia_ant = c2.selectbox("Dia origem",   dias,   key="rj_dia_ant")
            rj_trn_ant = c3.selectbox("Turno origem", turnos, key="rj_trn_ant")
            c4, c5 = st.columns(2)
            rj_dia_nov = c4.selectbox("Dia destino",   dias,   key="rj_dia_nov")
            rj_trn_nov = c5.selectbox("Turno destino", turnos, key="rj_trn_nov")
            rj_btn = st.form_submit_button("▶ Executar sp_reajustar_escala")

        if rj_btn:
            try:
                run_command(
                    "CALL sp_reajustar_escala(%(res)s, %(da)s, %(ta)s, %(dn)s, %(tn)s);",
                    {"res": int(rj_res), "da": rj_dia_ant, "ta": rj_trn_ant,
                     "dn": rj_dia_nov,  "tn": rj_trn_nov}
                )
                st.success("✅ Escala reajustada com sucesso!")
            except Exception as ex:
                st.error(f"❌ Conflito detectado — {ex}")
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()

    # ── TRIGGER: trg_audita_atendimento ──────────────────────────────────────
    st.markdown("### Trigger — `trg_audita_atendimento`")
    st.caption("Registros criados automaticamente após INSERT/UPDATE/DELETE em ATENDIMENTO.")
    try:
        df_audit = run_query(
            "SELECT id_auditoria, id_atendimento, operacao, usuario, data_hora, "
            "dados_antigos::text, dados_novos::text "
            "FROM auditoria_atendimento ORDER BY id_auditoria DESC LIMIT 50;"
        )
        if df_audit.empty:
            st.info("Nenhum registro de auditoria ainda. Insira ou edite um atendimento.")
        else:
            st.dataframe(df_audit, hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()

    # ── TRIGGER: trg_atualiza_media_procedimentos ────────────────────────────
    st.markdown("### Trigger — `trg_atualiza_media_procedimentos`")
    st.caption(
        "Coluna `media_tempo_procedimento` atualizada automaticamente "
        "após cada INSERT em PROCEDIMENTO_REALIZADO."
    )
    try:
        df_med = run_query(
            "SELECT codigo, nome, tempo_medio_minutos, nivel_risco, "
            "media_tempo_procedimento FROM procedimento ORDER BY codigo;"
        )
        st.dataframe(df_med, hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro: {e}")

    st.divider()

    # ── VIEWS ─────────────────────────────────────────────────────────────────
    st.markdown("### Views")
    view_choice = st.radio(
        "Selecione a view:",
        ["vw_pacientes_internados",
         "vw_residentes_sem_supervisor",
         "vw_estatisticas_atendimentos_mensal"],
        horizontal=True, key="view_radio"
    )
    try:
        df_view = run_query(f"SELECT * FROM {view_choice};")
        st.dataframe(df_view, hide_index=True, use_container_width=True)
    except Exception as e:
        st.error(f"Erro ao consultar view: {e}")


# ---------------------------------------------------------------------------
# TAB 7: ORM & CONSULTAS AVANÇADAS  (Etapa 2)
# ---------------------------------------------------------------------------
with tabs[6]:
    st.subheader("🔗 ORM SQLAlchemy — Mapeamento e Consultas Avançadas")
    st.caption(
        "Todas as consultas abaixo usam exclusivamente a DSL do SQLAlchemy "
        "(sem SQL cru). Demonstra eager/lazy loading, sessões e filtros ORM."
    )

    try:
        session = _get_orm_session()

        orm_choice = st.radio(
            "Consulta:",
            ["1. Preceptores de residentes que atenderam pacientes flamenguistas",
             "2. Último atendimento de cada paciente (residente, preceptor, procedimentos)",
             "3. Percentual de procedimentos de alto risco por residente"],
            key="orm_radio"
        )

        if orm_choice.startswith("1."):
            # Duas referências à tabela pessoa: usa alias explícito via subquery ORM
            from sqlalchemy.orm import aliased
            PessoaPac = aliased(_Pessoa, name="pes_pac")
            PessoaPre = aliased(_Pessoa, name="pes_pre")

            rows = (
                session.query(
                    PessoaPre.nome.label("preceptor"),
                    _Profissional.crm.label("crm"),
                    _PapelPreceptor.titulacao
                )
                .select_from(_Atendimento)
                .join(PessoaPac,        _Atendimento.id_paciente == PessoaPac.id_pessoa)
                .filter(PessoaPac.is_flamengo == True)   # noqa: E712
                .join(_PapelPreceptor,  _Atendimento.id_papel_preceptor == _PapelPreceptor.id_papel)
                .join(_PapelProfissional, _PapelPreceptor.id_papel == _PapelProfissional.id_papel)
                .join(_Profissional,    _PapelProfissional.id_profissional == _Profissional.id_pessoa)
                .join(PessoaPre,        _Profissional.id_pessoa == PessoaPre.id_pessoa)
                .distinct()
                .all()
            )
            st.dataframe(
                [{"preceptor": r.preceptor, "crm": r.crm, "titulacao": r.titulacao} for r in rows],
                hide_index=True, use_container_width=True
            )

        elif orm_choice.startswith("2."):
            # Eager loading: selectinload + joinedload em cadeia
            pacientes_orm = (
                session.query(_Paciente)
                .options(
                    joinedload(_Paciente.pessoa),
                    selectinload(_Paciente.atendimentos).options(
                        joinedload(_Atendimento.residente)
                            .joinedload(_PapelResidente.papel_prof)
                            .joinedload(_PapelProfissional.profissional)
                            .joinedload(_Profissional.pessoa),
                        joinedload(_Atendimento.preceptor)
                            .joinedload(_PapelPreceptor.papel_prof)
                            .joinedload(_PapelProfissional.profissional)
                            .joinedload(_Profissional.pessoa),
                        selectinload(_Atendimento.realizados)
                            .joinedload(_ProcedimentoRealizado.procedimento)
                    )
                )
                .all()
            )
            resultado = []
            for pac in pacientes_orm:
                if not pac.atendimentos:
                    continue
                ult = max(pac.atendimentos, key=lambda a: a.data_hora)
                procs = ", ".join(r.procedimento.nome for r in ult.realizados) or "Nenhum"
                resultado.append({
                    "paciente":       pac.pessoa.nome,
                    "data_hora":      ult.data_hora,
                    "residente":      ult.residente.papel_prof.profissional.pessoa.nome,
                    "preceptor":      ult.preceptor.papel_prof.profissional.pessoa.nome,
                    "procedimentos":  procs,
                })
            st.dataframe(resultado, hide_index=True, use_container_width=True)

        elif orm_choice.startswith("3."):
            # Agregação via func.count + case() — DSL pura, sem SQL literal
            alto_risco_expr = func.count(
                case((_Procedimento.nivel_risco == 'ALTO', 1))
            ).label("procs_alto_risco")
            total_expr = func.count(
                _ProcedimentoRealizado.codigo_procedimento
            ).label("total_procedimentos")

            rows = (
                session.query(
                    _Pessoa.nome.label("residente"),
                    total_expr,
                    alto_risco_expr,
                )
                .select_from(_PapelResidente)
                .join(_PapelProfissional, _PapelResidente.id_papel == _PapelProfissional.id_papel)
                .join(_Profissional,      _PapelProfissional.id_profissional == _Profissional.id_pessoa)
                .join(_Pessoa,            _Profissional.id_pessoa == _Pessoa.id_pessoa)
                .outerjoin(_Atendimento,
                           _PapelResidente.id_papel == _Atendimento.id_papel_residente)
                .outerjoin(_ProcedimentoRealizado,
                           _Atendimento.id_atendimento == _ProcedimentoRealizado.id_atendimento)
                .outerjoin(_Procedimento,
                           _ProcedimentoRealizado.codigo_procedimento == _Procedimento.codigo)
                .group_by(_Pessoa.id_pessoa, _Pessoa.nome)
                .all()
            )
            dados = []
            for r in rows:
                total = r.total_procedimentos or 0
                alto  = r.procs_alto_risco or 0
                pct   = round(alto / total * 100, 2) if total > 0 else 0.0
                dados.append({
                    "residente":            r.residente,
                    "total_procedimentos":  total,
                    "procs_alto_risco":     alto,
                    "pct_alto_risco":       pct,
                })
            df_pct = pd.DataFrame(dados).sort_values("pct_alto_risco", ascending=False)
            c1, c2 = st.columns([2, 1])
            c1.dataframe(df_pct, hide_index=True, use_container_width=True)
            if not df_pct.empty:
                c2.bar_chart(df_pct.set_index("residente")["pct_alto_risco"])

    except Exception as e:
        st.error(f"Erro na consulta ORM: {e}")
    finally:
        try:
            session.close()
        except Exception:
            pass


# ---------------------------------------------------------------------------
# TAB 8: CONCORRÊNCIA & TRANSAÇÕES  (Etapa 2)
# ---------------------------------------------------------------------------
with tabs[7]:
    st.subheader("⚡ Concorrência & Transações")
    st.markdown("""
    Simula duas transações concorrentes tentando modificar a tabela `ESCALA_PLANTAO`
    ao mesmo tempo.

    * **Bloqueio pessimista** (`SELECT ... FOR UPDATE NOWAIT`): a segunda thread
      falha imediatamente ao tentar bloquear um registro já bloqueado.
    * **Restrição estrutural** (Trigger + UNIQUE): o PostgreSQL rejeita o segundo
      INSERT via trigger, garantindo consistência sem lock explícito.
    """)

    modo_lock = st.radio(
        "Mecanismo de controle:",
        ["Bloqueio Pessimista (FOR UPDATE NOWAIT)",
         "Trigger + UNIQUE constraint"],
        horizontal=True, key="lock_mode"
    )

    _lock_logs: list = []

    def _log(msg: str) -> None:
        import datetime as _dt
        _lock_logs.append(f"[{_dt.datetime.now().strftime('%H:%M:%S.%f')[:-3]}] {msg}")

    def _tx_pessimistic(name: str, escala_id: int, novo_turno: str, hold_secs: float) -> None:
        """Tenta adquirir FOR UPDATE NOWAIT e alterar o turno da escala."""
        sess = _get_orm_session()
        try:
            _log(f"{name}: tentando adquirir lock na escala #{escala_id}...")
            esc = (
                sess.query(_EscalaPlantao)
                .filter(_EscalaPlantao.id_escala == escala_id)
                .with_for_update(nowait=True)
                .one_or_none()
            )
            if esc is None:
                _log(f"{name}: escala #{escala_id} não encontrada.")
                return
            _log(f"{name}: 🔒 lock adquirido (turno atual = '{esc.turno}'). Aguardando {hold_secs}s...")
            time.sleep(hold_secs)
            esc.turno = novo_turno
            sess.commit()
            _log(f"{name}: ✅ COMMIT — turno alterado para '{novo_turno}'.")
        except Exception as ex:
            sess.rollback()
            _log(f"{name}: ❌ BLOQUEADO / ERRO: {ex}")
        finally:
            sess.close()

    def _tx_conflict_insert(name: str, res_id: int, unidade_id: int,
                            dia: str, turno: str, pre_id: int) -> None:
        """Tenta inserir escala que conflita com outra já existente."""
        sess = _get_orm_session()
        try:
            _log(f"{name}: tentando inserir escala "
                 f"(residente={res_id}, unidade={unidade_id}, {dia}/{turno})...")
            nova = _EscalaPlantao(
                id_unidade=unidade_id,
                dia_semana=dia,
                turno=turno,
                id_papel_residente=res_id,
                id_papel_preceptor=pre_id,
            )
            sess.add(nova)
            time.sleep(0.3)
            sess.commit()
            _log(f"{name}: ✅ INSERT realizado com sucesso.")
        except Exception as ex:
            sess.rollback()
            _log(f"{name}: 🛑 REJEITADO (trigger/constraint): {ex}")
        finally:
            sess.close()

    if st.button("🔥 Executar simulação concorrente", key="btn_concorrencia"):
        _lock_logs.clear()
        _log("Iniciando simulação...")

        if modo_lock.startswith("Bloqueio Pessimista"):
            t1 = threading.Thread(target=_tx_pessimistic, args=("Thread-A", 1, "noite", 2.0))
            t2 = threading.Thread(target=_tx_pessimistic, args=("Thread-B", 1, "tarde", 0.0))
            t1.start()
            time.sleep(0.15)  # garante que A adquira o lock primeiro
            t2.start()
            t1.join(); t2.join()
        else:
            # Thread-A insere residente 6 na unidade 2 (segunda/manhã),
            # Thread-B tenta o mesmo residente numa unidade diferente — trigger rejeita.
            t1 = threading.Thread(
                target=_tx_conflict_insert, args=("Thread-A", 6, 2, "segunda", "manhã", 1))
            t2 = threading.Thread(
                target=_tx_conflict_insert, args=("Thread-B", 6, 3, "segunda", "manhã", 1))
            t1.start(); t2.start()
            t1.join(); t2.join()

        _log("Simulação concluída.")
        st.subheader("📜 Log da execução")
        for line in _lock_logs:
            if "✅" in line:
                st.success(line)
            elif "❌" in line or "🛑" in line:
                st.error(line)
            elif "🔒" in line:
                st.warning(line)
            else:
                st.info(line)
