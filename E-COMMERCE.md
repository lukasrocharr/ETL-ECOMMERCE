**E-COMMERCE**

*Documentação Técnica do Projeto*

SQL Server · T-SQL · Power BI

Dataset Olist Brazilian E-Commerce · 2016 -- 2018

**Sumário**

Introdução

1\. Visão Geral do Projeto

2\. Tecnologias Utilizadas

3\. Fontes de Dados

4\. Arquitetura --- Esquema Estrela

5\. Tabelas Fato

6\. Tabelas Dimensão

7\. Tabelas de Apoio

8\. Tipos de Dados Utilizados

9\. Objetos T-SQL

10\. Camada de Visualização --- Power BI

11\. Perguntas de Negócio Respondidas

**Introdução**

O crescimento acelerado do comércio eletrônico no Brasil ao longo da
última década consolidou o setor como um dos principais vetores da
economia digital do país. Nesse contexto, a capacidade de transformar
grandes volumes de dados transacionais em informação estratégica
torna-se um diferencial competitivo relevante para organizações que
operam em ambientes de alta concorrência e margens reduzidas.

O presente projeto, denominado **E-COMMERCE**, tem por objetivo a
construção de um armazém de dados *(Data Warehouse)* sobre dados reais
do marketplace brasileiro Olist, compreendendo o período de setembro de
2016 a outubro de 2018. O projeto abrange todas as etapas do ciclo de
vida do dado: da ingestão dos arquivos brutos até a entrega de
indicadores de desempenho em painéis interativos, passando pela
modelagem dimensional, transformação, carga e controle de qualidade.

A escolha do dataset Olist justifica-se por três razões principais.
Primeira: trata-se de dados reais de um negócio brasileiro ativo, com
todas as irregularidades e complexidades inerentes ao ambiente de
produção. Segunda: o conjunto de arquivos cobre múltiplas dimensões do
negócio --- pedidos, clientes, vendedores, produtos, pagamentos,
avaliações e geolocalização ---, o que permite a construção de um modelo
dimensional completo e representativo. Terceira: o volume de registros é
suficiente para demonstrar, em ambiente acadêmico, as implicações
práticas das decisões de modelagem e otimização.

Do ponto de vista tecnológico, o projeto adota o **Microsoft SQL
Server** como plataforma de armazenamento e processamento, fazendo uso
das capacidades da linguagem T-SQL para implementar a lógica de
extração, transformação e carga de dados por meio de procedimentos
armazenados, visões, funções e gatilhos. A camada de visualização é
operacionalizada pelo **Microsoft Power BI**, conectado diretamente ao
banco de dados e responsável pela entrega dos indicadores estratégicos
definidos como perguntas de negócio.

Esta documentação está organizada de forma a conduzir o leitor do
contexto geral do projeto até o detalhamento técnico de cada componente.
As seções iniciais apresentam as tecnologias adotadas e as fontes de
dados utilizadas. Em seguida, são descritos a arquitetura do modelo
dimensional e o detalhamento de cada tabela --- fato, dimensão e apoio
---, com especificação coluna a coluna. A documentação contempla ainda a
explicação dos tipos de dados empregados, o inventário dos objetos
programáveis criados no banco e o mapeamento entre as consultas de
negócio e seus respectivos painéis no Power BI.

O conjunto de decisões técnicas documentado a seguir reflete os
princípios de clareza estrutural, rastreabilidade do processo e
separação de responsabilidades entre as camadas de dados, transformação
e apresentação.

**1 Visão Geral do Projeto**

O projeto **E-COMMERCE** é um Data Warehouse construído sobre dados
reais do marketplace brasileiro Olist, disponibilizados publicamente no
Kaggle. O objetivo central é consolidar, transformar e analisar
informações de pedidos, clientes, vendedores, produtos e pagamentos do
período 2016 a 2018, respondendo a dez perguntas estratégicas de
negócio.

O modelo segue o padrão **Esquema Estrela**: tabelas fato no centro
conectadas a dimensões ao redor. Toda a transformação de dados ocorre no
SQL Server via T-SQL. A visualização é feita no Power BI, que consome
diretamente as visões e os procedimentos analíticos do banco.

  ----------------- ----------------- ----------------- -----------------
  **Tabelas Fato**  **Dimensões**     **Área de Pouso** **Controle**

  **4 tabelas**     **10 tabelas**    **1 tabela**      **1 tabela**

  200.000+          \~140.000         Temporária        Auditoria ETL
  registros         registros                           
  ----------------- ----------------- ----------------- -----------------

**2 Tecnologias Utilizadas**

**SQL Server --- Microsoft**

Banco de dados relacional onde todo o processamento acontece. O dialeto
usado é o **T-SQL** (Transact-SQL), que permite criar rotinas
automatizadas, regras de negócio direto no banco e uma camada de
segurança por perfil de usuário.

  -------------------- --------------------------------------------------
  **Recurso**          **Uso no projeto**

  **Schemas (dw / stg  Organização em três camadas: dados prontos, área
  / ctrl)**            de pouso e auditoria

  **Procedimentos      Rotinas de carga automatizada, transformação de
  Armazenados**        dados e relatórios com parâmetros

  **Visões (Views)**   Camada de acesso simplificada para o Power BI, sem
                       expor os relacionamentos internos

  **Funções**          Cálculos reutilizáveis: crescimento mensal e dias
                       úteis de entrega

  **Gatilhos           Auditoria automática de cargas e validação de
  (Triggers)**         regras de negócio

  **Controle de Acesso Permissões por perfil de usuário: analista,
  (DCL)**              engenheiro de dados e administrador
  -------------------- --------------------------------------------------

**Power BI --- Microsoft**

Ferramenta de inteligência de negócios usada na camada de visualização.
O Power BI conecta-se diretamente ao SQL Server e consome as visões e
procedimentos analíticos para gerar painéis interativos. Nenhum dado é
transformado no Power BI --- tudo já chega tratado do banco.

  -------------------- --------------------------------------------------
  **Recurso**          **Como é utilizado**

  **Conexão ao SQL     Driver nativo Microsoft. Modo Importação para
  Server**             dimensões, Consulta Direta para tabelas fato

  **Visões como fonte  As cinco visões do banco são consumidas
  de dados**           diretamente como tabelas no Power BI

  **Medidas DAX**      Indicadores calculados: valor médio de pedido,
                       taxa de recompra, satisfação e crescimento
                       percentual

  **Relatórios         10 painéis correspondendo às 10 perguntas de
  interativos**        negócio do projeto
  -------------------- --------------------------------------------------

**3 Fontes de Dados**

Os dados vêm de duas fontes públicas: o dataset da Olist no Kaggle e a
API aberta do Banco Central do Brasil.

**Olist --- Kaggle**

**Acesso:** https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

Formato: CSV · Período: 2016--2018 · Licença: CC BY-NC-SA 4.0 · Acesso:
gratuito, requer cadastro no Kaggle

+-----------------------------------------------------------------------+
| **olist_orders_dataset** olist_orders_dataset.csv \| **\~99.441       |
| pedidos**                                                             |
|                                                                       |
| Tabela central. Cada linha é um pedido com status, datas de compra,   |
| aprovação, envio e entrega. Origem das flags de cancelamento e        |
| cálculo de atrasos.                                                   |
|                                                                       |
| **Colunas:** order_id, customer_id, order_status,                     |
| order_purchase_timestamp, order_delivered_customer_date,              |
| order_estimated_delivery_date                                         |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **olist_order_items_dataset** olist_order_items_dataset.csv \|        |
| **\~112.650 itens**                                                   |
|                                                                       |
| Detalha os itens de cada pedido: produto, vendedor, preço e frete. Um |
| pedido com três produtos gera três linhas aqui --- origem da          |
| granularidade de 200.000+ registros na fato.                          |
|                                                                       |
| **Colunas:** order_id, order_item_id, product_id, seller_id, price,   |
| freight_value, shipping_limit_date                                    |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **olist_order_payments_dataset** olist_order_payments_dataset.csv \|  |
| **\~103.886 pagamentos**                                              |
|                                                                       |
| Transações de pagamento por pedido. Um pedido pode ter múltiplas      |
| linhas (cartão + voucher, por exemplo). Fonte principal para Q1.      |
|                                                                       |
| **Colunas:** order_id, payment_sequential, payment_type,              |
| payment_installments, payment_value                                   |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **olist_order_reviews_dataset** olist_order_reviews_dataset.csv \|    |
| **\~100.330 avaliações**                                              |
|                                                                       |
| Avaliações dos clientes após a entrega: nota de 1 a 5, título e       |
| comentário. Fonte para Q10 e análise de correlação entre atraso e     |
| insatisfação.                                                         |
|                                                                       |
| **Colunas:** review_id, order_id, review_score, review_comment_title, |
| review_comment_message                                                |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **olist_customers_dataset** olist_customers_dataset.csv \| **\~99.441 |
| clientes**                                                            |
|                                                                       |
| Dados geográficos dos compradores. O customer_unique_id identifica o  |
| comprador real entre pedidos distintos --- essencial para taxa de     |
| recompra (Q2).                                                        |
|                                                                       |
| **Colunas:** customer_id, customer_unique_id,                         |
| customer_zip_code_prefix, customer_city, customer_state               |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **olist_sellers_dataset** olist_sellers_dataset.csv \| **\~3.095      |
| vendedores**                                                          |
|                                                                       |
| Dados dos parceiros do marketplace. Permite análise de receita por    |
| vendedor (Q9) e cruzamento logístico com localização do cliente.      |
|                                                                       |
| **Colunas:** seller_id, seller_zip_code_prefix, seller_city,          |
| seller_state                                                          |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **olist_products_dataset** olist_products_dataset.csv \| **\~32.951   |
| produtos**                                                            |
|                                                                       |
| Catálogo de produtos com categoria e atributos físicos (peso,         |
| dimensões). Fonte para análise de receita por categoria (Q5).         |
|                                                                       |
| **Colunas:** product_id, product_category_name, product_weight_g,     |
| product_length_cm, product_height_cm, product_width_cm                |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **product_category_name_translation**                                 |
| product_category_name_translation.csv \| **\~71 categorias**          |
|                                                                       |
| Tradução dos nomes de categoria do português para o inglês. Popula a  |
| dim_categorias.                                                       |
|                                                                       |
| **Colunas:** product_category_name, product_category_name_english     |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **olist_geolocation_dataset** olist_geolocation_dataset.csv \|        |
| **\~1.000.163 registros**                                             |
|                                                                       |
| Mapeamento de prefixos de CEP para coordenadas geográficas. Permite   |
| mapas de calor no Power BI e enriquecimento geográfico de clientes e  |
| vendedores.                                                           |
|                                                                       |
| **Colunas:** geolocation_zip_code_prefix, geolocation_lat,            |
| geolocation_lng, geolocation_city, geolocation_state                  |
+-----------------------------------------------------------------------+

**Banco Central do Brasil --- API Pública**

**Acesso:**
https://dadosabertos.bcb.gov.br/dataset/estatisticas-pagamentos

Formato: API REST · Sem autenticação · Acesso: gratuito e aberto

+-----------------------------------------------------------------------+
| **Meios de Pagamento** API BCB --- Série Temporal \| **\~200          |
| registros mensais**                                                   |
|                                                                       |
| Volume e participação de cada meio de pagamento no Brasil (PIX,       |
| cartão, boleto, TED). Usado para comparar o perfil da Olist com o     |
| cenário nacional em Q1.                                               |
|                                                                       |
| **Colunas:** ano_referencia, mes_referencia, meio_pagamento,          |
| qtd_transacoes, valor_total_bilhoes, participacao_pct                 |
+-----------------------------------------------------------------------+

**4 Arquitetura --- Esquema Estrela**

O modelo segue o padrão Esquema Estrela, onde a tabela fato principal
fica no centro e as dimensões ao redor. Cada dimensão responde a uma
pergunta de contexto: *quem* comprou? *o quê*? *quando*? *onde*? *como*
pagou?

  ----------------- -----------------------------------------------------
  **Camada**        **Responsabilidade**

  stg. Área de      Recebe os arquivos brutos sem validação. Todos os
  Pouso             campos chegam como texto.

  dw. Dimensões     Armazenam os atributos descritivos: quem, o quê,
                    quando, onde, como.

  dw. Fato          Eventos de negócio com medidas numéricas e FKs para
                    as dimensões.

  ctrl. Controle    Registra cada execução do ETL: quando, quem, quantos
                    registros, resultado.
  ----------------- -----------------------------------------------------

**Fluxo de dados:** CSV → stg.stg_orders_raw → Procedimentos de Carga →
dw.dim\_\* → dw.fato\_\* → Views → Power BI

**5 Tabelas Fato**

As tabelas fato registram os eventos de negócio. Cada linha é uma
ocorrência real: um item vendido, um pagamento, uma avaliação. Contêm
medidas numéricas e as chaves estrangeiras que as conectam às dimensões.

+-----------------------------------------------------------------------+
| dw.**fato_pedidos** --- Tabela Fato Principal \| **200.000+           |
| registros**                                                           |
|                                                                       |
| *Tabela central do DW. Granularidade: um item de pedido por linha.    |
| Concentra todas as medidas de valor, tempo e flags de negócio, além   |
| das FKs para todas as dimensões.*                                     |
+-----------------------------------------------------------------------+

  -----------------------------------------------------------------------------
  **Coluna**          **Tipo de       **O que armazena**
                      Dado**          
  ------------------- --------------- -----------------------------------------
  fato_id             BIGINT          Chave primária gerada automaticamente
                                      pelo SQL Server.

  order_id            VARCHAR(50)     ID do pedido. Um pedido com três itens
                                      gera três linhas com o mesmo order_id.

  order_item_seq      TINYINT         Sequência do item no pedido (1, 2,
                                      3\...). Junto com order_id forma a chave
                                      natural.

  cliente_id          VARCHAR(50)     Chave estrangeira → dim_clientes. Liga a
                                      venda ao comprador e sua localização.

  vendedor_id         VARCHAR(50)     Chave estrangeira → dim_vendedores. Liga
                                      o item ao parceiro que realizou a venda.

  produto_id          VARCHAR(50)     Chave estrangeira → dim_produtos. Liga o
                                      item ao produto e sua categoria.

  pagamento_id        TINYINT         Chave estrangeira → dim_forma_pagamento.
                                      Como o pedido foi pago.

  status_id           TINYINT         Chave estrangeira → dim_status_pedido.
                                      Estado atual do pedido.

  tempo_compra_id     INT             Chave estrangeira → dim_tempo. Data da
                                      compra no formato YYYYMMDD.

  tempo_entrega_id    INT             Chave estrangeira → dim_tempo. Data de
                                      entrega real. Nulo em pedidos não
                                      entregues.

  motivo_cancel_id    TINYINT         Chave estrangeira →
                                      dim_motivo_cancelamento. Preenchido
                                      apenas quando fl_cancelado = 1.

  vlr_produto         DECIMAL(10,2)   Preço unitário do produto em reais.

  vlr_frete           DECIMAL(10,2)   Valor do frete cobrado pelo item.

  vlr_total           DECIMAL(10,2)   Calculado pelo ETL: vlr_produto +
                                      vlr_frete.

  dias_para_entrega   INT             Dias corridos entre a compra e a entrega
                                      real.

  atraso_dias         INT             Diferença entre prazo estimado e data
                                      real. Positivo = atraso.

  fl_cancelado        BIT             1 se o pedido foi cancelado.

  fl_entregue         BIT             1 se o pedido foi entregue com sucesso.

  fl_atraso           BIT             1 se a entrega ocorreu após a data
                                      estimada.

  dt_carga            DATETIME        Momento em que o registro foi inserido
                                      pelo ETL.
  -----------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**fato_itens_pedido** --- Tabela Fato \| **\~115.000 registros**   |
|                                                                       |
| *Detalha cada item de pedido com foco em produto, vendedor e preço.   |
| Base para análise de receita por categoria (Q5) e ranking de          |
| vendedores (Q9).*                                                     |
+-----------------------------------------------------------------------+

  -----------------------------------------------------------------------------
  **Coluna**          **Tipo de       **O que armazena**
                      Dado**          
  ------------------- --------------- -----------------------------------------
  item_id             BIGINT          Chave primária técnica.

  order_id            VARCHAR(50)     ID do pedido. Permite Relacionamento com
                                      fato_pedidos para cruzar informações de
                                      status e cliente.

  order_item_seq      TINYINT         Sequência do item. Junto com order_id
                                      identifica o registro.

  produto_id          VARCHAR(50)     Chave estrangeira → dim_produtos. Coluna
                                      principal para análise por categoria.

  vendedor_id         VARCHAR(50)     Chave estrangeira → dim_vendedores. Soma
                                      do preço agrupada por vendedor = receita
                                      por vendedor.

  tempo_compra_id     INT             Chave estrangeira → dim_tempo. Permite
                                      filtros por período.

  preco               DECIMAL(10,2)   Preço unitário do produto. Base de todas
                                      as análises de receita.

  frete_valor         DECIMAL(10,2)   Frete do item. Analisado separado da
                                      receita do produto.

  data_limite_envio   DATE            Prazo máximo para postagem pelo vendedor.
  -----------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**fato_pagamentos** --- Tabela Fato \| **\~103.000 registros**     |
|                                                                       |
| *Registra cada transação de pagamento. Um pedido pode ter múltiplas   |
| linhas (cartão + voucher). Fonte principal para Q1.*                  |
+-----------------------------------------------------------------------+

  ----------------------------------------------------------------------------
  **Coluna**         **Tipo de       **O que armazena**
                     Dado**          
  ------------------ --------------- -----------------------------------------
  pgto_seq_id        BIGINT          Chave primária técnica.

  order_id           VARCHAR(50)     ID do pedido associado ao pagamento.

  pagamento_seq      TINYINT         Sequência quando o pedido tem múltiplas
                                     formas de pagamento.

  pagamento_id       TINYINT         Chave estrangeira → dim_forma_pagamento.
                                     Contagem agrupada por tipo = resposta da
                                     Q1.

  parcelas           TINYINT         Número de parcelas. 1 = à vista.

  valor              DECIMAL(10,2)   Valor pago nessa transação.
  ----------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**fato_avaliacoes** --- Tabela Fato \| **\~100.000 registros**     |
|                                                                       |
| *Avaliações dos clientes após a entrega. Nota de 1 a 5 e comentário.  |
| Fonte para Q10 e correlação entre atraso e nota baixa.*               |
+-----------------------------------------------------------------------+

  ----------------------------------------------------------------------------
  **Coluna**          **Tipo de      **O que armazena**
                      Dado**         
  ------------------- -------------- -----------------------------------------
  review_id           VARCHAR(50)    ID único da avaliação, chave natural
                                     vinda do CSV da Olist.

  order_id            VARCHAR(50)    Pedido avaliado. Relacionamento com
                                     fato_pedidos conecta a nota ao produto e
                                     ao vendedor.

  nota                TINYINT        Nota de 1 a 5. Média da nota agrupada por
                                     vendedor = satisfação por vendedor (Q10).

  titulo_review       VARCHAR(100)   Título curto da avaliação. Pode ser nulo.

  comentario          VARCHAR(MAX)   Texto completo do comentário. Campo
                                     livre.

  tempo_compra_id     INT            Chave estrangeira → dim_tempo. Análise de
                                     satisfação ao longo do tempo.

  dt_envio_pesquisa   DATETIME       Data em que a Olist enviou o e-mail de
                                     pesquisa.

  fl_nota_negativa    BIT            1 se nota \<= 2. Filtro rápido de
                                     insatisfação.
  ----------------------------------------------------------------------------

**6 Tabelas Dimensão**

As dimensões fornecem contexto aos eventos das tabelas fato. Cada uma
responde a uma pergunta específica: quem comprou, o que foi vendido,
quando, onde, como foi pago e em que estado o pedido se encontra.

+-----------------------------------------------------------------------+
| dw.**dim_clientes** --- Dimensão \| **\~100.000 registros**           |
|                                                                       |
| *Dados geográficos dos compradores. O customer_unique_id identifica o |
| comprador real entre pedidos distintos --- essencial para calcular    |
| taxa de recompra (Q2).*                                               |
+-----------------------------------------------------------------------+

  ----------------------------------------------------------------------------
  **Coluna**          **Tipo de      **O que armazena**
                      Dado**         
  ------------------- -------------- -----------------------------------------
  cliente_id          VARCHAR(50)    Chave primária. Hash por pedido, gerado
                                     pela Olist.

  cliente_unique_id   VARCHAR(50)    ID real do comprador. O mesmo cliente
                                     pode ter vários customer_ids em pedidos
                                     diferentes.

  cep_prefixo         VARCHAR(10)    5 primeiros dígitos do CEP. Permite
                                     relacionamento com dim_geolocalizacao.

  cidade              VARCHAR(100)   Cidade do endereço de entrega.

  estado              CHAR(2)        UF do cliente. Principal coluna para Q3.
  ----------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**dim_vendedores** --- Dimensão \| **\~3.000 registros**           |
|                                                                       |
| *Dados dos parceiros do marketplace. Permite análise de performance   |
| regional e ranking de receita.*                                       |
+-----------------------------------------------------------------------+

  ---------------------------------------------------------------------------
  **Coluna**         **Tipo de      **O que armazena**
                     Dado**         
  ------------------ -------------- -----------------------------------------
  vendedor_id        VARCHAR(50)    Chave primária. Hash anonimizado do
                                    vendedor.

  cep_prefixo        VARCHAR(10)    Prefixo do CEP. Permite análise logística
                                    por proximidade ao cliente.

  cidade             VARCHAR(100)   Cidade do vendedor.

  estado             CHAR(2)        UF do vendedor. Cruzado com estado do
                                    cliente para análise logística.
  ---------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**dim_produtos** --- Dimensão \| **\~33.000 registros**            |
|                                                                       |
| *Catálogo de produtos com categoria e dimensões físicas. A coluna     |
| nome_categoria_pt foi desnormalizada aqui para evitar JOINs extras em |
| queries simples.*                                                     |
+-----------------------------------------------------------------------+

  ----------------------------------------------------------------------------
  **Coluna**          **Tipo de      **O que armazena**
                      Dado**         
  ------------------- -------------- -----------------------------------------
  produto_id          VARCHAR(50)    Chave primária. Hash anonimizado do
                                     produto.

  categoria_id        SMALLINT       Chave estrangeira → dim_categorias.

  nome_categoria_pt   VARCHAR(100)   Nome da categoria em português.
                                     Desnormalizado para performance.

  peso_gramas         INT            Peso do produto. Impacta diretamente no
                                     valor do frete.

  comprimento_cm      DECIMAL(8,2)   Comprimento em centímetros.

  altura_cm           DECIMAL(8,2)   Altura em centímetros.

  largura_cm          DECIMAL(8,2)   Largura em centímetros.
  ----------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**dim_categorias** --- Dimensão --- Domínio \| **\~74 registros**  |
|                                                                       |
| *Nomes das categorias em português e inglês. Separada de dim_produtos |
| para evitar repetição em 33.000 linhas.*                              |
+-----------------------------------------------------------------------+

  ----------------------------------------------------------------------------
  **Coluna**          **Tipo de      **O que armazena**
                      Dado**         
  ------------------- -------------- -----------------------------------------
  categoria_id        SMALLINT       Chave primária surrogate gerada pelo SQL
                                     Server.

  nome_categoria_pt   VARCHAR(100)   Nome original em português, como veio do
                                     CSV.

  nome_categoria_en   VARCHAR(100)   Tradução para inglês.
  ----------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**dim_forma_pagamento** --- Dimensão --- Domínio \| **\~6          |
| registros**                                                           |
|                                                                       |
| *Tipos de pagamento aceitos no marketplace. Pequena mas central ---   |
| responde diretamente a Q1.*                                           |
+-----------------------------------------------------------------------+

  ------------------------------------------------------------------------------
  **Coluna**             **Tipo de     **O que armazena**
                         Dado**        
  ---------------------- ------------- -----------------------------------------
  pagamento_id           TINYINT       Chave primária surrogate numérica pequena
                                       para JOINs eficientes.

  tipo_pagamento         VARCHAR(30)   Código original do CSV: credit_card,
                                       boleto, voucher, debit_card, pix.

  descricao_pt           VARCHAR(50)   Rótulo amigável em português para
                                       relatórios.

  permite_parcelamento   BIT           1 para cartão de crédito, 0 para os
                                       demais meios.
  ------------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**dim_tempo** --- Dimensão Calendário \| **\~1.095 registros       |
| (2016--2018)**                                                        |
|                                                                       |
| *Calendário gerado por script SQL, não vindo de CSV. Cada linha é um  |
| dia do período. Permite análises temporais eficientes sem funções de  |
| data nas queries.*                                                    |
+-----------------------------------------------------------------------+

  --------------------------------------------------------------------------
  **Coluna**         **Tipo de     **O que armazena**
                     Dado**        
  ------------------ ------------- -----------------------------------------
  tempo_id           INT           Chave primária no formato YYYYMMDD. As
                                   fatos armazenam datas neste formato para
                                   JOIN direto.

  data_completa      DATE          A data real no tipo DATE do SQL Server.

  ano                SMALLINT      Ano (2016, 2017, 2018). GROUP BY ano =
                                   análise anual.

  trimestre          TINYINT       Trimestre do ano (1 a 4).

  mes                TINYINT       Mês numérico (1 a 12). Principal coluna
                                   para Q4 e Q6.

  nome_mes           VARCHAR(20)   Nome do mês em português para relatórios.

  dia_semana         TINYINT       Dia da semana (1 = domingo a 7 = sábado).

  eh_fim_semana      BIT           1 se sábado ou domingo. Usado para
                                   calcular dias úteis de entrega.

  eh_feriado         BIT           1 se feriado nacional. Inicialmente 0,
                                   pode ser atualizado manualmente.
  --------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**dim_status_pedido** --- Dimensão --- Domínio \| **\~8            |
| registros**                                                           |
|                                                                       |
| *Status possíveis de um pedido. Permite adicionar atributos de        |
| negócio sem alterar a tabela fato.*                                   |
+-----------------------------------------------------------------------+

  --------------------------------------------------------------------------
  **Coluna**         **Tipo de     **O que armazena**
                     Dado**        
  ------------------ ------------- -----------------------------------------
  status_id          TINYINT       Chave primária surrogate.

  codigo_status      VARCHAR(30)   Código original: delivered, canceled,
                                   shipped, processing, approved\...

  descricao_pt       VARCHAR(60)   Descrição em português para relatórios.

  eh_status_final    BIT           1 se o status é terminal. Usado pelo
                                   Trigger de validação de transições.

  eh_cancelamento    BIT           1 especificamente para cancelamentos.
  --------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**dim_motivo_cancelamento** --- Dimensão --- Domínio \| **\~7      |
| registros**                                                           |
|                                                                       |
| *Motivos de cancelamento inferidos pelo ETL a partir de padrões nos   |
| dados. Não existe no CSV original. Responde Q8.*                      |
+-----------------------------------------------------------------------+

  ---------------------------------------------------------------------------
  **Coluna**         **Tipo de      **O que armazena**
                     Dado**         
  ------------------ -------------- -----------------------------------------
  motivo_id          TINYINT        Chave primária surrogate.

  codigo_motivo      VARCHAR(50)    Código interno: sem_pagamento,
                                    cancelamento_cliente,
                                    produto_indisponivel\...

  descricao          VARCHAR(100)   Descrição completa do motivo para
                                    relatórios.
  ---------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**dim_geolocalizacao** --- Dimensão \| **\~1.000.000 registros**   |
|                                                                       |
| *Maior dimensão do projeto. Mapeia prefixos de CEP para coordenadas   |
| geográficas. Permite mapas de calor no Power BI.*                     |
+-----------------------------------------------------------------------+

  ----------------------------------------------------------------------------
  **Coluna**         **Tipo de       **O que armazena**
                     Dado**          
  ------------------ --------------- -----------------------------------------
  geo_id             INT             Chave primária surrogate.

  cep_prefixo        VARCHAR(10)     5 primeiros dígitos do CEP. Coluna de
                                     relacionamento com dim_clientes e
                                     dim_vendedores.

  latitude           DECIMAL(10,6)   Latitude geográfica para mapas no Power
                                     BI.

  longitude          DECIMAL(10,6)   Longitude geográfica.

  cidade             VARCHAR(100)    Cidade do CEP.

  estado             CHAR(2)         UF do CEP.

  regiao             VARCHAR(20)     Região do Brasil calculada pelo ETL com
                                     base no estado.
  ----------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| dw.**dim_meios_pagamento_bcb** --- Dimensão --- Enriquecimento \|     |
| **\~200 registros**                                                   |
|                                                                       |
| *Dados do Banco Central do Brasil. Sem FK com as fatos --- usada para |
| comparar o perfil da Olist com o cenário nacional em Q1.*             |
+-----------------------------------------------------------------------+

  -------------------------------------------------------------------------------
  **Coluna**            **Tipo de       **O que armazena**
                        Dado**          
  --------------------- --------------- -----------------------------------------
  bcb_id                INT             Chave primária surrogate.

  ano_referencia        SMALLINT        Ano dos dados.

  mes_referencia        TINYINT         Mês de referência (1--12).

  meio_pagamento        VARCHAR(50)     Tipo: PIX, TED, Cartão Crédito,
                                        Boleto\...

  qtd_transacoes        BIGINT          Volume de transações no Brasil naquele
                                        mês.

  valor_total_bilhoes   DECIMAL(18,4)   Valor movimentado em bilhões de reais.

  participacao_pct      DECIMAL(5,2)    Participação percentual no total
                                        nacional.
  -------------------------------------------------------------------------------

**7 Tabelas de Apoio**

Duas tabelas que sustentam o processo ETL sem armazenar dados de
negócio: a área de pouso dos CSVs e o log de auditoria.

+-----------------------------------------------------------------------+
| stg.**stg_orders_raw** --- Área de Pouso --- Dados Brutos \|          |
| **Temporária, limpa após cada carga**                                 |
|                                                                       |
| *Recebe os CSVs exatamente como foram exportados. Todos os campos     |
| chegam como VARCHAR para que nenhum dado seja rejeitado na entrada. O |
| ETL lê daqui, valida, transforma e carrega nas tabelas definitivas.*  |
+-----------------------------------------------------------------------+

  ----------------------------------------------------------------------------------------
  **Coluna**                      **Tipo de      **O que armazena**
                                  Dado**         
  ------------------------------- -------------- -----------------------------------------
  stg_id                          BIGINT         Chave primária técnica da staging.

  order_id                        VARCHAR(50)    ID do pedido como veio do arquivo. Pode
                                                 ter duplicatas, tratadas pelo processo de
                                                 carga.

  customer_id                     VARCHAR(50)    ID do cliente bruto. Convertido para
                                                 chave estrangeira de dim_clientes pelo
                                                 processo de carga.

  order_status                    VARCHAR(30)    Status bruto: delivered, canceled\...
                                                 Convertido para status_id no processo de
                                                 carga.

  order_purchase_timestamp        VARCHAR(30)    Data da compra como texto. O processo de
                                                 carga converte para data e depois para o
                                                 formato AAAAMMDD.

  order_delivered_customer_date   VARCHAR(30)    Data de entrega como texto. Nulo para
                                                 pedidos não entregues.

  order_estimated_delivery_date   VARCHAR(30)    Prazo estimado de entrega. Comparado com
                                                 a data real para calcular atraso.

  product_id                      VARCHAR(50)    ID do produto bruto. Resolvido como FK
                                                 para dim_produtos.

  seller_id                       VARCHAR(50)    ID do vendedor bruto. Resolvido como FK
                                                 para dim_vendedores.

  price                           VARCHAR(20)    Preço como texto. O ETL faz REPLACE e
                                                 CAST para DECIMAL.

  freight_value                   VARCHAR(20)    Frete como texto. Mesmo tratamento do
                                                 price.

  payment_type                    VARCHAR(30)    Tipo de pagamento bruto. Mapeado para
                                                 pagamento_id.

  payment_value                   VARCHAR(20)    Valor do pagamento como texto.

  dt_carga                        DATETIME       Data e hora de chegada do registro na
                                                 área de pouso. Preenchido automaticamente
                                                 pelo banco.

  fl_processado                   BIT            0 = aguardando processamento. 1 =
                                                 processado com sucesso pelo processo de
                                                 carga.

  fl_erro                         BIT            1 se houve problema durante o
                                                 processamento. A mensagem de erro detalha
                                                 o ocorrido.

  msg_erro                        VARCHAR(500)   Detalhe do erro. Nulo quando o
                                                 processamento ocorre sem problemas.
  ----------------------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| ctrl.**log_etl** --- Controle --- Auditoria ETL \| **Cresce a cada    |
| execução**                                                            |
|                                                                       |
| *Registro de auditoria do processo de carga. Grava automaticamente    |
| cada execução de procedimento e gatilho: quando rodou, o que foi      |
| carregado, quantos registros, quem executou e qual foi o resultado.   |
| Não contém dados de negócio.*                                         |
+-----------------------------------------------------------------------+

  ---------------------------------------------------------------------------
  **Coluna**         **Tipo de      **O que armazena**
                     Dado**         
  ------------------ -------------- -----------------------------------------
  log_id             INT            Chave primária sequencial de cada entrada
                                    de log.

  tabela_destino     VARCHAR(100)   Nome completo da tabela de destino que
                                    recebeu os dados. Exemplo:
                                    dw.fato_pedidos.

  sp_executada       VARCHAR(100)   Nome do procedimento ou gatilho que gerou
                                    o registro de log.

  dt_inicio          DATETIME       Timestamp de início da execução.

  dt_fim             DATETIME       Data e hora de conclusão. Nulo se ainda
                                    em execução ou em caso de falha grave.

  qtd_inseridos      INT            Registros efetivamente inseridos na
                                    tabela destino.

  usuario            VARCHAR(100)   Usuário que executou o processo,
                                    capturado automaticamente pelo SQL
                                    Server.

  status             VARCHAR(20)    INICIADO → SUCESSO ou ERRO. Registro
                                    permanente como INICIADO indica falha
                                    grave no servidor.

  mensagem_erro      VARCHAR(MAX)   Mensagem detalhada do erro quando o
                                    status é ERRO. Vazio quando a execução
                                    ocorre sem problemas.
  ---------------------------------------------------------------------------

**8 Tipos de Dados Utilizados**

Cada coluna do banco foi definida com um tipo de dado específico do SQL
Server. A escolha do tipo afeta diretamente o espaço em disco, a
performance das queries e o que pode ser armazenado. Abaixo estão
explicados todos os tipos usados no projeto.

**Tipos Numéricos Inteiros**

  ------------ ------------- --------------- ----------------------------------
  **Tipo**     **Tamanho**   **Intervalo**   **Onde é usado no projeto**

  TINYINT      1 byte        0 a 255         IDs de domínio pequenos:
                                             pagamento_id, status_id,
                                             motivo_id, sequências, notas de
                                             avaliação (1--5)

  SMALLINT     2 bytes       --32.768 a      categoria_id, ano na dim_tempo,
                             32.767          campos de ano em geral

  INT          4 bytes       --2 bi a +2 bi  tempo_id (formato YYYYMMDD),
                                             geo_id, log_id, qtd_inseridos no
                                             log_etl

  BIGINT       8 bytes       --9 qua a +9    fato_id, item_id, pgto_seq_id ---
                             qua             chaves primárias das tabelas fato
                                             com volume alto. qtd_transacoes na
                                             dim BCB
  ------------ ------------- --------------- ----------------------------------

**Tipos Numéricos Decimais**

  --------------- --------------- -----------------------------------------
  **Tipo**        **Precisão**    **Onde é usado no projeto**

  DECIMAL(10,2)   10 dígitos, 2   vlr_produto, vlr_frete, vlr_total, preco,
                  casas           frete_valor, valor (pagamentos) --- todos
                                  os valores monetários em reais

  DECIMAL(8,2)    8 dígitos, 2    comprimento_cm, altura_cm, largura_cm ---
                  casas           dimensões físicas dos produtos

  DECIMAL(10,6)   10 dígitos, 6   latitude e longitude na
                  casas           dim_geolocalizacao --- precisão
                                  necessária para mapas

  DECIMAL(18,4)   18 dígitos, 4   valor_total_bilhoes na dim BCB ---
                  casas           valores de grande magnitude com precisão
                                  decimal

  DECIMAL(5,2)    5 dígitos, 2    participacao_pct na dim BCB ---
                  casas           percentuais de 0,00 a 100,00
  --------------- --------------- -----------------------------------------

**Por que DECIMAL e não ponto flutuante??** O tipo de ponto flutuante é
aproximado --- pode introduzir erros de arredondamento em operações
financeiras. O DECIMAL é exato, o que é obrigatório para valores
monetários.

**Tipos de Texto**

  -------------- -------------------- -----------------------------------------
  **Tipo**       **Característica**   **Onde é usado no projeto**

  VARCHAR(n)     Tamanho variável até Maioria das colunas de texto: IDs dos
                 n                    CSVs (50), nomes de cidades e categorias
                                      (100), mensagens de erro (500), códigos
                                      de status (30). Ocupa só o espaço
                                      necessário.

  CHAR(2)        Tamanho fixo 2       estado --- sempre dois caracteres (SP,
                                      RJ, MG). Fixo é mais eficiente quando o
                                      tamanho nunca varia.

  VARCHAR(MAX)   Até 2 GB             comentario na fato_avaliacoes e
                                      mensagem_erro no log_etl --- textos de
                                      tamanho imprevisível.
  -------------- -------------------- -----------------------------------------

**Tipos de Data e Hora**

  -------------- --------------- -----------------------------------------
  **Tipo**       **Precisão**    **Onde é usado no projeto**

  DATE           Somente data    data_completa na dim_tempo e
                                 data_limite_envio na fato_itens ---
                                 quando o horário não importa.

  DATETIME       Data + hora     dt_carga em todas as tabelas, dt_inicio e
                 (ms)            dt_fim no log_etl, dt_envio_pesquisa na
                                 fato_avaliacoes --- quando o horário
                                 exato é relevante para auditoria.
  -------------- --------------- -----------------------------------------

**Por que as datas nas tabelas fato são números inteiros e não datas??**
As chaves estrangeiras para dim_tempo usam o formato AAAAMMDD como
número inteiro (exemplo: 20171015) porque a comparação entre inteiros é
mais rápida que entre datas, e permite filtros diretos por ano e mês sem
conversão: WHERE tempo_compra_id BETWEEN 20170101 AND 20171231.

**Tipo Lógico**

  -------------- --------------- -----------------------------------------
  **Tipo**       **Valores**     **Onde é usado no projeto**

  BIT            0 ou 1          Todas as flags: fl_cancelado,
                                 fl_entregue, fl_atraso, fl_avaliado,
                                 fl_nota_negativa, fl_processado, fl_erro,
                                 eh_fim_semana, eh_feriado,
                                 eh_cancelamento, permite_parcelamento.
  -------------- --------------- -----------------------------------------

O tipo BIT ocupa apenas 1 bit de armazenamento. Marcadores BIT são muito
mais eficientes que texto (\'S\'/\'N\') e permitem filtros rápidos nas
tabelas fato sem relacionamentos adicionais.

**9 Objetos T-SQL**

Além das tabelas, o banco contém objetos programáveis que automatizam a
carga de dados, garantem a integridade das informações e facilitam o
consumo pelo Power BI.

**Visões (Views)**

  -------------------------- --------------------------------------------------
  **Visão**                  **O que entrega**

  vw_pedidos_completos       Relacionamento central com todas as dimensões.
                             Base para Q1 e Q3. Principal fonte do Power BI.

  vw_receita_por_categoria   Receita agregada por categoria de produto.
                             Responde Q5 diretamente.

  vw_vendas_por_mes          Volume de vendas e receita por ano e mês. Base
                             para Q4 (sazonalidade) e Q6 (crescimento mensal).

  vw_satisfacao_clientes     Média de notas por vendedor, categoria e período.
                             Responde Q10.

  vw_status_entregas         Tempo médio de entrega e cancelamentos por estado.
                             Responde Q7 e Q8.
  -------------------------- --------------------------------------------------

**Procedimentos Armazenados**

  ------------------------- ----------- ----------------------------------------
  **Procedimento**          **Tipo**    **Função**

  sp_seed_dimensoes         Carga       Popula dimensões estáticas via MERGE:
                                        status, motivo, forma de pagamento.

  sp_gerar_dim_tempo        Carga       Gera o calendário 2016--2018 com loop.
                                        Preenche todos os atributos de data.

  sp_carga_dim_clientes     Carga       Carrega dim_clientes com atualização no
                                        estilo substituição direta. Evita
                                        duplicatas automaticamente.

  sp_carga_fato_pedidos     Carga       Procedimento principal de carga. Lê a
                                        área de pouso, resolve chaves
                                        estrangeiras, calcula colunas derivadas
                                        e gerencia transações.

  sp_inserir_avaliacao      Escrita     Insere avaliações com validação de nota
                                        (1--5) e controle de duplicidade.

  sp_relatorio_vendedores   Analítica   Ranking de vendedores. Parâmetros:
                                        \@data_inicio, \@data_fim, \@top_n.
                                        Responde Q9.

  sp_analise_recompra       Analítica   Calcula taxa de recompra por
                                        cliente_unique_id usando CTE. Responde
                                        Q2.
  ------------------------- ----------- ----------------------------------------

**Funções e Gatilhos**

  -------------------------- ---------- ----------------------------------------
  **Objeto**                 **Tipo**   **Função**

  fn_calcular_mom            Função     Recebe \@ano e \@mes, retorna
                                        crescimento percentual em relação ao mês
                                        anterior.

  fn_tempo_entrega_dias      Função     Conta dias úteis entre compra e entrega
                                        consultando dim_tempo.

  trg_log_carga_fato         Gatilho    Disparado após inserção em fato_pedidos.
                                        Registra automaticamente no log de
                                        auditoria.

  trg_valida_status_pedido   Gatilho    Disparado após atualização. Bloqueia
                                        mudanças de status em pedidos já
                                        finalizados.
  -------------------------- ---------- ----------------------------------------

**10 Camada de Visualização --- Power BI**

O Power BI conecta-se ao SQL Server e consome as visões e procedimentos
analíticos. Nenhuma transformação ocorre no Power BI --- os dados chegam
prontos do banco.

  -------------------- --------------------------------------------------
  **Relatório**        **Origem no SQL Server**

  **Formas de          fato_pagamentos + dim_forma_pagamento +
  Pagamento**          dim_meios_pagamento_bcb

  **Taxa de Recompra** sp_analise_recompra

  **Clientes por       vw_pedidos_completos + dim_geolocalizacao (mapa)
  Estado**             

  **Sazonalidade de    vw_vendas_por_mes
  Vendas**             

  **Receita por        vw_receita_por_categoria
  Categoria**          

  **Crescimento Mês a  fn_calcular_mom via vw_vendas_por_mes
  Mês**                

  **Tempo Médio de     vw_status_entregas
  Entrega**            

  **Motivos de         vw_status_entregas + dim_motivo_cancelamento
  Cancelamento**       

  **Ranking de         sp_relatorio_vendedores
  Vendedores**         

  **Satisfação de      vw_satisfacao_clientes
  Clientes**           
  -------------------- --------------------------------------------------

**11 Perguntas de Negócio Respondidas**

Cada pergunta tem uma fonte de dados definida no banco e um visual
correspondente no Power BI.

  --------- ----------------------------- -------------------------- -----------------
  **\#**    **Pergunta**                  **Fonte**                  **Painel no Power
                                                                     BI**

  **Q1**    Qual a forma de pagamento     fato_pagamentos +          Gráfico de barras
            mais usada?                   dim_forma_pagamento        

  **Q2**    Qual a taxa de recompra dos   sp_analise_recompra        KPI + tabela
            clientes?                                                

  **Q3**    Quais estados têm mais        vw_pedidos_completos +     Mapa coroplético
            clientes ativos?              dim_clientes               

  **Q4**    Quais meses têm mais volume   vw_vendas_por_mes          Gráfico de linha
            de vendas?                                               

  **Q5**    Quais categorias geram mais   vw_receita_por_categoria   Mapa de área /
            receita?                                                 barras

  **Q6**    Qual o crescimento mês a mês? fn_calcular_mom            Linha com
                                                                     variação %

  **Q7**    Qual o tempo médio de entrega vw_status_entregas         Mapa + ranking
            por estado?                                              

  **Q8**    Quais os principais motivos   fato_pedidos +             Barras
            de cancelamento?              dim_motivo_cancelamento    horizontais

  **Q9**    Quais vendedores geram mais   sp_relatorio_vendedores    Tabela top N
            receita?                                                 

  **Q10**   Qual a satisfação geral dos   vw_satisfacao_clientes     Gauge + tabela
            clientes?                                                
  --------- ----------------------------- -------------------------- -----------------
