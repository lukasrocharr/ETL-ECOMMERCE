# Documento de Especificação de Requisitos (SRS)
[cite_start]**Projeto Final:** Engenharia e Análise de Dados com T-SQL [cite: 1]
**Tema:** E-commerce (Análise de Funil e Comportamento do Consumidor)
[cite_start]**Fonte de Dados:** Kaggle ("eCommerce behavior data from multi category store") 

## 1. Visão Geral e Objetivos
[cite_start]O objetivo deste projeto é construir um processo de ETL robusto e um Data Warehouse otimizado no SQL Server usando exclusivamente T-SQL[cite: 1]. [cite_start]Transformaremos dados brutos de interações de e-commerce (eventos de navegação, carrinhos e compras) em insights de negócio acionáveis[cite: 2].

**Infraestrutura:** O banco de dados será hospedado em SQL Server (compatível com instâncias locais em Windows ou via contêiner Docker para ambientes de desenvolvimento Linux/Ubuntu).

## 2. Plano de Análise e Negócio
[cite_start]Antes da estruturação (DDL), definimos as seguintes perguntas de negócio que o modelo deve responder[cite: 17, 24]:
1. Qual é a taxa de conversão (Visualização -> Carrinho -> Compra) por categoria de produto?
2. Quais são os horários de pico (Deep Work/Navegação) com maior volume de abandono de carrinho?
3. Qual é o perfil de faturamento (LTV e Ticket Médio) das marcas mais visualizadas versus as mais compradas?

## 3. Modelagem Física e Escopo (20 Tabelas)
[cite_start]O modelo atende ao escopo mínimo de 20 tabelas e utiliza normalização adequada para dimensões[cite: 12, 40].

### 3.1. Tabelas de Dimensão (14 Tabelas)
1. **Dim_Usuario**: Dados do visitante/cliente extraídos das sessões.
2. **Dim_Produto**: Catálogo detalhado com especificações dos itens.
3. **Dim_Categoria**: Agrupamento macro dos produtos (ex: Eletrônicos, Vestuário).
4. **Dim_Subcategoria**: Nível secundário de classificação.
5. **Dim_Marca**: Fabricantes e marcas atreladas aos produtos.
6. **Dim_Tempo (Calendário)**: Tabela essencial para agregação temporal (Ano, Mês, Dia, Hora, Dia Útil).
7. **Dim_TipoEvento**: Dicionário de eventos (1 - *view*, 2 - *cart*, 3 - *purchase*).
8. **Dim_OrigemTrafego**: Canais de aquisição do usuário (Orgânico, Pago, Direto) inferidos das sessões.
9. **Dim_Geografia**: Localização macro dos usuários (caso derivado por IP/Região).
10. **Dim_MetodoPagamento**: Dicionário de transações.
11. **Dim_StatusTransacao**: Dicionário de status financeiros (Aprovado, Recusado, Pendente).
12. **Dim_FaixaPreco**: Categorização do produto por ticket (Baixo, Médio, Alto) para facilitar análises de cluster.
13. **Dim_Dispositivo**: Plataforma de acesso do usuário (Mobile, Desktop, Tablet).
14. **Dim_CampanhaPromo**: Mapeamento de possíveis ações de marketing em datas festivas.

### 3.2. Tabelas Fato (6 Tabelas)
15. **Fato_EventosNavegacao (Tabela Principal)**: Granularidade de hit/sessão. [cite_start]**Contará com >500.000 registros**, cumprindo o limite obrigatório.
16. **Fato_Pedido**: Tabela transacional gerada apenas para eventos do tipo *purchase*.
17. **Fato_ItemPedido**: Desmembramento da `Fato_Pedido` para garantir a 3FN em compras de múltiplos itens.
18. **Fato_AbandonoCarrinho**: Fato derivada calculada via ETL para registrar sessões que tiveram *cart* mas não *purchase*.
19. **Fato_Pagamento**: Registro transacional do faturamento.
20. **Audit_CargaETL**: Tabela gerencial de log para controle e auditoria do processo de DML.

## 4. Engenharia de Dados e Objetos T-SQL (Obrigatórios)
[cite_start]Para o processo de transformação e carga, implementaremos os seguintes objetos programáveis[cite: 15]:

* **Stored Procedures de ETL/CRUD (3)**:
  * [cite_start]`sp_ExtractKaggleData`: Realiza a leitura e conversão primária dos dados brutos em uma *staging area* usando métodos robustos de extração[cite: 44].
  * [cite_start]`sp_TransformEventos`: Limpeza de dados nulos, conversão de tipos de data/hora (Timezones)[cite: 45].
  * [cite_start]`sp_LoadFatoNavegacao`: Executa o particionamento e carga (DML) nas tabelas finais aplicando blocos transacionais (BEGIN TRAN, COMMIT) para atomicidade[cite: 52].
* **Stored Procedures Analíticas (2)**:
  * [cite_start]`sp_AnaliseFunilConversao`: Responde à pergunta 1 do negócio com agregações complexas[cite: 32].
  * [cite_start]`sp_AnaliseAbandonoHorario`: Responde à pergunta 2 cruzando a Fato com a `Dim_Tempo`[cite: 32].
* [cite_start]**Views (5)**[cite: 15]:
  * `vw_ReceitaPorMarca`, `vw_EngajamentoUsuario`, `vw_CatalogoCompleto`, `vw_ResumoDiarioEventos`, `vw_MonitoramentoCarga`.
* [cite_start]**Functions (2)**[cite: 15]:
  * `fn_CalcularSessaoMinutos`: Retorna o tempo em minutos entre o primeiro *view* e a *purchase*.
  * `fn_ClassificarTicket`: Classifica dinamicamente um valor monetário.
* [cite_start]**Triggers (2)**[cite: 15]:
  * [cite_start]`trg_AuditoriaPedidos`: Registra alterações ou exclusões não autorizadas na `Fato_Pedido`[cite: 33].
  * `trg_AtualizacaoPreco`: Grava log histórico caso o valor de um produto na `Dim_Produto` seja alterado.

## 5. Governança e Segurança (DCL)
[cite_start]O controle de acesso adotará o princípio do menor privilégio [cite: 53][cite_start], implementando as 3 Roles obrigatórias[cite: 16]:
1. **DBA_Admin**: Acesso total para operações de DDL e DCL.
2. **Eng_Dados**: Permissões de escrita restritas à execução (EXECUTE) das Procedures de ETL e manipulação (INSERT/UPDATE/DELETE) nas *staging areas*.
3. **Analista_BI**: Acesso estrito de leitura (SELECT) concedido apenas nas Views e execução nas Procedures Analíticas, sem visualização das tabelas transacionais de origem.

## 6. Cronograma de Entrega (Resumo Semanal)
[cite_start]A gestão será feita via Kanban no GitHub Projects[cite: 14], versionando este SRS e todos os artefatos de código.
* [cite_start]**Semanas 1-3:** Extração da amostra do Kaggle e finalização do Diagrama Entidade-Relacionamento (DER) completo[cite: 12].
* **Semanas 4-6:** Criação dos scripts DDL idempotentes [cite: 43] e execução da carga DML da tabela fato com +200k linhas[cite: 46].
* [cite_start]**Semanas 7-10:** Otimização (criação de Índices) [cite: 31] [cite_start]e codificação das Stored Procedures analíticas[cite: 32].
* **Semanas 11-13:** Documentação (Dicionário de Dados)  e formatação da defesa final, conectando um Dashboard de BI (Power BI/Metabase) à base T-SQL[cite: 19].