# 📊 ETL E-commerce Brasil — Análise do Mercado Olist

Projeto de **ETL (Extract, Transform, Load)** sobre dados do e-commerce brasileiro utilizando **SQL Server**, com base no dataset público do **Olist** (Kaggle).

> **Trabalho acadêmico** | UNASP SP — Análise e Desenvolvimento de Sistemas
> **Autor:** José Artur Silva Brito ([@ArturJasb](https://github.com/ArturJasb))

---

## 🎯 Sobre o projeto

Este projeto extrai, transforma e carrega dados de **mais de 1,5 milhão de registros** do maior dataset público de e-commerce do Brasil para responder **10 perguntas estratégicas de negócio**.

### Perguntas respondidas

| # | Pergunta | Resposta |
|---|---|---|
| 1 | Qual forma de pagamento é mais usada? | Cartão de crédito (73,92%) |
| 2 | Qual a taxa de recompra dos clientes? | 3,12% (muito baixa) |
| 3 | Quais estados têm mais clientes ativos? | SP (41,83%), RJ (12,88%), MG (11,72%) |
| 4 | Quais meses têm maior volume de vendas? | Novembro/2017 (Black Friday) |
| 5 | Quais categorias foram mais vendidas? | Cama/Mesa/Banho (9,94%) |
| 6 | Qual o crescimento MoM de vendas? | +122% em Fev/2017 (pico inicial) |
| 7 | Tempo médio de entrega? | SP: 8,7 dias / RR: 29,3 dias |
| 8 | Maiores motivos de cancelamento? | 0,63% canceled + 0,61% unavailable |
| 9 | Quais vendedores têm mais receita? | 9 dos top 10 são de SP |
| 10 | Satisfação dos clientes? | Nota média 4,09 — 77% satisfeitos |

---

## 🛠 Stack utilizada

| Tecnologia | Função |
|---|---|
| **Microsoft SQL Server 2022** | Banco de dados (rodando em Docker) |
| **Azure Data Studio** | Interface visual para executar queries |
| **Docker** | Containerização do SQL Server (Linux) |
| **Python 3** | Limpeza prévia de CSV problemático (reviews) |
| **Dataset Olist** | Fonte de dados (Kaggle) |

---

## 📂 Estrutura do repositório

```
.
├── README.md                          # Este arquivo
├── data/                              # CSVs originais do dataset Olist
│   ├── olist_customers_dataset.csv
│   ├── olist_geolocation_dataset.csv
│   ├── olist_order_items_dataset.csv
│   ├── olist_order_payments_dataset.csv
│   ├── olist_order_reviews_dataset.csv
│   ├── olist_orders_dataset.csv
│   ├── olist_products_dataset.csv
│   ├── olist_sellers_dataset.csv
│   └── product_category_name_translation.csv
├── sql/                               # Scripts SQL na ordem de execução
│   ├── 01_setup_database.sql          # Cria banco + schemas
│   ├── 02_create_raw_tables.sql       # Tabelas da camada RAW
│   ├── 03_bulk_insert_csvs.sql        # Importa os CSVs
│   ├── 04_create_staging.sql          # Camada STAGING (dados limpos)
│   ├── 05_analise_perguntas.sql       # As 10 perguntas respondidas
│   └── 06_import_reviews_limpo.sql    # Importação dos reviews (etapa especial)
├── scripts/
│   └── limpar_reviews.py              # Script Python para tratar reviews
└── docs/
    └── arquitetura.md                 # Documentação técnica do ETL
```

---

## 🏗 Arquitetura do ETL

O projeto segue o padrão clássico de **3 camadas**:

```
┌─────────────────────────────────────────────────────────────┐
│  FONTES                                                      │
│  📁 9 CSVs do Olist (Kaggle)                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ BULK INSERT
┌─────────────────────────────────────────────────────────────┐
│  CAMADA RAW (dados brutos)                                   │
│  📦 raw.customers, raw.orders, raw.payments, ...             │
│  - Estrutura idêntica ao CSV                                 │
│  - Sem transformação                                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ SELECT INTO + JOIN
┌─────────────────────────────────────────────────────────────┐
│  CAMADA STAGING (dados limpos)                               │
│  📦 staging.orders_clientes, staging.products_categoria      │
│  - Joins entre tabelas                                       │
│  - Categorias traduzidas                                     │
│  - Cálculo de campos derivados (dias_entrega, etc)           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ QUERIES ANALÍTICAS
┌─────────────────────────────────────────────────────────────┐
│  CAMADA MART (resposta às 10 perguntas)                      │
│  📊 Insights de negócio prontos para o relatório             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Como executar o projeto

### Pré-requisitos

- Docker instalado
- Azure Data Studio (ou SSMS no Windows)
- Python 3 (para o script de limpeza dos reviews)
- ~2GB de RAM disponíveis

### Passo a passo

#### 1️⃣ Subir o SQL Server em Docker

```bash
docker run -d \
  --name sqlserver-etl \
  -e ACCEPT_EULA=Y \
  -e MSSQL_SA_PASSWORD='SuaSenh@Forte123!' \
  -e MSSQL_PID=Express \
  -p 1433:1433 \
  --restart unless-stopped \
  mcr.microsoft.com/mssql/server:2022-latest
```

Confirma que subiu:
```bash
docker ps
```

#### 2️⃣ Conectar no Azure Data Studio

- **Server:** localhost
- **Authentication:** SQL Login
- **User:** sa
- **Password:** (a que você definiu)
- **Trust server certificate:** ✅

#### 3️⃣ Criar o banco e os schemas

Execute o arquivo: `sql/01_setup_database.sql`

#### 4️⃣ Criar as tabelas RAW

Execute: `sql/02_create_raw_tables.sql`

#### 5️⃣ Copiar os CSVs para dentro do container

```bash
docker exec sqlserver-etl mkdir -p /var/opt/mssql/dados
docker cp ./data/. sqlserver-etl:/var/opt/mssql/dados/
docker exec -u root sqlserver-etl chown -R mssql:mssql /var/opt/mssql/dados/
```

#### 6️⃣ Importar os 8 CSVs principais

Execute: `sql/03_bulk_insert_csvs.sql`

#### 7️⃣ Tratar e importar os reviews

O CSV de reviews contém comentários com vírgulas e quebras de linha que quebram o `BULK INSERT` padrão. Solução: limpar com Python primeiro.

```bash
cd data
python3 ../scripts/limpar_reviews.py
docker cp reviews_limpo.csv sqlserver-etl:/var/opt/mssql/dados/
docker exec -u root sqlserver-etl chown mssql:mssql /var/opt/mssql/dados/reviews_limpo.csv
```

Depois execute: `sql/06_import_reviews_limpo.sql`

#### 8️⃣ Criar a camada STAGING

Execute: `sql/04_create_staging.sql`

#### 9️⃣ Rodar as análises

Execute: `sql/05_analise_perguntas.sql` (cada bloco responde uma pergunta)

---

## 📊 Volume de dados processados

| Tabela | Registros |
|---|---|
| customers | 99.441 |
| orders | 99.441 |
| order_items | 112.650 |
| payments | 103.886 |
| products | 32.951 |
| sellers | 3.093 |
| geolocation | 1.000.161 |
| category_translation | 71 |
| reviews_limpo | 99.224 |
| **TOTAL** | **~1,5 milhão** |

---

## 🔍 Principais insights de negócio

### 💳 Pagamento
**Cartão de crédito domina** com 73,92% das transações. Boleto ainda relevante (19%), mas em queda — tendência geral do mercado brasileiro.

### 🔁 Recompra
Apenas **3,12% dos clientes recompram**. Para um e-commerce saudável, esse número deveria estar entre 20-40%. **Oportunidade gigante** para programas de fidelidade.

### 📍 Concentração geográfica
**Sudeste concentra 66% das vendas**. Norte e Nordeste juntos somam menos de 10%. Logística e infraestrutura ainda são barreiras.

### 📅 Sazonalidade
**Black Friday (Nov/2017) foi o pico absoluto** com 7.544 pedidos. Janeiro também forte (compras pós-festas).

### 🚚 Entrega
**SP entrega 3x mais rápido que RR** (8,7 vs 29,3 dias). Disparidade regional gritante.

### ⭐ Satisfação
Nota média 4,09. Mas atenção: **11,51% deram nota 1** — padrão bimodal típico de e-commerce (ótimo ou péssimo, sem meio termo).

---

## 📝 Notas técnicas

### Compatibilidade SQL Server Linux
- `CODEPAGE` não é suportado em Linux → removido das queries
- `FORMAT = 'CSV'` também não funciona → uso de `MAXERRORS` para tolerar truncamentos

### Reviews — caso especial
O CSV de reviews possui comentários em texto livre com vírgulas e `\n` que quebram o parser. Solução: script Python que extrai só as colunas essenciais (id, score, datas) ignorando o texto.

### Dados desconsiderados
- **Set/Out 2018** foram excluídos das análises temporais — o dataset termina nesse período e os números ficam artificialmente baixos (16 e 4 pedidos respectivamente)
- **4 linhas com `state` inválido** (em sellers e geolocation) foram descartadas pelo BULK INSERT — impacto irrelevante

---

## 📚 Fontes dos dados

- **Olist Brazilian E-Commerce Dataset:** [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Período:** 2016 a 2018
- **Pedidos:** ~100.000

---

## 📜 Licença

Projeto acadêmico — uso livre para fins educacionais.

---

**Desenvolvido por José Artur Silva Brito** | UNASP SP | 2026
