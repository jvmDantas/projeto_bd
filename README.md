# 🏥 Sistema de Gestão Hospitalar

**Projeto de Banco de Dados — Dra. Yuska Maritan Brito**  
Etapa 1: Implementação do BD + CRUD + Consultas Analíticas  
SGBD: PostgreSQL | Interface: Streamlit

Alunos: João Victor Martins e Luís Henrique Aranha

---

## 📋 Pré-requisitos

| Ferramenta | Versão mínima | Download |
|---|---|---|
| Python | 3.10+ | https://www.python.org/downloads/ |
| PostgreSQL | 14+ | https://www.postgresql.org/download/ |

---

## 🗄️ 1. Configurar o Banco de Dados

### 1.1 Criar o banco

Abra o **pgAdmin** ou o terminal `psql` e execute:

```sql
CREATE DATABASE hospital_gestor;
```

> ⚠️ Se preferir usar um banco já existente (ex: `postgres`), pule esta etapa e ajuste o nome do banco na interface do app.

### 1.2 Executar o script SQL

Com o banco criado, execute o script `hospital_system_v2.sql`, que cria todas as tabelas e insere os dados de exemplo.

**Via psql (linha de comando):**

```bash
psql -U postgres -d hospital_gestor -f hospital_system_v2.sql
```

---

## 🐍 2. Instalar as Dependências Python

No terminal, dentro da pasta do projeto:

```bash
# (Opcional, mas recomendado) Criar um ambiente virtual
python -m venv .venv

# Ativar o ambiente virtual
# Windows:
.venv\Scripts\activate
# Linux/macOS:
source .venv/bin/activate

# Instalar as dependências
pip install -r requirements.txt
```

**Pacotes instalados:**

| Pacote | Uso |
|---|---|
| `streamlit >= 1.30` | Interface web |
| `psycopg2-binary >= 2.9` | Conexão com PostgreSQL |
| `pandas >= 2.0` | Manipulação de dados |

---

## 🚀 3. Executar a Aplicação

```bash
streamlit run app.py
```

O browser abrirá automaticamente em `http://localhost:8501`.

---

## 🔌 4. Configurar a Conexão na Interface

Na barra lateral do app, preencha os dados de conexão:

| Campo | Valor padrão | Descrição |
|---|---|---|
| **Host** | `localhost` | Endereço do servidor PostgreSQL |
| **Porta** | `5432` | Porta padrão do PostgreSQL |
| **Banco** | `hospital_gestor` | Nome do banco criado no passo 1 |
| **Usuário** | `postgres` | Usuário do PostgreSQL |
| **Senha** | *(sua senha)* | Senha definida na instalação |

Clique em **"Testar conexão"** para confirmar.

> ⚠️ **Importante:** O banco informado no campo **Banco** deve ser exatamente aquele onde o script SQL foi executado.

---