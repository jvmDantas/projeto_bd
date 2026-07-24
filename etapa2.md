1. Stored Procedures (1,5 ponto)

- sp_registrar_atendimento_completo: recebe dados do atendimento + lista de procedimentos realizados (como JSON ou tabela temporária) e insere tudo dentro de uma transação (se qualquer procedimento falhar, tudo é revertido).
- sp_calcular_tempo_medio_espera: calcula, para cada unidade, o tempo médio entre a chegada do paciente (data_hora do atendimento) e o início do primeiro procedimento.
- sp_reajustar_escala: recebe um id_residente, muda todas as suas escalas de um dia/turno para outro, desde que não gere conflito (mesmo unidade+dia+turno+residente).

2. Triggers (1,5 ponto)

- trg_check_sobreposicao_escala: BEFORE INSERT/UPDATE na tabela ESCALA. Impede que um mesmo residente seja escalado no mesmo dia/turno em duas unidades diferentes.
- trg_audita_atendimento: AFTER INSERT/UPDATE/DELETE em ATENDIMENTO. Registra em uma tabela AUDITORIA_ATENDIMENTO (id_auditoria, id_atendimento, operacao, usuario, data_hora, dados_antigos (JSON), dados_novos (JSON)).
- trg_atualiza_media_procedimentos: AFTER INSERT em PROCEDIMENTO_REALIZADO. Atualiza uma coluna media_tempo_procedimento na tabela PROCEDIMENTO (média do tempo_real_minutos daquele procedimento em todos os atendimentos).

3. Views (1,0 ponto)

- vw_pacientes_internados: pacientes que estão atualmente internados (data_hora_saida IS NULL na internação mais recente).
- vw_residentes_sem_supervisor: residentes que estão escalados em algum plantão, mas cujo preceptor não tem titulação de doutor (ou não possui supervisão ativa).
- vw_estatisticas_atendimentos_mensal: agregação por mês e por unidade: total de atendimentos, média de duração, procedimentos mais comuns.

4. ORM (2,0 pontos)

- Reimplementar todas as operações da Etapa 1 usando uma ORM à escolha:
  - Python: SQLAlchemy (recomendado) ou Django ORM
  - Node.js: Prisma ou TypeORM
  - Java: Hibernate
  - C#: Entity Framework Core
- Demonstrar:
  - Mapeamento objeto-relacional (classes/entidades)
  - Uso de sessões/transações via ORM
  - Consultas usando a DSL/filter da ORM (não SQL cru)
  - Relacionamentos (lazy loading vs eager loading)

5. Consultas avançadas com ORM (1,0 ponto)

- Usando a ORM, implemente:
  - Listar todos os preceptores que supervisionaram residentes que atenderam pacientes que são flamenguistas (is_flamengo = TRUE).
  - Para cada paciente, exibir seu último atendimento (data_hora, residente, preceptor, lista de procedimentos).
  - Calcular o percentual de procedimentos de alto risco realizados por cada residente.

6. Tratamento de concorrência e transações (1,0 ponto)

- Implementar um cenário simulado de duas transações concorrentes tentando escalar o mesmo residente para o mesmo dia/turno/unidade.
- Usar mecanismos da ORM/BD para evitar inconsistência (lock otimista ou pessimista).
- Demonstrar com código e logs.

7. Entrega Final (1 ponto extra)

- Repositório GitHub com commits separados por Etapa 1 e Etapa 2.
- Vídeo de até 8 minutos demonstrando as novas funcionalidades da Etapa 2.
- Relatório breve (2 páginas) explicando as decisões de implementação, especialmente sobre triggers vs procedures e escolha da ORM.
