# 🛤 Trilha completa — Como o projeto foi construído

Esta é a **trilha cronológica** de como o ETL foi desenvolvido do zero, com todas as decisões técnicas, problemas encontrados e soluções aplicadas.

---

## 📍 Etapa 1 — Definição do escopo

### Objetivo
Construir um ETL completo sobre o e-commerce brasileiro respondendo 10 perguntas estratégicas.

### Datasets escolhidos
- **Principal:** Olist (Kaggle) — 9 CSVs com ~1,5M registros
- **Complementar:** IBGE (descartado — dados já presentes no Olist)
- **Complementar:** Brasil.io (descartado — não agregaria valor às 10 perguntas)

### Stack definida
- **Banco:** SQL Server 2022 (escolha imposta pelo trabalho)
- **Sistema:** Linux CachyOS via Docker
- **Cliente SQL:** Azure Data Studio
- **Linguagem auxiliar:** Python 3 (para tratamento de CSV)

---

## 📍 Etapa 2 — Configuração do ambiente

### 2.1 Docker
```bash
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 2.2 Container do SQL Server
**Primeiro tentativa (FALHOU):**
- Senha `Etl@2026Comanda` foi rejeitada pelo SQL Server, mesmo atendendo aos requisitos aparentes
- Erro: `Password validation failed`

**Segunda tentativa (SUCESSO):**
```bash
docker run -d \
  --name sqlserver-etl \
  -e ACCEPT_EULA=Y \
  -e MSSQL_SA_PASSWORD='Artur55171862!' \
  -e MSSQL_PID=Express \
  -p 1433:1433 \
  --restart unless-stopped \
  mcr.microsoft.com/mssql/server:2022-latest
```

**Lição aprendida:** O SQL Server tem regras de validação de senha sutis. Usar caracteres simples com maiúscula + minúscula + número + símbolo é a forma mais segura de garantir aceitação.

### 2.3 Azure Data Studio
```bash
paru -S azuredatastudio-bin
```

Conexão configurada:
- Server: `localhost`
- User: `sa`
- Trust Server Certificate: ✅

---

## 📍 Etapa 3 — Criação do banco e camadas

Definição da arquitetura em **3 schemas** seguindo o padrão Medallion (Bronze/Silver/Gold ou RAW/STAGING/MART):

```sql
CREATE DATABASE ecommerce_etl;
CREATE SCHEMA raw;       -- dados brutos
CREATE SCHEMA staging;   -- dados limpos
CREATE SCHEMA mart;      -- dados analíticos
```

**Decisão de design:** schemas separados facilitam manutenção e versionamento. A camada RAW pode ser reconstruída a qualquer momento sem afetar STAGING/MART.

---

## 📍 Etapa 4 — Modelagem das tabelas RAW

Para cada CSV, criada uma tabela com **estrutura idêntica** ao arquivo de origem. Tipos escolhidos com tolerância:

- IDs como `VARCHAR(50)` (não precisamos converter para int)
- Datas como `DATETIME`
- Valores monetários como `DECIMAL(10,2)`
- Coordenadas como `DECIMAL(15,10)`

**Total: 9 tabelas RAW** (customers, orders, order_items, payments, products, sellers, geolocation, category_translation, reviews_limpo).

---

## 📍 Etapa 5 — Importação dos CSVs (a parte mais complicada)

### 5.1 Cópia dos arquivos para dentro do container
O SQL Server roda dentro do Docker, então não enxerga os arquivos do host:

```bash
docker exec sqlserver-etl mkdir -p /var/opt/mssql/dados
docker cp ./data/. sqlserver-etl:/var/opt/mssql/dados/
docker exec -u root sqlserver-etl chown -R mssql:mssql /var/opt/mssql/dados/
```

### 5.2 Primeiro problema: CODEPAGE não suportado em Linux

**Tentativa que falhou:**
```sql
BULK INSERT raw.customers FROM '...' WITH (
    CODEPAGE = '65001',  -- ❌ não funciona em SQL Server Linux
    ...
);
```

**Erro:** `Keyword or statement option 'CODEPAGE' is not supported on the 'Linux' platform.`

**Solução:** remover o `CODEPAGE`. Funciona porque o UTF-8 é o padrão do SQL Server moderno em Linux.

### 5.3 Segundo problema: Reviews com comentários problemáticos

O `BULK INSERT` falhou no dataset de reviews por dois motivos:
1. Comentários em português com **vírgulas** dentro
2. Comentários com **quebras de linha (\n)** dentro do campo
3. `FORMAT = 'CSV'` não funciona em SQL Server Linux

**Tentativa com `MAXERRORS`:** ignora linhas problemáticas, mas perde milhares de reviews.

**Solução final:** pré-processar com Python.

```python
# scripts/limpar_reviews.py
# Mantém só as colunas necessárias (sem o texto livre)
import csv
# ...
for row in reader:
    score = int(row['review_score'])
    if 1 <= score <= 5:
        writer.writerow([
            row['review_id'],
            row['order_id'],
            score,
            row['review_creation_date'][:19],
            row['review_answer_timestamp'][:19]
        ])
```

Resultado: **99.224 reviews limpos importados com sucesso**.

---

## 📍 Etapa 6 — Construção da camada STAGING

Duas tabelas derivadas para facilitar análises:

### staging.orders_clientes
Join entre `orders` e `customers` + cálculo de `dias_entrega`:

```sql
SELECT 
    o.order_id,
    c.customer_unique_id AS cliente_id,
    c.customer_state AS estado,
    -- ...
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS dias_entrega
INTO staging.orders_clientes
FROM raw.orders o
INNER JOIN raw.customers c ON o.customer_id = c.customer_id;
```

**Por que `customer_unique_id`?** Cada `customer_id` é único por pedido (gera duplicatas). O `customer_unique_id` é a chave real do cliente.

### staging.products_categoria
Tradução de categorias português → inglês:

```sql
SELECT 
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'sem_categoria') AS categoria
INTO staging.products_categoria
FROM raw.products p
LEFT JOIN raw.category_translation t ON p.product_category_name = t.product_category_name;
```

**Uso de COALESCE:** garante que produtos sem categoria mapeada não sejam perdidos.

---

## 📍 Etapa 7 — Análise das 10 perguntas

Cada pergunta foi respondida com SQL puro usando recursos como:
- `COUNT(DISTINCT ...)` para contagens únicas
- `GROUP BY` + window functions (`OVER`) para percentuais
- `LAG()` para cálculos temporais (crescimento MoM)
- `DATEDIFF()` para diferenças entre datas
- CTEs (`WITH`) para subconsultas legíveis

### Padrão usado em todas as queries

```sql
SELECT 
    coluna_categorica,
    COUNT(*) AS qtd,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percentual
FROM tabela
GROUP BY coluna_categorica
ORDER BY qtd DESC;
```

Isso retorna automaticamente quantidades **e** percentuais — pronto para o relatório acadêmico.

---

## 📍 Etapa 8 — Validação dos resultados

### Cruzamentos feitos para validar

✅ **Total de orders = Total de customers únicos por order_id**
- 99.441 = 99.441 ✓

✅ **Soma dos percentuais = 100%**
- Verificado em todas as queries de distribuição

✅ **Tempos de entrega negativos descartados**
- `WHERE dias_entrega > 0` na Pergunta 7

✅ **Período inconsistente identificado e marcado**
- Set/Out 2018 com apenas 16 e 4 pedidos = dataset truncado

---

## 📍 Etapa 9 — Insights finais

A análise revelou **5 padrões críticos** do e-commerce brasileiro:

### 1. Concentração de pagamento no cartão de crédito
73,92% — mostra dependência do crédito e exposição ao mercado financeiro.

### 2. Taxa de recompra catastrófica
3,12% — muito abaixo da média de mercado (20-40%). Indica problema sério de retenção.

### 3. Desigualdade regional gritante
SP = 41,83% dos clientes / Norte = menos de 1%. Reflexo da realidade brasileira.

### 4. Black Friday domina o calendário
Novembro/2017 foi o pico absoluto (+62% vs outubro).

### 5. Polarização da satisfação
77% satisfeitos vs 15% extremamente insatisfeitos — sem meio-termo. Padrão típico de e-commerce.

---

## 📍 Etapa 10 — Documentação e entrega

- README.md detalhado com contexto, stack, como rodar e insights
- Scripts SQL organizados na ordem de execução
- Script Python documentado
- Esta trilha técnica explicando o processo

---

## ⚠️ Erros encontrados e como resolver

| Problema | Causa | Solução |
|---|---|---|
| Container em Restarting | Senha fraca | Usar senha com 4 critérios |
| CODEPAGE not supported | SQL Server Linux limitation | Remover CODEPAGE |
| Reviews truncados | Vírgulas em comentários | Pré-processar com Python |
| Truncation row 553 | Estado inválido no CSV | MAXERRORS para tolerar |
| Set/Out 2018 com poucos dados | Dataset truncado | Filtrar fora das análises |

---

## 🎓 O que esse projeto demonstra

✅ **Modelagem de dados** em camadas (data warehouse pattern)
✅ **ETL completo** do zero (extração → transformação → carga)
✅ **SQL avançado** (joins, CTEs, window functions, agregações complexas)
✅ **Resolução de problemas reais** (encoding, malformed CSVs, container networking)
✅ **Análise de negócio** com geração de insights acionáveis
✅ **Documentação técnica** de qualidade

---

**Total: ~1,5 milhão de registros processados | 10 perguntas respondidas | Projeto reproduzível end-to-end**
