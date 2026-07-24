# Etapa 2 — Decisões técnicas

Este é o documento único e cumulativo das decisões técnicas da Etapa 2. Cada
novo ponto deve acrescentar somente suas decisões relevantes, sem repetir a
documentação detalhada mantida na respectiva pasta `pontoN/`.

## Ponto 1 — Stored Procedures

- **Scripts incrementais:** a Etapa 1 permanece em
  `hospital_system_v2.sql`; as mudanças são aplicadas por arquivos numerados em
  `sql/etapa2/`, preservando o estado anterior e a ordem de execução.
- **Alteração mínima do modelo:** foram adicionados somente
  `ATENDIMENTO.id_unidade` e
  `PROCEDIMENTO_REALIZADO.data_hora_inicio`, pois ambos são indispensáveis ao
  cálculo do tempo de espera. O preenchimento dos dados existentes é explícito
  e ocorre antes de `NOT NULL`.
- **Lista em JSONB:** permite registrar vários procedimentos em uma chamada e
  simplifica a futura integração com Python/SQLAlchemy. Códigos repetidos são
  rejeitados porque a multiplicidade já é representada por `quantidade`.
- **Identificador do residente:** corresponde a
  `PAPEL_RESIDENTE.id_papel`, seguindo as FKs existentes.
- **Transação externa:** as procedures não executam `COMMIT` ou `ROLLBACK`;
  erros são propagados para garantir atomicidade e compatibilidade futura com a
  ORM.
- **Resultado com `REFCURSOR`:** mantém a média de espera em formato tabular e
  inclui unidades sem atendimentos elegíveis.
- **Lock do residente:** `sp_reajustar_escala` bloqueia o papel do residente
  antes de verificar conflitos, serializando reajustes para o mesmo residente.
- **Testes transacionais:** os fixtures são verificados por asserções SQL e
  descartados com `ROLLBACK`.
