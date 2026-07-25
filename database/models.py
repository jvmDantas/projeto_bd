"""
database/models.py — Mapeamento Objeto-Relacional (ORM SQLAlchemy)
"""

from sqlalchemy import (
    Column, Integer, String, Boolean, Date, DateTime, Numeric, Text, ForeignKey
)
from sqlalchemy.orm import declarative_base, relationship

Base = declarative_base()


class Pessoa(Base):
    __tablename__ = 'pessoa'
    id_pessoa       = Column(Integer, primary_key=True)
    nome            = Column(String(150), nullable=False)
    cpf             = Column(String(11),  nullable=False, unique=True)
    data_nascimento = Column(Date,        nullable=False)
    is_flamengo     = Column(Boolean,     default=False)
    telefone        = Column(String(11))
    paciente        = relationship('Paciente',     back_populates='pessoa',       uselist=False)
    profissional    = relationship('Profissional', back_populates='pessoa',       uselist=False)


class Paciente(Base):
    __tablename__ = 'paciente'
    id_pessoa    = Column(Integer, ForeignKey('pessoa.id_pessoa'), primary_key=True)
    num_convenio = Column(String(20))
    alergias     = Column(Text)
    grupo_sanguineo = Column(String(3))
    endereco     = Column(String(200))
    pessoa       = relationship('Pessoa',      back_populates='paciente')
    atendimentos = relationship('Atendimento', back_populates='paciente')


class Profissional(Base):
    __tablename__ = 'profissional'
    id_pessoa     = Column(Integer, ForeignKey('pessoa.id_pessoa'), primary_key=True)
    crm           = Column(String(20), nullable=False, unique=True)
    data_admissao = Column(Date,       nullable=False)
    especialidade = Column(String(100))
    pessoa        = relationship('Pessoa',           back_populates='profissional')
    papeis        = relationship('PapelProfissional', back_populates='profissional')


class PapelProfissional(Base):
    __tablename__   = 'papel_profissional'
    id_papel        = Column(Integer, primary_key=True)
    id_profissional = Column(Integer, ForeignKey('profissional.id_pessoa'), nullable=False)
    tipo_papel      = Column(String(20), nullable=False)
    data_inicio     = Column(Date,       nullable=False)
    data_fim        = Column(Date)
    profissional    = relationship('Profissional',    back_populates='papeis')
    residente       = relationship('PapelResidente',  back_populates='papel_prof', uselist=False)
    preceptor       = relationship('PapelPreceptor',  back_populates='papel_prof', uselist=False)


class PapelResidente(Base):
    __tablename__  = 'papel_residente'
    id_papel       = Column(Integer, ForeignKey('papel_profissional.id_papel'), primary_key=True)
    ano_residencia = Column(String(2), nullable=False)
    papel_prof     = relationship('PapelProfissional', back_populates='residente')
    atendimentos   = relationship('Atendimento',       back_populates='residente')
    escalas        = relationship('EscalaPlantao',     back_populates='residente')


class PapelPreceptor(Base):
    __tablename__ = 'papel_preceptor'
    id_papel      = Column(Integer, ForeignKey('papel_profissional.id_papel'), primary_key=True)
    titulacao     = Column(String(50))
    papel_prof    = relationship('PapelProfissional', back_populates='preceptor')
    atendimentos  = relationship('Atendimento',       back_populates='preceptor')
    escalas       = relationship('EscalaPlantao',     back_populates='preceptor')


class Unidade(Base):
    __tablename__     = 'unidade'
    id_unidade        = Column(Integer, primary_key=True)
    nome              = Column(String(100), nullable=False)
    tipo              = Column(String(30),  nullable=False)
    capacidade_leitos = Column(Integer)
    escalas           = relationship('EscalaPlantao', back_populates='unidade')


class Procedimento(Base):
    __tablename__            = 'procedimento'
    codigo                   = Column(Integer, primary_key=True)
    nome                     = Column(String(150), nullable=False)
    tempo_medio_minutos      = Column(Integer,     nullable=False)
    nivel_risco              = Column(String(10),  nullable=False)
    media_tempo_procedimento = Column(Numeric(10, 2), default=0.00)
    realizados               = relationship('ProcedimentoRealizado', back_populates='procedimento')


class Atendimento(Base):
    __tablename__      = 'atendimento'
    id_atendimento     = Column(Integer, primary_key=True)
    data_hora          = Column(DateTime, nullable=False)
    duracao_minutos    = Column(Integer,  nullable=False)
    id_paciente        = Column(Integer, ForeignKey('paciente.id_pessoa'),       nullable=False)
    id_papel_residente = Column(Integer, ForeignKey('papel_residente.id_papel'), nullable=False)
    id_papel_preceptor = Column(Integer, ForeignKey('papel_preceptor.id_papel'), nullable=False)
    paciente           = relationship('Paciente',       back_populates='atendimentos')
    residente          = relationship('PapelResidente', back_populates='atendimentos')
    preceptor          = relationship('PapelPreceptor', back_populates='atendimentos')
    realizados         = relationship('ProcedimentoRealizado', back_populates='atendimento',
                                      cascade='all, delete-orphan')


class ProcedimentoRealizado(Base):
    __tablename__             = 'procedimento_realizado'
    id_atendimento            = Column(Integer, ForeignKey('atendimento.id_atendimento'),  primary_key=True)
    codigo_procedimento       = Column(Integer, ForeignKey('procedimento.codigo'),          primary_key=True)
    quantidade                = Column(Integer, nullable=False)
    tempo_real_minutos        = Column(Integer, nullable=False)
    observacao_intercorrencia = Column(Text)
    flag_faturado             = Column(Boolean, default=False)
    atendimento               = relationship('Atendimento',    back_populates='realizados')
    procedimento              = relationship('Procedimento',   back_populates='realizados')


class EscalaPlantao(Base):
    __tablename__      = 'escala_plantao'
    id_escala          = Column(Integer, primary_key=True)
    id_unidade         = Column(Integer, ForeignKey('unidade.id_unidade'),          nullable=False)
    dia_semana         = Column(String(10), nullable=False)
    turno              = Column(String(10), nullable=False)
    id_papel_residente = Column(Integer, ForeignKey('papel_residente.id_papel'),    nullable=False)
    id_papel_preceptor = Column(Integer, ForeignKey('papel_preceptor.id_papel'),    nullable=False)
    unidade            = relationship('Unidade',        back_populates='escalas')
    residente          = relationship('PapelResidente', back_populates='escalas')
    preceptor          = relationship('PapelPreceptor', back_populates='escalas')


class AuditoriaAtendimento(Base):
    __tablename__  = 'auditoria_atendimento'
    id_auditoria   = Column(Integer, primary_key=True)
    id_atendimento = Column(Integer)
    operacao       = Column(String(10),  nullable=False)
    usuario        = Column(String(100), nullable=False)
    data_hora      = Column(DateTime)
    dados_antigos  = Column(Text)
    dados_novos    = Column(Text)
