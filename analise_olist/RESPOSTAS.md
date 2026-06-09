# Respostas às 10 Perguntas de Negócio — Olist

> Base: **OlistDW** (99.441 pedidos, 112.650 itens, 103.886 pagamentos, 99.224 avaliações).
> Queries executadas: [`01_perguntas.sql`](01_perguntas.sql). Carga: [`00_setup_e_carga.sql`](00_setup_e_carga.sql).

---

### 1) Qual forma de pagamento é mais usada?
**Cartão de crédito**, disparado. Domina em volume e valor.

| Forma | Transações | % | Valor total (R$) |
|---|--:|--:|--:|
| credit_card | 76.795 | **73,9%** | 12.542.084 |
| boleto | 19.784 | 19,0% | 2.869.361 |
| voucher | 5.775 | 5,6% | 379.437 |
| debit_card | 1.529 | 1,5% | 217.990 |

---

### 2) Qual a taxa de recompra dos clientes?
**Apenas 3,12%.** De 96.096 clientes únicos, só 2.997 fizeram mais de um pedido — a base é fortemente de **compra única** (oportunidade de fidelização/CRM).

---

### 3) Quais estados têm mais clientes ativos?
**São Paulo lidera com folga** (40.302 clientes ativos), seguido de RJ e MG. O Sudeste concentra a maioria.

| Estado | Clientes ativos |
|---|--:|
| SP | 40.302 |
| RJ | 12.384 |
| MG | 11.259 |
| RS | 5.277 |
| PR | 4.882 |

---

### 4) Quais meses têm maior volume de vendas?
**Novembro/2017 é o pico** (7.451 pedidos) — efeito **Black Friday**. Os meses do 1º semestre de 2018 também são fortes.

| Ano-Mês | Pedidos | Receita (R$) |
|---|--:|--:|
| 2017-11 | 7.451 | 1.010.271 |
| 2018-01 | 7.220 | 950.030 |
| 2018-03 | 7.188 | 983.213 |
| 2018-04 | 6.934 | 996.648 |
| 2018-05 | 6.853 | 996.518 |

---

### 5) Quais categorias foram mais vendidas?
Por **itens vendidos**, lidera **cama/mesa/banho** (`bed_bath_table`); por **receita**, **saúde & beleza** (`health_beauty`) e **relógios/presentes** se destacam (ticket maior).

| Categoria | Itens | Receita (R$) |
|---|--:|--:|
| bed_bath_table | 11.115 | 1.036.989 |
| health_beauty | 9.670 | 1.258.681 |
| sports_leisure | 8.641 | 988.049 |
| furniture_decor | 8.334 | 729.762 |
| computers_accessories | 7.827 | 911.954 |

---

### 6) Qual o crescimento MoM (mês a mês) de vendas?
Forte crescimento ao longo de **2017** (ápice em nov/2017, +52% vs out). Em **2018** a receita **estabiliza** em ~R$ 850k–1M/mês. *(Os meses de 2016 e set/2018 são caudas com pouquíssimos dados.)*

| Mês | Receita (R$) | MoM |
|---|--:|--:|
| 2017-09 | 624.402 | +8,8% |
| 2017-10 | 664.219 | +6,4% |
| **2017-11** | **1.010.271** | **+52,1%** |
| 2017-12 | 743.914 | −26,4% |
| 2018-01 | 950.030 | +27,7% |

---

### 7) Qual o tempo médio de entrega?
**~12,5 dias** da compra até a entrega. Em média os pedidos chegam **~12 dias antes** do prazo estimado, e **93,2%** são entregues **no prazo**.

| Métrica | Valor |
|---|--:|
| Pedidos entregues | 96.470 |
| Dias médios de entrega | **12,5** |
| Dias médios de folga vs estimativa | 11,9 |
| % no prazo | 93,2% |

---

### 8) Quais os maiores motivos de cancelamento?
⚠️ **O Olist não registra um "motivo" textual de cancelamento.** O que dá para medir é o **status** dos pedidos: a esmagadora maioria é `delivered` (97%). Os problemáticos são **`canceled` (625)** e **`unavailable` (609)** — este último sugere **indisponibilidade/ruptura de estoque** como principal causa de não-entrega. Entre os cancelados, as categorias mais frequentes são `sports_leisure`, `housewares` e `computers_accessories`.

| Status | Qtd | % |
|---|--:|--:|
| delivered | 96.478 | 97,0% |
| shipped | 1.107 | 1,1% |
| canceled | 625 | 0,6% |
| unavailable | 609 | 0,6% |
| invoiced | 314 | 0,3% |
| processing | 301 | 0,3% |

---

### 9) Quais vendedores têm mais receita?
O **top seller** (`4869f7a5…`, de Guariba/SP) faturou **R$ 229.473**. O ranking é **dominado por vendedores de SP**.

| Vendedor (id) | UF | Cidade | Receita (R$) |
|---|---|---|--:|
| 4869f7a5dfa2…b52b2 | SP | Guariba | 229.473 |
| 53243585a1d6…d8905 | BA | Lauro de Freitas | 222.776 |
| 4a3ca9315b74…93884 | SP | Ibitinga | 200.473 |
| fa1c13f2614d…ecda94 | SP | Sumaré | 194.042 |
| 7c67e1448b00…b010ab | SP | Itaquaquecetuba | 187.924 |

---

### 10) Qual a satisfação dos clientes?
**Boa, mas polarizada.** Nota média **4,09/5**; **77%** dão nota 4–5. Porém há uma cauda relevante de **insatisfeitos: 14,7%** dão nota 1–2 (sendo 11,5% nota 1).

| Nota | Avaliações | % |
|---|--:|--:|
| 5 | 57.328 | 57,8% |
| 4 | 19.142 | 19,3% |
| 3 | 8.179 | 8,2% |
| 2 | 3.151 | 3,2% |
| 1 | 11.424 | 11,5% |

---

## Como reproduzir
```bash
# Docker ativo + CSVs do Olist em /home/artur/Downloads/etl-ecommerce/archive
docker run -d --name olist_dw -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='Str0ng!Passw0rd2024' \
  -p 14333:1433 -v /home/artur/Downloads/etl-ecommerce/archive:/data:ro \
  mcr.microsoft.com/mssql/server:2022-latest

docker cp 00_setup_e_carga.sql olist_dw:/sql/ ; docker cp 01_perguntas.sql olist_dw:/sql/
docker exec olist_dw /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Str0ng!Passw0rd2024' -C -i /sql/00_setup_e_carga.sql
docker exec olist_dw /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Str0ng!Passw0rd2024' -C -i /sql/01_perguntas.sql
```

> Nota técnica: o `BULK INSERT` roda sem `CODEPAGE` (não suportado no SQL Server Linux);
> por isso alguns acentos em nomes de cidade podem aparecer trocados — não afeta os números.
