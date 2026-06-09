/*======================================================================
  10_indexes.sql
  Índices para otimizar as consultas analíticas (executar após a carga).
  Idempotente: cada índice é criado apenas se ainda não existir.
  Para demonstrar o ganho de performance, rode as SP analíticas com
  SET STATISTICS IO, TIME ON ANTES e DEPOIS de criar estes índices.
======================================================================*/
USE EcommerceDW;
GO

-- Funil de conversão: filtra/agrupa por tipo de evento e produto.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Eventos_Tipo_Produto')
    CREATE NONCLUSTERED INDEX IX_Eventos_Tipo_Produto
        ON fato.Fato_EventosNavegacao (TipoEventoSK, ProdutoSK)
        INCLUDE (Preco);
GO

-- Análise temporal / por hora.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Eventos_Tempo_Hora')
    CREATE NONCLUSTERED INDEX IX_Eventos_Tempo_Hora
        ON fato.Fato_EventosNavegacao (TempoSK, HoraDoDia);
GO

-- fn_CalcularSessaoMinutos e joins por sessão.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Eventos_Session')
    CREATE NONCLUSTERED INDEX IX_Eventos_Session
        ON fato.Fato_EventosNavegacao (UserSession)
        INCLUDE (TipoEventoSK, EventTime);
GO

-- Receita por marca (join itens -> produto).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ItemPedido_Produto')
    CREATE NONCLUSTERED INDEX IX_ItemPedido_Produto
        ON fato.Fato_ItemPedido (ProdutoSK)
        INCLUDE (Quantidade, PrecoUnitario, PedidoSK);
GO

-- Abandono por hora.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Abandono_Hora')
    CREATE NONCLUSTERED INDEX IX_Abandono_Hora
        ON fato.Fato_AbandonoCarrinho (HoraDoDia)
        INCLUDE (TempoSK, ValorAbandonado);
GO

PRINT '>> 10_indexes.sql concluído.';
GO
