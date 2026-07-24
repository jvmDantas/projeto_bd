# Etapa 2 — Diretrizes de implementação

Estas regras orientam as próximas implementações da Etapa 2 e devem ser lidas
em conjunto com `etapa2.md` e com as instruções específicas de cada ponto.

## Organização

- preservar `hospital_system_v2.sql` como referência da Etapa 1;
- colocar scripts incrementais em `sql/etapa2/` com prefixos numéricos;
- manter a documentação específica de cada ponto em
  `docs/etapa2/pontoN/`, com um arquivo principal que explique as mudanças e
  documente os objetos criados ou modificados;
- registrar as justificativas técnicas de todos os pontos somente em
  `docs/etapa2/decisoes_tecnicas.md`, de forma concisa e cumulativa;
- não misturar ORM, interface e objetos de banco no mesmo ponto sem requisito;
- não criar commits automaticamente; separar os commits manualmente por ponto.

## Nomenclatura SQL

- procedures: prefixo `sp_`;
- parâmetros de entrada e saída: prefixo `p_`;
- variáveis PL/pgSQL: prefixo `v_`;
- FKs nomeadas: prefixo `fk_`;
- triggers futuros: prefixo `trg_`;
- views futuras: prefixo `vw_`;
- usar os nomes de domínio já existentes, inclusive acentos nos valores de
  `dia_semana` e `turno`.

O termo `id_residente` nos requisitos deve ser mapeado para
`PAPEL_RESIDENTE.id_papel`, salvo decisão de modelo posterior explicitamente
documentada.

## Migrações

- aplicar alterações depois do script da Etapa 1;
- para novas colunas obrigatórias em tabelas populadas: adicionar anulável,
  preencher deterministicamente, validar e só então aplicar `NOT NULL`;
- dar nomes explícitos a novas constraints;
- preferir scripts reaplicáveis durante o desenvolvimento;
- interromper a migração com mensagem clara se as precondições não forem
  atendidas;
- não introduzir objetos pertencentes a pontos ainda não implementados.

## Procedures e transações

- não executar `COMMIT` ou `ROLLBACK` dentro das procedures;
- não capturar exceções para ocultá-las;
- quando uma captura melhorar a mensagem, lançar uma nova exceção clara;
- validar parâmetros antes de alterar dados;
- manter constraints e FKs como última linha de proteção;
- bloquear um recurso estável quando a operação combinar verificação e escrita;
- usar uma única instrução em operações que devam atualizar um conjunto
  completo.

## Validação

- distinguir valor nulo, tipo incorreto, referência inexistente e conflito;
- produzir mensagens que identifiquem o parâmetro ou item problemático;
- validar valores enumerados conforme as constraints da tabela;
- validar números positivos antes de inserir;
- validar campos obrigatórios e tipos ao consumir JSONB;
- preservar a semântica das colunas existentes.

## Testes

- ativar `ON_ERROR_STOP` nos scripts executados pelo `psql`;
- incluir ao menos um sucesso e um erro por objeto implementado;
- testar resultados por atributos controlados ou IDs devolvidos pela operação;
- não presumir IDs recém-gerados;
- usar horários e médias calculáveis manualmente;
- inserir dados fora da ordem natural quando a ordenação for parte da regra;
- verificar contagens ou marcadores antes e depois de uma falha atômica;
- envolver fixtures em `BEGIN` e `ROLLBACK` sempre que possível;
- documentar o resultado esperado em comentários e mensagens da execução.

## Documentação e entrega

Cada ponto deve registrar:

- objetos e arquivos criados;
- alterações de esquema;
- assinatura e exemplos de uso;
- decisões e alternativas relevantes;
- ordem de execução;
- forma de rodar os testes;
- resultado esperado;
- limites de escopo e itens reservados aos próximos pontos.

Antes do commit manual, revisar `git diff`, executar os scripts em um banco
recriado da Etapa 1 e reaplicar as migrações para verificar idempotência.
