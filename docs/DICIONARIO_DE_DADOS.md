# Dicionário de Dados — EcommerceDW

Convenções: `*SK` = Surrogate Key (IDENTITY, PK) · `*BK`/`*ID` = chave natural (origem).
Schemas: `stg` (staging), `dim` (dimensões), `fato` (fatos), `dbo` (views/functions).

## Staging

### stg.EventosRaw — espelho do CSV bruto do Kaggle
| Coluna | Tipo | Descrição |
|---|---|---|
| event_time | NVARCHAR(40) | Data/hora do evento como texto (`yyyy-MM-dd HH:mm:ss UTC`). |
| event_type | NVARCHAR(20) | `view`, `cart` ou `purchase`. |
| product_id | NVARCHAR(30) | Identificador do produto (texto bruto). |
| category_id | NVARCHAR(30) | Identificador numérico da categoria. |
| category_code | NVARCHAR(200) | Caminho da categoria (`eletronics.smartphone`). |
| brand | NVARCHAR(100) | Marca (pode ser nula). |
| price | NVARCHAR(30) | Preço (texto bruto). |
| user_id | NVARCHAR(30) | Identificador do usuário. |
| user_session | NVARCHAR(80) | Identificador da sessão de navegação. |

### stg.EventosClean — dados tipados/enriquecidos (saída de `sp_TransformEventos`)
Mesmos campos tipados + `CategoriaNome`, `SubcategoriaNome`, `DataEvento`, `HoraDoDia`
e atributos inferidos `Dispositivo`, `OrigemTrafego`, `GeoPais`, `GeoRegiao`.

## Dimensões (14)

### dim.Dim_Categoria
| Coluna | Tipo | Chave | Descrição |
|---|---|---|---|
| CategoriaSK | INT IDENTITY | PK | Surrogate. |
| CategoriaNome | VARCHAR(100) | UNIQUE | 1º nível do `category_code`. |

### dim.Dim_Subcategoria
| CategoriaSK | INT | FK→Categoria | Categoria pai (floco-de-neve). |
| SubcategoriaNome | VARCHAR(100) | UNIQUE(c/ Cat) | Demais níveis do `category_code`. |

### dim.Dim_Marca
| MarcaSK | INT IDENTITY | PK | Surrogate. |
| MarcaNome | VARCHAR(100) | UNIQUE | Marca (`UNKNOWN` quando nula). |

### dim.Dim_FaixaPreco
| FaixaNome | VARCHAR(20) | UNIQUE | Baixo/Medio/Alto/Premium. |
| ValorMinimo, ValorMaximo | DECIMAL(12,2) | CHECK max>min | Limites da faixa. |

### dim.Dim_Produto
| ProdutoSK | INT IDENTITY | PK | Surrogate. |
| ProductID | BIGINT | UNIQUE | Chave natural do Kaggle. |
| CategoriaSK/SubcategoriaSK/MarcaSK/FaixaPrecoSK | INT | FK | Atributos do produto. |
| PrecoAtual | DECIMAL(12,2) | CHECK ≥0 | Preço corrente (versionado por trigger). |

### dim.Dim_Usuario
| UsuarioSK | INT IDENTITY | PK | Surrogate. |
| UserID | BIGINT | UNIQUE | Chave natural. |
| PrimeiroEvento/UltimoEvento | DATETIME2 | | Janela de atividade. |

### dim.Dim_Tempo (grão = dia)
| TempoSK | INT | PK | `AAAAMMDD`. |
| DataCompleta | DATE | UNIQUE | Data. |
| Ano, Mes, NomeMes, Dia, Trimestre, DiaSemana, NomeDiaSemana | | | Atributos de calendário. |
| EhDiaUtil, EhFimDeSemana | BIT | | Flags. |

### dim.Dim_TipoEvento
| EventTypeCodigo | VARCHAR(20) | UNIQUE | `view`/`cart`/`purchase`. |
| OrdemFunil | TINYINT | | 1, 2, 3 (posição no funil). |

### dim.Dim_OrigemTrafego
| Canal | VARCHAR(20) | UNIQUE | Organico/Pago/Direto/Social/Email. |

### dim.Dim_Geografia
| Pais, Regiao | VARCHAR | UNIQUE(par) | Localização macro inferida. |

### dim.Dim_MetodoPagamento
| Metodo | VARCHAR(30) | UNIQUE | Cartão/Pix/Boleto. |
| PermiteParcelamento | BIT | | Regra de negócio. |

### dim.Dim_StatusTransacao
| Status | VARCHAR(20) | UNIQUE | Aprovado/Recusado/Pendente. |
| EhConcluido | BIT | | Indica transação fechada. |

### dim.Dim_Dispositivo
| Plataforma | VARCHAR(20) | UNIQUE | Desktop/Mobile/Tablet. |

### dim.Dim_CampanhaPromo
| NomeCampanha | VARCHAR(60) | UNIQUE | Ação de marketing. |
| DataInicio, DataFim | DATE | CHECK fim≥inicio | Vigência. |

## Fatos (6)

### fato.Fato_EventosNavegacao (principal, > 500k)
Grão: **1 evento**. FKs: Tempo, Usuario, Produto, TipoEvento, OrigemTrafego,
Dispositivo, Geografia, Campanha (nullable). Medidas: `Preco`, `HoraDoDia`. Guarda
`UserSession` e `EventTime` para análises de sessão.

### fato.Fato_Pedido
Grão: **1 compra (sessão com purchase)**. FKs: Tempo, Usuario, MetodoPagamento,
StatusTransacao. Medidas: `QtdItens` (CHECK>0), `ValorTotal` (CHECK≥0).

### fato.Fato_ItemPedido
Grão: **1 item de pedido** (3FN). FK: Pedido, Produto. `Quantidade`, `PrecoUnitario`,
`Subtotal` (coluna computada PERSISTED).

### fato.Fato_AbandonoCarrinho (derivada no ETL)
Grão: **1 evento cart sem purchase na sessão**. FK: Tempo, Usuario, Produto,
Dispositivo. Medida: `ValorAbandonado`.

### fato.Fato_Pagamento
Grão: **1 transação por pedido**. FK: Pedido, MetodoPagamento, StatusTransacao, Tempo.
Medida: `ValorPago` (0 quando não concluído).

### fato.Audit_CargaETL
Log gerencial do ETL: `NomeProcesso`, `Etapa`, `InicioExec`, `FimExec`,
`LinhasAfetadas`, `Status` (CHECK EXECUTANDO/SUCESSO/ERRO), `Mensagem`, `Usuario`.

## Suporte

### dim.Hist_PrecoProduto
Histórico de alterações de preço gravado por `trg_AtualizacaoPreco`
(`PrecoAntigo`, `PrecoNovo`, `AlteradoEm`, `AlteradoPor`).

## Objetos programáveis

| Tipo | Objeto | Função |
|---|---|---|
| Function | `fn_ClassificarTicket(@valor)` | Retorna a faixa de preço. |
| Function | `fn_CalcularSessaoMinutos(@sessao)` | Minutos entre 1º view e compra. |
| View | `vw_CatalogoCompleto` | Catálogo desnormalizado. |
| View | `vw_ReceitaPorMarca` | Receita/ticket/visualizações por marca. |
| View | `vw_EngajamentoUsuario` | Funil e LTV por usuário. |
| View | `vw_ResumoDiarioEventos` | Eventos agregados por dia. |
| View | `vw_MonitoramentoCarga` | Status do ETL. |
| SP ETL | `sp_ExtractKaggleData` | Extração (BULK INSERT ou amostra). |
| SP ETL | `sp_TransformEventos` | Limpeza e enriquecimento. |
| SP ETL | `sp_LoadFatoNavegacao` | Carga transacional de dims e fatos. |
| SP análise | `sp_AnaliseFunilConversao` | Pergunta 1. |
| SP análise | `sp_AnaliseAbandonoHorario` | Pergunta 2. |
| Trigger | `trg_AuditoriaPedidos` | Audita UPDATE/DELETE em Fato_Pedido. |
| Trigger | `trg_AtualizacaoPreco` | Versiona preço em Dim_Produto. |
| Role | `DBA_Admin` / `Eng_Dados` / `Analista_BI` | Segurança (menor privilégio). |
