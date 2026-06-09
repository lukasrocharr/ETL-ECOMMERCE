<h1 align="center">🛒 ETL E-commerce — Data Warehouse em T-SQL</h1>

<p align="center">
  <b>Engenharia e Análise de Dados de E-commerce com SQL Server</b><br>
  Da extração de eventos brutos de navegação até insights de funil de conversão.
</p>

<p align="center">
  <img alt="SQL Server" src="https://img.shields.io/badge/SQL%20Server-2019%2F2022-CC2927?logo=microsoftsqlserver&logoColor=white">
  <img alt="T-SQL" src="https://img.shields.io/badge/Linguagem-T--SQL-blue">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-pronto-2496ED?logo=docker&logoColor=white">
  <img alt="Tabelas" src="https://img.shields.io/badge/Tabelas-20-success">
  <img alt="Fato" src="https://img.shields.io/badge/Fato%20principal-%3E500k%20linhas-success">
</p>

---

## 📌 O que é este projeto

Um pipeline completo de **ETL** e um **Data Warehouse** (modelo estrela/floco-de-neve)
construídos **exclusivamente em T-SQL**. Ele pega eventos brutos de uma loja virtual
(visualização → carrinho → compra) e os transforma em respostas para perguntas de
negócio reais.

> **Tema:** E-commerce — Funil de Conversão e Comportamento do Consumidor
> **Dataset:** Kaggle — *eCommerce behavior data from multi category store*

---

## 🇧🇷 Análise Olist — 10 Perguntas de Negócio

Além do DW de eventos, o repositório traz a análise do dataset **Olist (Brazilian
E-Commerce)** — ~100 mil pedidos reais (2016–2018) carregados em SQL Server e
respondidos com T-SQL (`analise_olist/`). As 10 perguntas e suas respostas:

| # | Pergunta de negócio | Resposta (resumo) |
|---|---------------------|-------------------|
| 1 | Qual forma de pagamento é mais usada? | **Cartão de crédito** — 73,9% das transações |
| 2 | Qual a taxa de recompra dos clientes? | Apenas **3,12%** — base quase toda de compra única |
| 3 | Quais estados têm mais clientes ativos? | **SP** (40.302), seguido de RJ e MG |
| 4 | Quais meses têm maior volume de vendas? | Pico em **nov/2017** (Black Friday) |
| 5 | Quais categorias foram mais vendidas? | `bed_bath_table` (volume) e `health_beauty` (receita) |
| 6 | Qual o crescimento MoM de vendas? | Alta forte em 2017; estabiliza em ~R$ 1 mi/mês em 2018 |
| 7 | Qual o tempo médio de entrega? | **~12,5 dias**; 93,2% no prazo |
| 8 | Quais os maiores motivos de cancelamento? | Sem campo de "motivo"; `canceled`+`unavailable` ≈ ruptura |
| 9 | Quais vendedores têm mais receita? | Top seller (Guariba/SP): **R$ 229 mil**; SP domina |
| 10 | Qual a satisfação dos clientes? | Nota média **4,09/5**; 77% satisfeitos, 14,7% insatisfeitos |

📂 **Artefatos:** [`analise_olist/01_perguntas.sql`](analise_olist/01_perguntas.sql) ·
[respostas completas](analise_olist/RESPOSTAS.md) ·
[`Analise_Olist.xlsx`](analise_olist/Analise_Olist.xlsx) ·
[`Apresentacao_Olist.pptx`](analise_olist/Apresentacao_Olist.pptx)

---

## 🚀 Começando em 2 passos

> Você **não** precisa instalar o SQL Server. Só precisa de **Docker**.

```bash
# 1) garanta que o Docker está rodando
sudo systemctl start docker

# 2) suba o banco e rode TUDO (DDL → ETL → análises → demos)
./run_local.sh
```

O script faz sozinho:
sobe um SQL Server 2022 → cria o banco `EcommerceDW` → executa todos os scripts na
ordem → roda o ETL gerando **~590 mil eventos** → valida a carga → demonstra triggers
e segurança.

<details>
<summary>🔌 Usar o CSV real do Kaggle (em vez da amostra)</summary>

```bash
docker cp 2019-Oct.csv ecommerce_dw:/data/2019-Oct.csv
```
```sql
EXEC dbo.sp_ExtractKaggleData @CaminhoArquivo = N'/data/2019-Oct.csv';
EXEC dbo.sp_TransformEventos;
EXEC dbo.sp_LoadFatoNavegacao;
```
A amostra sintética usa **exatamente o mesmo layout de colunas** do Kaggle, então nada
mais no pipeline muda.
</details>

---

## 🏗️ Arquitetura do pipeline

```
   CSV Kaggle / Amostra sintética
              │
              ▼
   ┌──────────────────────┐   sp_ExtractKaggleData
   │   stg.EventosRaw      │   (BULK INSERT ou gerador)
   └──────────┬───────────┘
              │  sp_TransformEventos  (limpeza, tipagem, enriquecimento)
              ▼
   ┌──────────────────────┐
   │  stg.EventosClean     │
   └──────────┬───────────┘
              │  sp_LoadFatoNavegacao  (BEGIN TRAN ... COMMIT)
              ▼
   ┌───────────────────────────────────────────────┐
   │  14 Dimensões  +  6 Fatos  (modelo estrela)    │
   └──────────┬────────────────────────┬───────────┘
              ▼                         ▼
        Views (5)              SP Analíticas (2)  ──►  Dashboard de BI
```

### Modelo de dados (estrela/floco-de-neve)

```
                         ┌───────────────┐
          ┌──────────────│   Dim_Tempo   │
          │              └───────────────┘
 ┌────────▼─────────┐    ┌───────────────┐    ┌───────────────┐
 │   Dim_Usuario    │────│               │────│  Dim_Produto  │──┐
 └──────────────────┘    │     FATO      │    └───────────────┘  │ floco:
 ┌──────────────────┐    │  Eventos      │    ┌───────────────┐  ├─ Dim_Categoria
 │ Dim_TipoEvento   │────│  Navegacao    │    │   Dim_Marca   │  ├─ Dim_Subcategoria
 └──────────────────┘    │  (>500k)      │    └───────────────┘  └─ Dim_FaixaPreco
 ┌──────────────────┐    │               │    ┌───────────────┐
 │ Dim_OrigemTrafego│────│               │────│ Dim_Geografia │
 └──────────────────┘    └───────┬───────┘    └───────────────┘
                                 │  Dim_Dispositivo, Dim_CampanhaPromo
       Fatos derivadas pelo ETL  ▼
   Fato_Pedido → Fato_ItemPedido → Fato_Pagamento   |   Fato_AbandonoCarrinho
```

---

## 📂 Estrutura do repositório

```
.
├── README.md                  ← este arquivo
├── srs.md                     ← Especificação de Requisitos (SRS)
├── run_local.sh               ← orquestra Docker + sqlcmd (1 comando)
│
├── sql/
│   ├── 00_create_database.sql       banco + schemas (stg/dim/fato)
│   ├── 01_ddl_staging.sql           staging: EventosRaw / EventosClean
│   ├── 02_ddl_dimensions.sql        14 dimensões
│   ├── 03_ddl_facts.sql             6 fatos + tabela de auditoria
│   ├── 04_seed_static_dims.sql      dicionários + calendário (Dim_Tempo)
│   ├── 05_functions.sql             2 functions
│   ├── 06_views.sql                 5 views
│   ├── 07_sp_etl.sql                3 SP de ETL  (+ gerador de amostra)
│   ├── 08_sp_analytics.sql          2 SP analíticas
│   ├── 09_triggers.sql              2 triggers
│   ├── 10_indexes.sql               índices de performance
│   ├── 11_dcl_security.sql          3 roles (segurança / DCL)
│   ├── 12_run_pipeline.sql          executa o ETL + validações
│   └── 13_demo_triggers_seguranca.sql
│
└── docs/
    ├── PLANO_DE_ANALISE.md          perguntas de negócio
    ├── DICIONARIO_DE_DADOS.md       todas as tabelas e colunas
    └── MANUAL_DE_USO.md             como rodar cada rotina
```

---

## ✅ Requisitos atendidos

| Requisito                                | Onde está                                              |
|------------------------------------------|--------------------------------------------------------|
| **20 tabelas** (14 dim + 6 fato)         | `02_ddl_dimensions.sql`, `03_ddl_facts.sql`            |
| **Fato principal > 200k** (entrega >500k)| `Fato_EventosNavegacao` — validado em `12`             |
| **ETL em T-SQL**                         | `07_sp_etl.sql` (extract → transform → load)           |
| **5 Views**                              | `06_views.sql`                                         |
| **5 Stored Procedures** (3 ETL + 2 análise) | `07` e `08`                                         |
| **2 Functions**                          | `fn_ClassificarTicket`, `fn_CalcularSessaoMinutos`     |
| **2 Triggers**                           | `trg_AuditoriaPedidos`, `trg_AtualizacaoPreco`         |
| **3 Roles** (menor privilégio / DCL)     | `DBA_Admin`, `Eng_Dados`, `Analista_BI`                |
| **Transações** (DTL)                     | `BEGIN TRAN/COMMIT/ROLLBACK` em `sp_LoadFatoNavegacao` |
| **Constraints** PK/FK/UNIQUE/CHECK/DEFAULT | dimensões e fatos                                    |
| **Índices** (otimização)                 | `10_indexes.sql`                                      |
| **Scripts idempotentes**                 | `DROP IF EXISTS` / `CREATE OR ALTER` / `MERGE`         |
| **Plano de Análise + Dicionário + Manual** | `docs/`                                              |

---

## 🔎 Exemplos de uso

```sql
-- Pergunta 1: funil de conversão por categoria
EXEC dbo.sp_AnaliseFunilConversao;

-- Pergunta 2: top horários de abandono de carrinho
EXEC dbo.sp_AnaliseAbandonoHorario @TopN = 10;

-- Pergunta 3: receita x visualizações por marca
SELECT * FROM dbo.vw_ReceitaPorMarca ORDER BY ReceitaTotal DESC;

-- Acompanhar o ETL
SELECT * FROM dbo.vw_MonitoramentoCarga ORDER BY AuditSK DESC;
```

---

## 🔐 Segurança (DCL — princípio do menor privilégio)

| Role          | Pode                                                                 |
|---------------|----------------------------------------------------------------------|
| `DBA_Admin`   | Controle total (DDL/DCL).                                            |
| `Eng_Dados`   | Executar as SP de ETL + manipular a staging.                        |
| `Analista_BI` | **Somente** ler as Views e executar as SP analíticas. Não enxerga as tabelas transacionais (há `DENY` explícito). |

---

## 📊 Conectando um Dashboard de BI

Conecte Power BI / Metabase / Looker Studio ao SQL Server:

| Parâmetro | Valor                 |
|-----------|-----------------------|
| Servidor  | `localhost,1433`      |
| Banco     | `EcommerceDW`         |
| Fonte     | Views `dbo.vw_*` e SP analíticas |

Painéis sugeridos: funil por categoria, *heatmap* de abandono por hora e ranking de
receita por marca.

---

## 📖 Documentação completa

- 📋 [Plano de Análise](docs/PLANO_DE_ANALISE.md)
- 📚 [Dicionário de Dados](docs/DICIONARIO_DE_DADOS.md)
- 🛠️ [Manual de Uso](docs/MANUAL_DE_USO.md)
- 📜 [Especificação de Requisitos (SRS)](srs.md)
