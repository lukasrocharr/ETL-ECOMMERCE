/*======================================================================
  03_ddl_facts.sql
  6 Tabelas Fato + tabela de auditoria de carga.
  - fato.Fato_EventosNavegacao : grão de evento/hit (> 500.000 registros)
  - fato.Fato_Pedido           : 1 linha por compra (sessão com purchase)
  - fato.Fato_ItemPedido       : itens da compra (3FN)
  - fato.Fato_AbandonoCarrinho : sessões com cart e sem purchase
  - fato.Fato_Pagamento        : transações financeiras
  - fato.Audit_CargaETL        : log gerencial do processo de ETL
======================================================================*/
USE EcommerceDW;
GO

DROP TABLE IF EXISTS fato.Fato_Pagamento;
DROP TABLE IF EXISTS fato.Fato_ItemPedido;
DROP TABLE IF EXISTS fato.Fato_AbandonoCarrinho;
DROP TABLE IF EXISTS fato.Fato_Pedido;
DROP TABLE IF EXISTS fato.Fato_EventosNavegacao;
DROP TABLE IF EXISTS fato.Audit_CargaETL;
GO

----------------------------------------------------------------------
-- 15) Fato_EventosNavegacao (TABELA PRINCIPAL > 500k linhas)
----------------------------------------------------------------------
CREATE TABLE fato.Fato_EventosNavegacao
(
    EventoSK        BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Fato_Eventos PRIMARY KEY,
    TempoSK         INT    NOT NULL,
    HoraDoDia       TINYINT NOT NULL,
    UsuarioSK       INT    NOT NULL,
    ProdutoSK       INT    NOT NULL,
    TipoEventoSK    INT    NOT NULL,
    OrigemTrafegoSK INT    NOT NULL,
    DispositivoSK   INT    NOT NULL,
    GeografiaSK     INT    NOT NULL,
    CampanhaSK      INT    NULL,
    UserSession     VARCHAR(80)  NOT NULL,
    EventTime       DATETIME2(0) NOT NULL,
    Preco           DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_Eventos_Tempo    FOREIGN KEY (TempoSK)         REFERENCES dim.Dim_Tempo(TempoSK),
    CONSTRAINT FK_Eventos_Usuario  FOREIGN KEY (UsuarioSK)       REFERENCES dim.Dim_Usuario(UsuarioSK),
    CONSTRAINT FK_Eventos_Produto  FOREIGN KEY (ProdutoSK)       REFERENCES dim.Dim_Produto(ProdutoSK),
    CONSTRAINT FK_Eventos_Tipo     FOREIGN KEY (TipoEventoSK)    REFERENCES dim.Dim_TipoEvento(TipoEventoSK),
    CONSTRAINT FK_Eventos_Origem   FOREIGN KEY (OrigemTrafegoSK) REFERENCES dim.Dim_OrigemTrafego(OrigemTrafegoSK),
    CONSTRAINT FK_Eventos_Disp     FOREIGN KEY (DispositivoSK)   REFERENCES dim.Dim_Dispositivo(DispositivoSK),
    CONSTRAINT FK_Eventos_Geo      FOREIGN KEY (GeografiaSK)     REFERENCES dim.Dim_Geografia(GeografiaSK),
    CONSTRAINT FK_Eventos_Campanha FOREIGN KEY (CampanhaSK)      REFERENCES dim.Dim_CampanhaPromo(CampanhaSK)
);
GO

----------------------------------------------------------------------
-- 16) Fato_Pedido (1 linha por compra)
----------------------------------------------------------------------
CREATE TABLE fato.Fato_Pedido
(
    PedidoSK          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Fato_Pedido PRIMARY KEY,
    UserSession       VARCHAR(80) NOT NULL,
    TempoSK           INT NOT NULL,
    UsuarioSK         INT NOT NULL,
    MetodoPagamentoSK INT NOT NULL,
    StatusTransacaoSK INT NOT NULL,
    DataHoraPedido    DATETIME2(0) NOT NULL,
    QtdItens          INT NOT NULL CONSTRAINT CK_Pedido_Qtd CHECK (QtdItens > 0),
    ValorTotal        DECIMAL(14,2) NOT NULL CONSTRAINT CK_Pedido_Valor CHECK (ValorTotal >= 0),
    CONSTRAINT FK_Pedido_Tempo   FOREIGN KEY (TempoSK)           REFERENCES dim.Dim_Tempo(TempoSK),
    CONSTRAINT FK_Pedido_Usuario FOREIGN KEY (UsuarioSK)         REFERENCES dim.Dim_Usuario(UsuarioSK),
    CONSTRAINT FK_Pedido_Metodo  FOREIGN KEY (MetodoPagamentoSK) REFERENCES dim.Dim_MetodoPagamento(MetodoPagamentoSK),
    CONSTRAINT FK_Pedido_Status  FOREIGN KEY (StatusTransacaoSK) REFERENCES dim.Dim_StatusTransacao(StatusTransacaoSK)
);
GO

----------------------------------------------------------------------
-- 17) Fato_ItemPedido (itens; garante 3FN)
----------------------------------------------------------------------
CREATE TABLE fato.Fato_ItemPedido
(
    ItemPedidoSK BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Fato_ItemPedido PRIMARY KEY,
    PedidoSK     BIGINT NOT NULL,
    ProdutoSK    INT NOT NULL,
    Quantidade   INT NOT NULL CONSTRAINT CK_Item_Qtd CHECK (Quantidade > 0),
    PrecoUnitario DECIMAL(12,2) NOT NULL CONSTRAINT CK_Item_Preco CHECK (PrecoUnitario >= 0),
    Subtotal     AS (Quantidade * PrecoUnitario) PERSISTED,  -- coluna computada
    CONSTRAINT FK_Item_Pedido  FOREIGN KEY (PedidoSK)  REFERENCES fato.Fato_Pedido(PedidoSK),
    CONSTRAINT FK_Item_Produto FOREIGN KEY (ProdutoSK) REFERENCES dim.Dim_Produto(ProdutoSK)
);
GO

----------------------------------------------------------------------
-- 18) Fato_AbandonoCarrinho (derivada via ETL)
----------------------------------------------------------------------
CREATE TABLE fato.Fato_AbandonoCarrinho
(
    AbandonoSK     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Fato_Abandono PRIMARY KEY,
    UserSession    VARCHAR(80) NOT NULL,
    TempoSK        INT NOT NULL,
    HoraDoDia      TINYINT NOT NULL,
    UsuarioSK      INT NOT NULL,
    ProdutoSK      INT NOT NULL,
    DispositivoSK  INT NOT NULL,
    DataHoraCarrinho DATETIME2(0) NOT NULL,
    ValorAbandonado DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_Abandono_Tempo   FOREIGN KEY (TempoSK)       REFERENCES dim.Dim_Tempo(TempoSK),
    CONSTRAINT FK_Abandono_Usuario FOREIGN KEY (UsuarioSK)     REFERENCES dim.Dim_Usuario(UsuarioSK),
    CONSTRAINT FK_Abandono_Produto FOREIGN KEY (ProdutoSK)     REFERENCES dim.Dim_Produto(ProdutoSK),
    CONSTRAINT FK_Abandono_Disp    FOREIGN KEY (DispositivoSK) REFERENCES dim.Dim_Dispositivo(DispositivoSK)
);
GO

----------------------------------------------------------------------
-- 19) Fato_Pagamento (faturamento)
----------------------------------------------------------------------
CREATE TABLE fato.Fato_Pagamento
(
    PagamentoSK       BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Fato_Pagamento PRIMARY KEY,
    PedidoSK          BIGINT NOT NULL,
    MetodoPagamentoSK INT NOT NULL,
    StatusTransacaoSK INT NOT NULL,
    TempoSK           INT NOT NULL,
    DataHoraPagamento DATETIME2(0) NOT NULL,
    ValorPago         DECIMAL(14,2) NOT NULL CONSTRAINT CK_Pagamento_Valor CHECK (ValorPago >= 0),
    CONSTRAINT FK_Pagamento_Pedido FOREIGN KEY (PedidoSK)          REFERENCES fato.Fato_Pedido(PedidoSK),
    CONSTRAINT FK_Pagamento_Metodo FOREIGN KEY (MetodoPagamentoSK) REFERENCES dim.Dim_MetodoPagamento(MetodoPagamentoSK),
    CONSTRAINT FK_Pagamento_Status FOREIGN KEY (StatusTransacaoSK) REFERENCES dim.Dim_StatusTransacao(StatusTransacaoSK),
    CONSTRAINT FK_Pagamento_Tempo  FOREIGN KEY (TempoSK)           REFERENCES dim.Dim_Tempo(TempoSK)
);
GO

----------------------------------------------------------------------
-- 20) Audit_CargaETL (log gerencial)
----------------------------------------------------------------------
CREATE TABLE fato.Audit_CargaETL
(
    AuditSK       BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Audit_CargaETL PRIMARY KEY,
    NomeProcesso  VARCHAR(100) NOT NULL,
    Etapa         VARCHAR(50)  NOT NULL,
    InicioExec    DATETIME2(0) NOT NULL,
    FimExec       DATETIME2(0) NULL,
    LinhasAfetadas BIGINT NULL,
    Status        VARCHAR(20) NOT NULL CONSTRAINT DF_Audit_Status DEFAULT ('EXECUTANDO'),
    Mensagem      NVARCHAR(2000) NULL,
    Usuario       SYSNAME NOT NULL CONSTRAINT DF_Audit_Usuario DEFAULT (SUSER_SNAME()),
    CONSTRAINT CK_Audit_Status CHECK (Status IN ('EXECUTANDO','SUCESSO','ERRO'))
);
GO

PRINT '>> 03_ddl_facts.sql concluído (6 fatos/auditoria).';
GO
