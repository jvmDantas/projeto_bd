# Relatório Técnico: Sistema de Gestão Hospitalar (Etapa 1 & 2)

**Disciplina:** Banco de Dados  
**Docente:** Profº Marcelo Iury
**Discentes:** João Victor Martins e Luís Henrique Aranha Magalhães  
**SGBD Utilizado:** PostgreSQL 14+ | **Linguagem & Framework:** Python 3.12, SQLAlchemy 2.0, Streamlit  

---

## 1. Introdução e Arquitetura do Sistema

A arquitetura foi estruturada em camadas bem definidas:
- **Camada de Dados (PostgreSQL):** Responsável pela persistência, integridade referencial, triggers de validação/auditoria e procedures para processamento atômico em lote.
- **Camada ORM (SQLAlchemy 2.0):** Atua no mapeamento das entidades relacionais para objetos Python, gerenciando sessões e pools de conexões.
- **Camada de Interface (Streamlit):** Oferece um painel interativo para execução de operações CRUD, chamadas de rotinas internas do banco e visualização gráfica de relatórios.

---

## 2. Modelagem Relacional e Mapeamento ORM

O modelo relacional suporta a hierarquia entre pessoas, profissionais (divididos nos papéis de *Residente* e *Preceptor*) e pacientes, além de gerenciar atendimentos, escalas de plantão, procedimentos e internações.

### 2.1 Principais Entidades Mapeadas

- **PESSOA / PACIENTE / PROFISSIONAL:** Herança por tabela genérica `PESSOA` especializada via chave primária/estrangeira de relação 1:1 com `PACIENTE` e `PROFISSIONAL`.
- **PAPEL_PROFISSIONAL (`PAPEL_RESIDENTE` / `PAPEL_PRECEPTOR`):** Especialização de papéis exercidos por profissionais médicos no ambiente acadêmico-hospitalar.
- **ATENDIMENTO & PROCEDIMENTO_REALIZADO:** Entidades associativas para registro de consultas e procedimentos aplicados, com controle de tempo real e flags de faturamento.
- **INTERNACAO & AUDITORIA_ATENDIMENTO:** Tabelas introduzidas na Etapa 2 para controle de leitos ativos e histórico de auditoria mutável.

### 2.2 Estratégias de Carregamento (Loading Strategies)

Para otimizar o desempenho do ORM e mitigar o problema de consultas *N+1*:
- **Eager Loading via `joinedload`:** Utilizado nos relacionamentos diretos de chave estrangeira (ex.: `Atendimento -> Paciente -> Pessoa`), realizando `LEFT OUTER JOIN` em uma única instrução SQL.
- **Eager Loading via `selectinload`:** Utilizado para coleções 1:N e N:M (ex.: `Paciente -> Atendimentos -> ProcedimentosRealizados`), executando a busca de relacionamentos em lote secundário via operador `IN`.

---

## 3. Programação no Banco de Dados: Stored Procedures e Triggers

As regras cruciais de integridade e processamento atômico foram delegadas diretamente ao PostgreSQL via funções e procedimentos em **PL/pgSQL**.

### 3.1 Stored Procedures e Funções

1. **`sp_registrar_atendimento_completo`**
   - **Objetivo:** Inserir um novo atendimento e sua lista de procedimentos em um único comando atômico.
   - **Funcionamento:** Recebe os parâmetros básicos e uma lista em formato `JSONB`. Caso ocorra qualquer falha de validação ou chave inexistente durante a iteração do JSON, toda a operação sofre *rollback* automático.

2. **`sp_calcular_tempo_medio_espera`**
   - **Objetivo:** Retornar o tempo médio de espera por unidade hospitalar.
   - **Funcionamento:** Função do tipo `RETURNS TABLE` que calcula o intervalo em minutos entre a chegada do paciente e o atendimento efetivo por unidade.

3. **`sp_reajustar_escala`**
   - **Objetivo:** Reorganizar em lote as escalas de um residente entre dias da semana e turnos.
   - **Funcionamento:** Altera os registros correspondentes ao residente e slot de origem para o novo slot de destino, delegando à trigger de sobreposição a validação de conflitos.

### 3.2 Triggers (Gatilhos)

1. **`trg_check_sobreposicao_escala` (`BEFORE INSERT OR UPDATE ON ESCALA_PLANTAO`):**  
   Impede que o mesmo residente seja alocado no mesmo dia e turno em duas unidades hospitalares distintas, lançando uma exceção antes da gravação do registro.

2. **`trg_audita_atendimento` (`AFTER INSERT OR UPDATE OR DELETE ON ATENDIMENTO`):**  
   Insere automaticamente um registro na tabela `AUDITORIA_ATENDIMENTO`, registrando o usuário do banco, a data/hora exata, a operação realizada e os coletores JSON com o estado anterior (`OLD`) e posterior (`NEW`) da linha.

3. **`trg_atualiza_media_procedimentos` (`AFTER INSERT ON PROCEDIMENTO_REALIZADO`):**  
   Recalcula a média de duração real de um procedimento específico sempre que uma nova execução é inserida, atualizando a coluna denormalizada `media_tempo_procedimento` na tabela `PROCEDIMENTO`.

---

## 4. Visões de Dados (Views)

As views consolidadas abstraem queries complexas do consumo da aplicação:

1. **`vw_pacientes_internados`:** Lista pacientes com internação ativa, filtrando registros sem data de saída (`data_hora_saida IS NULL`) referentes à entrada mais recente.
2. **`vw_residentes_sem_supervisor`:** Identifica plantões nos quais o preceptor responsável não possui titulação de 'Doutor' ou teve seu vínculo encerrado.
3. **`vw_estatisticas_atendimentos_mensal`:** Consolida mensalmente o volume de atendimentos, a duração média e o procedimento mais realizado por meio de CTEs e funções de janela (`ROW_NUMBER()`).

---

## 5. Concorrência e Transações

Para demonstrar a resolução de conflitos em ambientes concorrentes, a aplicação simula execuções simultâneas via *multi-threading*:

- **Bloqueio Pessimista (`SELECT ... FOR UPDATE NOWAIT`):** Na alteração concorrente de plantões, a primeira transação adquire o bloqueio da linha. A segunda transação falha imediatamente ao tentar acessar o recurso bloqueado com `nowait=True`, prevenindo travamentos indesejados (*deadlocks*).
- **Validação Estrutural:** Combinação de restrições de unicidade (`UNIQUE (id_unidade, dia_semana, turno, id_papel_residente)`) com gatilhos de validação para impedir estados inconsistentes do banco durante *inserts* simultâneos.

---

## 6. Verificação e Validação

O sistema foi validado por meio dos seguintes cenários:
1. **Testes de Integridade:** Validação do *rollback* ao tentar registrar procedimentos inválidos na procedure atômica.
2. **Testes de Gatilho:** Confirmação da geração automática de registros de auditoria em inserções e remoções de atendimentos.
3. **Testes de Concorrência:** Simulação de acesso simultâneo na aba dedicada do Streamlit, registrando a resposta de bloqueio em tempo real.

---

## 7. Conclusão

A solução desenvolvida integra técnicas avançadas de modelagem relacional, procedimentos armazenados e consumo moderno via ORM. A transferência de regras críticas de integridade para a camada de banco de dados garantiu a consistência dos dados independentemente da forma de acesso, enquanto a interface em Streamlit viabilizou a validação prática dos requisitos.
