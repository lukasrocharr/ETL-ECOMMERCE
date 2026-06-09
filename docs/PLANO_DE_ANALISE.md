# Plano de Análise

**Projeto:** E-commerce — Funil de Conversão e Comportamento do Consumidor
**Dataset:** Kaggle — *eCommerce behavior data from multi category store*

## 1. Contexto

O dataset registra o comportamento de usuários em uma loja virtual multicategoria.
Cada linha é um **evento** com as colunas: `event_time`, `event_type`
(`view`/`cart`/`purchase`), `product_id`, `category_id`, `category_code`, `brand`,
`price`, `user_id`, `user_session`.

A partir desses eventos brutos construímos um Data Warehouse que permite analisar o
**funil de conversão**, o **abandono de carrinho** e o **valor gerado por marca**.

## 2. Perguntas de negócio

### Pergunta 1 — Taxa de conversão por categoria
> Qual é a taxa de conversão (Visualização → Carrinho → Compra) por categoria de produto?

- **Responde:** `EXEC dbo.sp_AnaliseFunilConversao;`
- **Métricas:** Visualizações, Carrinhos, Compras, % View→Cart, % Cart→Buy, % Conversão total.
- **Valor:** identifica categorias com muito tráfego e baixa conversão (oportunidade de
  otimização de página/preço) e categorias campeãs de conversão.

### Pergunta 2 — Horários de pico de abandono
> Quais são os horários com maior volume de abandono de carrinho?

- **Responde:** `EXEC dbo.sp_AnaliseAbandonoHorario;`
- **Métricas:** abandono por hora do dia, separado por dia útil × fim de semana,
  valor monetário abandonado e taxa de abandono sobre os carrinhos da hora.
- **Valor:** direciona campanhas de remarketing e e-mails de recuperação de carrinho
  para as janelas de maior perda.

### Pergunta 3 — Receita: marcas vistas × compradas
> Qual o perfil de faturamento (LTV e Ticket Médio) das marcas mais visualizadas versus as mais compradas?

- **Responde:** `SELECT * FROM dbo.vw_ReceitaPorMarca ORDER BY ReceitaTotal DESC;`
- **Métricas:** total de visualizações, unidades vendidas, receita total, ticket médio por marca.
- **Valor:** revela marcas com alta vitrine e baixa conversão (problema de preço/estoque)
  e marcas que sustentam o faturamento.

## 3. Como o modelo suporta as análises

- **`Fato_EventosNavegacao`** (grão de evento) sustenta o funil completo e os horários.
- **`Fato_AbandonoCarrinho`** (derivada no ETL) isola sessões com `cart` sem `purchase`.
- **`Fato_Pedido` / `Fato_ItemPedido` / `Fato_Pagamento`** sustentam receita, ticket e LTV.
- **`Dim_Tempo`** permite recortes por dia útil/fim de semana e sazonalidade.
- **`Dim_Categoria` / `Dim_Marca`** permitem o agrupamento de negócio.

## 4. Dashboard de BI (conexão)

As Stored Procedures analíticas e as Views são o ponto de consumo para Power BI /
Metabase / Looker Studio (conexão SQL Server, host `localhost,1433`, banco
`EcommerceDW`). Sugestão de painéis: funil por categoria, heatmap de abandono por hora
e ranking de receita por marca.
