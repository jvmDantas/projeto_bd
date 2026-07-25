"""
services/orm_service.py — Serviços para consultas avançadas usando a DSL do SQLAlchemy ORM (Etapa 2)
"""

import pandas as pd
from sqlalchemy import func, case
from sqlalchemy.orm import joinedload, selectinload, aliased
from database.connection import get_orm_session
from database.models import (
    Pessoa, Paciente, Profissional, PapelProfissional, PapelResidente,
    PapelPreceptor, Atendimento, ProcedimentoRealizado, Procedimento
)


def get_preceptores_flamenguistas_orm():
    """Consulta ORM 1: Preceptores de residentes que atenderam pacientes flamenguistas."""
    session = get_orm_session()
    try:
        PessoaPac = aliased(Pessoa, name="pes_pac")
        PessoaPre = aliased(Pessoa, name="pes_pre")

        rows = (
            session.query(
                PessoaPre.nome.label("preceptor"),
                Profissional.crm.label("crm"),
                PapelPreceptor.titulacao
            )
            .select_from(Atendimento)
            .join(PessoaPac,        Atendimento.id_paciente == PessoaPac.id_pessoa)
            .filter(PessoaPac.is_flamengo == True)   # noqa: E712
            .join(PapelPreceptor,   Atendimento.id_papel_preceptor == PapelPreceptor.id_papel)
            .join(PapelProfissional, PapelPreceptor.id_papel == PapelProfissional.id_papel)
            .join(Profissional,     PapelProfissional.id_profissional == Profissional.id_pessoa)
            .join(PessoaPre,         Profissional.id_pessoa == PessoaPre.id_pessoa)
            .distinct()
            .all()
        )
        return [{"preceptor": r.preceptor, "crm": r.crm, "titulacao": r.titulacao} for r in rows]
    finally:
        session.close()


def get_ultimo_atendimento_pacientes_orm():
    """Consulta ORM 2: Último atendimento de cada paciente com Eager Loading em cadeia."""
    session = get_orm_session()
    try:
        pacientes_orm = (
            session.query(Paciente)
            .options(
                joinedload(Paciente.pessoa),
                selectinload(Paciente.atendimentos).options(
                    joinedload(Atendimento.residente)
                        .joinedload(PapelResidente.papel_prof)
                        .joinedload(PapelProfissional.profissional)
                        .joinedload(Profissional.pessoa),
                    joinedload(Atendimento.preceptor)
                        .joinedload(PapelPreceptor.papel_prof)
                        .joinedload(PapelProfissional.profissional)
                        .joinedload(Profissional.pessoa),
                    selectinload(Atendimento.realizados)
                        .joinedload(ProcedimentoRealizado.procedimento)
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
        return resultado
    finally:
        session.close()


def get_pct_alto_risco_residentes_orm():
    """Consulta ORM 3: Percentual de procedimentos de alto risco agregados via func.count + case()."""
    session = get_orm_session()
    try:
        alto_risco_expr = func.count(
            case((Procedimento.nivel_risco == 'ALTO', 1))
        ).label("procs_alto_risco")
        total_expr = func.count(
            ProcedimentoRealizado.codigo_procedimento
        ).label("total_procedimentos")

        rows = (
            session.query(
                Pessoa.nome.label("residente"),
                total_expr,
                alto_risco_expr,
            )
            .select_from(PapelResidente)
            .join(PapelProfissional, PapelResidente.id_papel == PapelProfissional.id_papel)
            .join(Profissional,      PapelProfissional.id_profissional == Profissional.id_pessoa)
            .join(Pessoa,            Profissional.id_pessoa == Pessoa.id_pessoa)
            .outerjoin(Atendimento,
                       PapelResidente.id_papel == Atendimento.id_papel_residente)
            .outerjoin(ProcedimentoRealizado,
                       Atendimento.id_atendimento == ProcedimentoRealizado.id_atendimento)
            .outerjoin(Procedimento,
                       ProcedimentoRealizado.codigo_procedimento == Procedimento.codigo)
            .group_by(Pessoa.id_pessoa, Pessoa.nome)
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
        return pd.DataFrame(dados).sort_values("pct_alto_risco", ascending=False)
    finally:
        session.close()
