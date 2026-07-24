# Planejamento de implementação — Etapa 2, Ponto 1: Stored Procedures

## 1. Objetivo desta implementação

Implementar no PostgreSQL as três stored procedures solicitadas:

1. `sp_registrar_atendimento_completo`;
2. `sp_calcular_tempo_medio_espera`;
3. `sp_reajustar_escala`.

A implementação deve:

- preservar o funcionamento da Etapa 1;
- manter o script original da Etapa 1 identificável no histórico;
- adicionar somente as alterações de esquema estritamente necessárias;
- garantir atomicidade das operações;
- fornecer testes SQL positivos e negativos;
- deixar a estrutura preparada para a futura integração com SQLAlchemy, sem migrar a aplicação para ORM neste momento.

O projeto atualmente inicializa todo o banco por meio de `hospital_system_v2.sql`, conforme documentado no README. A aplicação ainda executa SQL diretamente com `psycopg2`, portanto as procedures devem ser implementadas inicialmente no banco e demonstradas por scripts SQL, sem reestruturar o `app.py` nesta etapa.

---

# 2. Decisões técnicas adotadas no planejamento

## 2.1 Preservar o script da Etapa 1

Não concentrar todas as alterações diretamente em `hospital_system_v2.sql`.

Criar uma nova estrutura para a Etapa 2:

```text
sql/
└── etapa2/
    ├── 01_alteracoes_schema.sql
    ├── 02_stored_procedures.sql
    └── 03_testes_stored_procedures.sql
```

A ordem de execução deverá ser:

```text
1. hospital_system_v2.sql
2. sql/etapa2/01_alteracoes_schema.sql
3. sql/etapa2/02_stored_procedures.sql
4. sql/etapa2/03_testes_stored_procedures.sql
```

Isso permite:

- identificar claramente o estado final da Etapa 1;
- aplicar a Etapa 2 incrementalmente;
- testar cada grupo de alterações separadamente;
- manter commits organizados;
- futuramente adicionar arquivos separados para triggers, views e ORM.

## 2.2 Usar JSONB no registro de atendimento completo

A lista de procedimentos será recebida como um array JSONB.

Essa opção deve ser preferida à tabela temporária porque:

- permite enviar vários procedimentos em uma única chamada;
- não exige que aplicação e procedure compartilhem uma tabela temporária previamente criada;
- será mais simples de integrar ao Python e ao SQLAlchemy;
- facilita os testes de rollback;
- representa naturalmente uma lista de objetos.

## 2.3 Usar o papel do residente como identificador

No banco atual, `ATENDIMENTO` e `ESCALA_PLANTAO` não referenciam diretamente `PESSOA` ou `PROFISSIONAL`. Elas referenciam `PAPEL_RESIDENTE.id_papel`.

Assim, o parâmetro descrito pelo professor como `id_residente` deverá representar:

```text
PAPEL_RESIDENTE.id_papel
```

O nome interno recomendado é:

```text
p_id_papel_residente
```

A documentação pode explicar que esse é o identificador do residente em seu papel profissional.

## 2.4 Não executar `COMMIT` ou `ROLLBACK` dentro das procedures

As procedures devem participar da transação iniciada pelo chamador.

Elas não devem:

- confirmar parcialmente os dados;
- capturar um erro e ocultá-lo;
- executar `COMMIT` no meio da operação;
- deixar o atendimento persistido quando um procedimento falhar.

Quando ocorrer qualquer erro:

1. a procedure deve lançar ou propagar uma exceção;
2. a transação externa deve ficar inválida;
3. o chamador deve executar `ROLLBACK`;
4. todas as inserções feitas pela chamada devem ser revertidas.

Essa estratégia será compatível com a futura `Session` do SQLAlchemy.

---

# 3. Alterações de esquema necessárias

O esquema atual não possui duas informações indispensáveis para `sp_calcular_tempo_medio_espera`:

- a unidade onde o atendimento ocorreu;
- a data e hora de início de cada procedimento.

Atualmente, `ATENDIMENTO` possui paciente, residente, preceptor, data e duração, mas não possui `id_unidade`. `PROCEDIMENTO_REALIZADO` possui `tempo_real_minutos`, que representa duração, mas não possui um instante de início.

## 3.1 Alterar `ATENDIMENTO`

Adicionar:

```text
id_unidade
```

Características:

- tipo inteiro;
- chave estrangeira para `UNIDADE.id_unidade`;
- deverá ser obrigatório após o preenchimento dos dados existentes;
- utilizar `ON DELETE RESTRICT`, seguindo o padrão das outras relações assistenciais.

### Estratégia segura de migração

A alteração deve ocorrer em três passos:

1. adicionar a coluna inicialmente permitindo `NULL`;
2. preencher os atendimentos existentes com unidades válidas;
3. adicionar `NOT NULL`.

Não adicionar a coluna diretamente como obrigatória enquanto já existirem atendimentos, pois isso faria a alteração falhar.

### Preenchimento dos dados antigos

Atribuir unidades de maneira explícita e determinística aos atendimentos já existentes.

Não usar valores aleatórios.

O script deve documentar que os valores foram atribuídos como dados de demonstração da Etapa 2.

## 3.2 Alterar `PROCEDIMENTO_REALIZADO`

Adicionar:

```text
data_hora_inicio
```

Características:

- tipo `TIMESTAMP`;
- deverá ser obrigatório após o preenchimento dos registros existentes;
- representa o início efetivo daquele procedimento;
- não deve ser confundido com `tempo_real_minutos`, que continua representando duração.

### Estratégia de migração

1. adicionar a coluna permitindo `NULL`;
2. preencher os procedimentos existentes com horários posteriores à chegada;
3. adicionar `NOT NULL`.

Exemplo conceitual de preenchimento:

```text
Atendimento às 09:00
Primeiro procedimento às 09:10
Segundo procedimento às 09:25
```

Os horários devem ser explícitos e permitir conferir manualmente as médias esperadas.

## 3.3 Manter a chave primária atual

A chave atual de `PROCEDIMENTO_REALIZADO` é composta por:

```text
id_atendimento + codigo_procedimento
```

Isso significa que um mesmo código de procedimento não pode aparecer duas vezes como linhas diferentes no mesmo atendimento.

A procedure deve respeitar essa regra:

- códigos diferentes podem ser enviados no mesmo JSON;
- o mesmo código repetido no JSON deve causar erro;
- a multiplicidade deve continuar sendo representada pela coluna `quantidade`.

## 3.4 Não adicionar outras mudanças neste ponto

Não implementar agora:

- tabela de auditoria;
- coluna de média em `PROCEDIMENTO`;
- tabela de internação;
- trigger de escala;
- trigger de auditoria;
- trigger de média;
- views;
- modelos SQLAlchemy.

Esses elementos pertencem aos demais pontos da Etapa 2.

---

# 4. Contrato de `sp_registrar_atendimento_completo`

## 4.1 Responsabilidade

Registrar, como uma única unidade atômica:

- um atendimento;
- todos os seus procedimentos realizados.

Nenhuma linha pode permanecer no banco se qualquer procedimento da lista for inválido.

## 4.2 Entradas planejadas

A procedure deverá receber:

### Dados do atendimento

- data e hora de chegada;
- duração em minutos;
- paciente;
- papel do residente;
- papel do preceptor;
- unidade.

### Lista JSONB de procedimentos

Cada objeto do array deverá conter:

- `codigo_procedimento`;
- `quantidade`;
- `tempo_real_minutos`;
- `data_hora_inicio`;
- `observacao_intercorrencia`, opcional;
- `flag_faturado`, opcional, assumindo `false` quando omitido.

Exemplo puramente estrutural:

```text
[
    {
        codigo_procedimento,
        quantidade,
        tempo_real_minutos,
        data_hora_inicio,
        observacao_intercorrencia,
        flag_faturado
    }
]
```

## 4.3 Saída planejada

Retornar por parâmetro de saída:

```text
id_atendimento criado
```

Isso facilitará:

- os testes;
- a futura integração com a ORM;
- a exibição de confirmação na aplicação;
- a consulta imediata do atendimento registrado.

## 4.4 Ordem interna da operação

A procedure deverá seguir esta sequência:

1. validar os parâmetros básicos;
2. validar que o JSON é um array;
3. validar que o array possui pelo menos um procedimento;
4. validar a existência do paciente;
5. validar a existência do papel de residente;
6. validar a existência do papel de preceptor;
7. validar a existência da unidade;
8. validar os itens do JSON;
9. inserir o atendimento;
10. capturar o ID gerado;
11. transformar o array JSONB em linhas;
12. inserir todos os procedimentos;
13. retornar o ID do atendimento.

## 4.5 Validações obrigatórias

A procedure deve gerar mensagens de erro claras para:

- duração do atendimento menor ou igual a zero;
- paciente inexistente;
- residente inexistente;
- preceptor inexistente;
- unidade inexistente;
- JSON nulo;
- valor que não seja array JSON;
- array vazio;
- código de procedimento inexistente;
- código repetido dentro da lista;
- quantidade menor ou igual a zero;
- tempo real menor ou igual a zero;
- ausência de campos obrigatórios;
- início do procedimento anterior à chegada do paciente.

As constraints existentes continuarão funcionando como proteção adicional, mas a procedure deverá antecipar os principais erros para produzir mensagens compreensíveis.

## 4.6 Atomicidade

O teste principal deverá comprovar:

```text
Procedimento 1 válido
Procedimento 2 inválido
```

Resultado esperado:

```text
Atendimento não inserido
Procedimento 1 não inserido
Procedimento 2 não inserido
```

A procedure não deve usar blocos de exceção que façam o erro desaparecer.

Caso utilize tratamento de exceção apenas para melhorar a mensagem, deverá relançar a exceção.

---

# 5. Contrato de `sp_calcular_tempo_medio_espera`

## 5.1 Responsabilidade

Calcular, para cada unidade, o tempo médio entre:

```text
ATENDIMENTO.data_hora
```

e:

```text
menor PROCEDIMENTO_REALIZADO.data_hora_inicio
do respectivo atendimento
```

## 5.2 Definição do tempo de espera

Para cada atendimento:

```text
tempo de espera =
início do primeiro procedimento - data/hora de chegada
```

O primeiro procedimento é determinado pelo menor `data_hora_inicio`, e não:

- pelo menor código;
- pela ordem de inserção;
- pelo menor tempo de duração.

## 5.3 Atendimentos considerados

Incluir somente atendimentos que possuam pelo menos um procedimento realizado.

Um atendimento sem procedimento não possui tempo de espera calculável e não deve ser tratado como espera zero.

## 5.4 Unidades sem atendimentos elegíveis

A procedure deve incluir todas as unidades.

Para uma unidade sem atendimento com procedimento:

- `total_atendimentos_considerados` deve ser zero;
- `tempo_medio_espera_minutos` deve ser `NULL`.

Isso diferencia:

```text
não há dados para calcular
```

de:

```text
a espera média foi zero minuto
```

## 5.5 Resultado planejado

O resultado deverá possuir:

- `id_unidade`;
- nome da unidade;
- total de atendimentos considerados;
- média de espera em minutos.

A média deverá ser numérica, arredondada para duas casas decimais.

## 5.6 Forma de retorno

Como uma procedure PostgreSQL não é consultada da mesma forma que uma view, utilizar um cursor de saída:

```text
REFCURSOR
```

Fluxo de utilização esperado:

1. iniciar uma transação;
2. chamar a procedure;
3. buscar as linhas do cursor;
4. encerrar a transação.

Essa abordagem mantém o resultado em formato tabular e evita devolver um documento JSON que depois precisaria ser reconvertido em linhas.

## 5.7 Estrutura conceitual da consulta

A procedure deverá:

1. encontrar o primeiro procedimento de cada atendimento;
2. calcular a diferença entre o primeiro procedimento e a chegada;
3. agrupar os resultados por unidade;
4. calcular a média;
5. associar o resultado à tabela `UNIDADE`;
6. incluir também unidades sem dados.

## 5.8 Casos de teste

Preparar dados com resultados conhecidos, por exemplo:

```text
Unidade A:
Atendimento 1: espera de 10 minutos
Atendimento 2: espera de 20 minutos
Média esperada: 15 minutos
```

Testar também:

- atendimento com dois procedimentos, garantindo que apenas o primeiro seja usado;
- unidade sem atendimentos;
- atendimento sem procedimentos;
- procedimentos inseridos fora da ordem cronológica;
- duas unidades diferentes.

---

# 6. Contrato de `sp_reajustar_escala`

## 6.1 Responsabilidade

Mover todas as escalas de determinado residente que estejam em um dia e turno de origem para um novo dia e turno.

## 6.2 Entradas planejadas

- identificador do papel de residente;
- dia de origem;
- turno de origem;
- dia de destino;
- turno de destino.

A unidade não será alterada.

Exemplo:

```text
Residente 6
segunda/manhã
        ↓
quarta/tarde
```

Se houver duas escalas de origem válidas para o residente, todas deverão ser tratadas pela mesma operação.

## 6.3 Saída planejada

Retornar:

```text
quantidade de escalas atualizadas
```

## 6.4 Validações obrigatórias

A procedure deve validar:

- existência do residente;
- dia de origem válido;
- dia de destino válido;
- turno de origem válido;
- turno de destino válido;
- origem diferente do destino;
- existência de pelo menos uma escala na origem;
- ausência de conflito no destino.

## 6.5 Definição de conflito

Para cada escala que será movida, não pode existir previamente outra linha com:

```text
mesma unidade
mesmo dia de destino
mesmo turno de destino
mesmo residente
```

Essa é a combinação descrita no requisito e também corresponde à constraint única existente em `ESCALA_PLANTAO`.

## 6.6 Compatibilidade com o futuro trigger

O próximo ponto da Etapa 2 criará uma regra mais forte:

```text
o mesmo residente não pode estar no mesmo dia e turno
em duas unidades diferentes
```

A procedure deve ser preparada para não contradizer essa futura regra.

Além do conflito da constraint atual, recomenda-se que ela também rejeite qualquer escala já existente para o mesmo residente no dia e turno de destino, ainda que seja em outra unidade.

Assim, quando o trigger for adicionado, a procedure continuará funcionando com as mesmas regras.

## 6.7 Proteção da operação

A verificação de conflito e o `UPDATE` não podem ser operações independentes.

A procedure deverá:

1. bloquear o registro correspondente ao residente;
2. localizar e bloquear suas escalas de origem;
3. verificar os conflitos;
4. atualizar todas as linhas;
5. concluir a chamada.

O bloqueio do residente é preferível a tentar bloquear somente uma escala conflitante, porque a escala de destino pode ainda não existir.

Isso também deixa a implementação preparada para o cenário de concorrência solicitado posteriormente na Etapa 2.

## 6.8 Comportamento em caso de erro

Se qualquer conflito for encontrado:

- nenhuma escala deve ser atualizada;
- a procedure deve lançar uma exceção;
- a transação deve ser revertida;
- a mensagem deve identificar dia, turno e, quando aplicável, unidade conflitante.

## 6.9 Casos de teste

### Sucesso simples

Mover uma escala para um destino livre.

Resultado:

- uma linha atualizada;
- unidade preservada;
- residente e preceptor preservados.

### Sucesso com múltiplas linhas

Criar mais de uma escala de origem para o residente e verificar que todas são atualizadas.

### Conflito na mesma unidade

Já existe uma escala para:

```text
mesma unidade + destino + residente
```

Resultado:

- exceção;
- nenhuma linha alterada.

### Conflito em outra unidade

Já existe uma escala do residente no mesmo dia e turno de destino em outra unidade.

Resultado:

- exceção;
- nenhuma linha alterada.

### Residente inexistente

Resultado:

- exceção descritiva.

### Nenhuma escala na origem

Resultado recomendado:

- exceção informando que não há escalas para reajustar.

### Origem igual ao destino

Resultado:

- rejeitar a chamada como operação inválida.

---

# 7. Idempotência dos scripts

Os arquivos da Etapa 2 devem poder ser executados novamente durante o desenvolvimento.

## Arquivo de alterações de esquema

Deve verificar a existência das colunas antes de criá-las, ou assumir formalmente um banco recém-restaurado da Etapa 1 e documentar essa exigência.

Para um projeto acadêmico, a estratégia mais previsível é:

```text
recriar o banco da Etapa 1
aplicar os scripts da Etapa 2 em ordem
```

## Arquivo de procedures

Antes de criar cada procedure:

- usar `CREATE OR REPLACE PROCEDURE` quando a assinatura não mudar;
- ou remover explicitamente a assinatura antiga antes de recriar, caso necessário.

As assinaturas devem permanecer estáveis depois de definidas.

---

# 8. Plano de testes SQL

O arquivo `03_testes_stored_procedures.sql` deve ser dividido em três seções.

## 8.1 Testes de registro completo

Testar:

1. atendimento com um procedimento válido;
2. atendimento com vários procedimentos válidos;
3. retorno correto do ID;
4. paciente inexistente;
5. unidade inexistente;
6. procedimento inexistente;
7. procedimento duplicado no JSON;
8. quantidade inválida;
9. horário de início anterior à chegada;
10. rollback integral quando um item intermediário falha.

O teste de rollback deve registrar as contagens antes e depois ou consultar diretamente o atendimento que não deveria existir.

Não depender de IDs fixos recém-gerados. Utilizar o ID devolvido pela procedure ou consultas por atributos controlados pelo teste.

## 8.2 Testes da média de espera

Testar:

1. média conhecida;
2. agrupamento por unidade;
3. escolha do primeiro procedimento;
4. unidade sem dados;
5. atendimento sem procedimento;
6. arredondamento;
7. resultado em minutos.

## 8.3 Testes de reajuste de escala

Testar:

1. atualização normal;
2. atualização de várias linhas;
3. conflito na mesma unidade;
4. conflito entre unidades;
5. residente inexistente;
6. origem sem escalas;
7. origem igual ao destino;
8. rollback sem atualização parcial.

## 8.4 Limpeza dos testes

Os testes devem evitar alterar permanentemente os dados de demonstração.

Sempre que possível:

```text
BEGIN
executar preparação
executar teste
verificar resultados
ROLLBACK
```

Para testes que precisam comprovar uma chamada bem-sucedida, consultar os dados antes do rollback.

---

# 9. Critérios de aceite

A implementação do Ponto 1 estará concluída quando:

## Esquema

- `ATENDIMENTO` possuir relação com `UNIDADE`;
- `PROCEDIMENTO_REALIZADO` possuir horário de início;
- dados anteriores estiverem preenchidos;
- as novas colunas estiverem obrigatórias;
- as FKs estiverem válidas.

## `sp_registrar_atendimento_completo`

- aceitar atendimento e JSONB;
- inserir atendimento e procedimentos;
- devolver o ID;
- rejeitar entradas inválidas;
- realizar rollback integral em caso de falha.

## `sp_calcular_tempo_medio_espera`

- calcular o primeiro procedimento por atendimento;
- calcular espera em minutos;
- agrupar por unidade;
- incluir unidades sem dados;
- retornar resultado tabular.

## `sp_reajustar_escala`

- mover todas as escalas da origem;
- preservar unidade, residente e preceptor;
- retornar quantidade atualizada;
- impedir conflitos;
- não produzir alterações parciais.

## Testes

- existir um script reproduzível;
- haver pelo menos um teste positivo e um negativo para cada procedure;
- haver demonstração explícita do rollback;
- os resultados esperados estarem documentados em comentários.

## Documentação

Criar documentação separada para a Etapa 2, sem alterar o README original:

- criar um arquivo `.md` específico para cada ponto implementado da Etapa 2 (ex: stored procedures, triggers, views, ORM, etc.);
- organizar a documentação em uma pasta dedicada (ex: `docs/etapa2/`), contendo:
  - um arquivo `.md` consolidado com todas as decisões técnicas adotadas na Etapa 2;
  - um arquivo `.md` com regras e diretrizes de implementação destinadas ao agente do Codex, incluindo padrões de organização, nomenclatura, validação e estrutura de commits;
  - subpastas opcionais para cada ponto (ex: `stored_procedures/`, `triggers/`, `views/`, `orm/`), caso a documentação cresça ao longo das próximas implementações.

---

# 10. Ordem de execução recomendada para o Codex

## Passo 1 — preservar a Etapa 1

- usar a nova branch `feat/stored-procedures`;
- não reescrever o histórico da Etapa 1;
- não alterar ainda a interface Streamlit.

## Passo 2 — criar estrutura da Etapa 2

Criar:

```text
sql/etapa2/01_alteracoes_schema.sql
sql/etapa2/02_stored_procedures.sql
sql/etapa2/03_testes_stored_procedures.sql
```

## Passo 3 — implementar a evolução mínima do esquema

- adicionar `ATENDIMENTO.id_unidade`;
- adicionar sua FK;
- preencher dados existentes;
- tornar a coluna obrigatória;
- adicionar `PROCEDIMENTO_REALIZADO.data_hora_inicio`;
- preencher dados existentes;
- tornar a coluna obrigatória.

## Passo 4 — implementar `sp_registrar_atendimento_completo`

- definir assinatura;
- validar parâmetros;
- converter JSONB em registros;
- inserir o atendimento;
- inserir procedimentos;
- devolver o ID;
- garantir propagação dos erros.

## Passo 5 — implementar `sp_calcular_tempo_medio_espera`

- definir cursor de saída;
- localizar primeiro procedimento;
- calcular diferenças;
- agregar por unidade;
- incluir unidades sem dados.

## Passo 6 — implementar `sp_reajustar_escala`

- definir assinatura;
- validar residente, dias e turnos;
- bloquear residente e escalas;
- verificar conflitos;
- atualizar em lote;
- devolver quantidade atualizada.

## Passo 7 — criar testes

- preparar cenários controlados;
- testar sucessos;
- testar erros;
- testar rollback;
- usar transações de teste;
- documentar resultados esperados.

## Passo 8 — atualizar documentação

- adicionar comandos de execução;
- explicar contratos;
- registrar decisões adotadas;
- deixar explícito que app e ORM não foram modificados neste ponto.

## Passo 9 — commits e validação final

Os commits deverão ser realizados manualmente após a implementação completa.

Ao final, deve ser fornecido um breve resumo contendo:

- o que foi implementado em cada parte (alterações de esquema, procedures e testes);
- como executar os scripts na ordem correta;
- como rodar os testes SQL;
- exemplos de chamadas das procedures;
- como verificar os resultados esperados, incluindo casos de sucesso e de erro.

---

# 11. Restrições de escopo para esta implementação

O Codex não deve, neste momento:

- migrar o `app.py` para SQLAlchemy;
- criar modelos ORM;
- remover `psycopg2`;
- implementar triggers;
- criar views;
- implementar a tabela de auditoria;
- implementar internações;
- criar a média armazenada dos procedimentos;
- desenvolver o teste concorrente completo da Etapa 2;
- alterar as consultas avançadas;
- redesenhar a interface Streamlit.

Locks mínimos dentro de `sp_reajustar_escala` são permitidos porque fazem parte da atomicidade da própria procedure, mas a demonstração formal de duas sessões concorrentes deverá permanecer para o Ponto 6.
