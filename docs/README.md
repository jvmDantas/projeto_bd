# Projeto BD

Aplicação em Streamlit para explorar um banco PostgreSQL com telas de CRUD, consultas analíticas, views, procedures, triggers e simulações de concorrência.

## Requisitos

- Python 3.10 ou superior
- PostgreSQL 14 ou superior
- DBeaver ou acesso ao terminal `psql`

## Estrutura de conexão

O projeto lê as credenciais a partir do arquivo `.env` na raiz. O arquivo já vem com as chaves esperadas:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`

Se você usa os padrões locais, a conexão costuma ficar assim:

- host: `localhost`
- porta: `5432`
- usuário: `postgres`
- senha: a senha configurada na sua instalação do PostgreSQL

## 1. Preparar o banco

### Opção A: usando psql

1. Abra o terminal.
2. Conecte no PostgreSQL:

```bash
psql -U postgres -h localhost
```

3. Crie o banco que será usado pelo projeto:

```sql
CREATE DATABASE hospital_gestor;
```

4. Saia do `psql` e aplique todos os scripts com uma única conexão:

```bash
psql -X -v ON_ERROR_STOP=1 \
  -U postgres \
  -h localhost \
  -d hospital_gestor \
  -f sql/01_schema_ddl.sql \
  -f sql/02_seed_data.sql \
  -f sql/03_stored_procedures.sql \
  -f sql/04_triggers.sql \
  -f sql/05_views.sql \
  -f sql/06_queries_etapa1_2.sql
```

Esse é um único comando `psql`, apesar de estar dividido em várias linhas para
facilitar a leitura. Portanto, a senha é solicitada somente uma vez. A opção
`ON_ERROR_STOP=1` interrompe a execução imediatamente caso algum script falhe.

Se quiser eliminar também esse prompt e os prompts dos próximos comandos,
configure o arquivo `~/.pgpass` com uma linha no seguinte formato:

```text
localhost:5432:hospital_gestor:postgres:sua_senha
```

Depois, restrinja as permissões do arquivo:

```bash
chmod 600 ~/.pgpass
```

O PostgreSQL ignora o `.pgpass` quando ele pode ser lido por outros usuários.
Não adicione esse arquivo ao repositório.

### Opção B: usando DBeaver

1. Crie uma nova conexão PostgreSQL apontando para `localhost:5432`.
2. Autentique com o usuário `postgres` e a senha da sua instalação.
3. Crie o banco `hospital_gestor` se ele ainda não existir.
4. Abra um editor SQL no banco `hospital_gestor`.
5. Execute os scripts na mesma ordem:
   - `sql/01_schema_ddl.sql`
   - `sql/02_seed_data.sql`
   - `sql/03_stored_procedures.sql`
   - `sql/04_triggers.sql`
   - `sql/05_views.sql`
   - `sql/06_queries_etapa1_2.sql`

## 2. Configurar o ambiente Python

1. Crie e ative um ambiente virtual:

```bash
python -m venv .venv
source .venv/bin/activate
```

2. Instale as dependências:

```bash
pip install -r requirements.txt
```

## 3. Ajustar o arquivo .env

Confira a raiz do projeto e ajuste o `.env` para refletir sua instalação local. Exemplo:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=hospital_gestor
DB_USER=postgres
DB_PASSWORD=sua_senha
```

## 4. Executar a aplicação

Inicie o Streamlit a partir da raiz do projeto:

```bash
streamlit run app.py
```

Depois, na barra lateral da aplicação, clique em **Testar conexão** para validar as credenciais lidas do `.env`.

## 5. Observações

- Se você alterar o `.env`, reinicie o Streamlit para garantir que os novos valores sejam carregados.
- O app usa os valores do `.env` como padrão, mas a barra lateral ainda permite sobrescrevê-los manualmente durante a execução.

---
