# Etapa 2 — Ponto 1: Stored Procedures

## Escopo implementado

Este ponto adiciona ao PostgreSQL:

- `sp_registrar_atendimento_completo`;
- `sp_calcular_tempo_medio_espera`;
- `sp_reajustar_escala`;
- a relação entre `ATENDIMENTO` e `UNIDADE`;
- o instante de início em `PROCEDIMENTO_REALIZADO`;
- testes SQL positivos, negativos e de atomicidade.

O script original `hospital_system_v2.sql`, o `README.md` e a aplicação
Streamlit não foram alterados. ORM, triggers, views, auditoria e o cenário
formal de concorrência pertencem a outros pontos da Etapa 2.

## Ordem de execução

Partindo de um banco vazio, execute:

```bash
psql -U postgres -d hospital_gestor -v ON_ERROR_STOP=1 \
  -f hospital_system_v2.sql

psql -U postgres -d hospital_gestor -v ON_ERROR_STOP=1 \
  -f sql/etapa2/01_alteracoes_schema.sql \
  -f sql/etapa2/02_stored_procedures.sql
```

O primeiro script incremental preenche os registros de demonstração de forma
explícita, adiciona as restrições e interrompe a migração se encontrar algum
registro desconhecido ainda sem unidade ou horário de início. Ele também
considera o atendimento `15`, criado pela demonstração CRUD ao final do script
da Etapa 1.

Os dois scripts da implementação podem ser reaplicados: as colunas e a FK têm
proteção contra recriação, enquanto as procedures usam
`CREATE OR REPLACE PROCEDURE`.

## Alterações mínimas de esquema

### `ATENDIMENTO.id_unidade`

- tipo `INTEGER`;
- FK para `UNIDADE.id_unidade`;
- `ON DELETE RESTRICT`;
- `NOT NULL` após o preenchimento dos dados existentes.

### `PROCEDIMENTO_REALIZADO.data_hora_inicio`

- tipo `TIMESTAMP`;
- representa o instante efetivo de início;
- `NOT NULL` após o preenchimento dos dados existentes.

`tempo_real_minutos` continua representando duração. A chave primária composta
de `PROCEDIMENTO_REALIZADO` foi preservada; repetições são informadas por
`quantidade`.

## `sp_registrar_atendimento_completo`

O parâmetro de residente representa `PAPEL_RESIDENTE.id_papel`. A chamada
recebe os dados do atendimento, um array JSONB e devolve o ID criado:

```sql
CALL sp_registrar_atendimento_completo(
    TIMESTAMP '2030-03-01 09:00:00',
    45,
    1,
    6,
    1,
    1,
    '[
        {
            "codigo_procedimento": 1002,
            "quantidade": 1,
            "tempo_real_minutos": 10,
            "data_hora_inicio": "2030-03-01 09:10:00",
            "observacao_intercorrencia": null,
            "flag_faturado": false
        }
    ]'::jsonb,
    NULL
);
```

Os quatro campos obrigatórios de cada item são:

- `codigo_procedimento`;
- `quantidade`;
- `tempo_real_minutos`;
- `data_hora_inicio`.

`observacao_intercorrencia` e `flag_faturado` são opcionais. Quando omitida ou
nula, `flag_faturado` assume `false`.

A procedure valida referências, valores positivos, tipos dos campos JSON,
datas, duplicidade de códigos e existência dos procedimentos antes das
inserções. Ela não captura o erro final nem confirma a transação. Assim, uma
exceção é propagada e o chamador pode reverter toda a operação:

```sql
BEGIN;
CALL sp_registrar_atendimento_completo(/* parâmetros e NULL para a saída */);
COMMIT;
-- Em caso de erro, executar ROLLBACK no lugar do COMMIT.
```

## `sp_calcular_tempo_medio_espera`

A procedure abre um `REFCURSOR`. Ela usa o menor
`data_hora_inicio` de cada atendimento, exclui atendimentos sem procedimentos,
arredonda a média em minutos para duas casas e mantém unidades sem dados com
total zero e média nula.

O cursor só existe dentro de uma transação:

```sql
BEGIN;
CALL sp_calcular_tempo_medio_espera('cur_tempo_espera');
FETCH ALL FROM cur_tempo_espera;
COMMIT;
```

Colunas retornadas:

- `id_unidade`;
- `nome_unidade`;
- `total_atendimentos_considerados`;
- `tempo_medio_espera_minutos`.

## `sp_reajustar_escala`

A procedure recebe o papel do residente, dia/turno de origem e dia/turno de
destino. A unidade, o residente e o preceptor de cada escala são preservados.

```sql
CALL sp_reajustar_escala(
    6,
    'segunda',
    'manhã',
    'quarta',
    'tarde',
    NULL
);
```

O parâmetro de saída informa quantas escalas foram atualizadas. A procedure:

1. valida os valores de entrada;
2. bloqueia o papel do residente com `FOR UPDATE`;
3. bloqueia todas as escalas de origem;
4. rejeita qualquer escala preexistente do residente no destino, inclusive em
   outra unidade;
5. atualiza todas as linhas de origem em uma única instrução.

O bloqueio do residente serializa chamadas da própria procedure para o mesmo
residente. A demonstração completa com duas sessões concorrentes continua
reservada ao Ponto 6 da Etapa 2.

## Execução dos testes

```bash
psql -U postgres -d hospital_gestor \
  -f sql/etapa2/03_testes_stored_procedures.sql
```

O arquivo ativa `ON_ERROR_STOP`, usa asserções e termina com `ROLLBACK`. O
resultado esperado é:

```text
OK - registro completo, validacoes e atomicidade
OK - media conhecida, primeiro procedimento, unidades sem dados e arredondamento
OK - reajustes, conflitos, validacoes e ausencia de atualizacao parcial
Todos os testes passaram; os dados de teste foram revertidos.
```

Entre os casos cobertos estão o primeiro item válido seguido de um inválido,
códigos repetidos, referências inexistentes, média conhecida, procedimentos
inseridos fora da ordem cronológica, unidade sem dados, atualização múltipla e
conflitos na mesma unidade ou entre unidades.
