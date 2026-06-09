/*======================================================================
  09_triggers.sql
  2 Triggers (DTL) exigidos pelo SRS.
  - trg_AuditoriaPedidos  : registra UPDATE/DELETE na Fato_Pedido
                            (detecção de alterações não autorizadas).
  - trg_AtualizacaoPreco  : grava histórico quando o preço de um
                            produto muda na Dim_Produto.
======================================================================*/
USE EcommerceDW;
GO

----------------------------------------------------------------------
-- Tabela de histórico de preços (suporte ao trigger).
----------------------------------------------------------------------
IF OBJECT_ID('dim.Hist_PrecoProduto') IS NULL
CREATE TABLE dim.Hist_PrecoProduto
(
    HistSK      BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Hist_Preco PRIMARY KEY,
    ProdutoSK   INT NOT NULL,
    PrecoAntigo DECIMAL(12,2) NOT NULL,
    PrecoNovo   DECIMAL(12,2) NOT NULL,
    AlteradoEm  DATETIME2(0) NOT NULL CONSTRAINT DF_Hist_Preco_Data DEFAULT (SYSDATETIME()),
    AlteradoPor SYSNAME NOT NULL CONSTRAINT DF_Hist_Preco_User DEFAULT (SUSER_SNAME())
);
GO

----------------------------------------------------------------------
-- trg_AuditoriaPedidos : AFTER UPDATE, DELETE em Fato_Pedido.
----------------------------------------------------------------------
CREATE OR ALTER TRIGGER fato.trg_AuditoriaPedidos
ON fato.Fato_Pedido
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @acao VARCHAR(10) =
        CASE WHEN EXISTS (SELECT 1 FROM inserted) THEN 'UPDATE' ELSE 'DELETE' END;
    DECLARE @qtd INT = (SELECT COUNT(*) FROM deleted);

    INSERT INTO fato.Audit_CargaETL (NomeProcesso, Etapa, InicioExec, FimExec, LinhasAfetadas, Status, Mensagem)
    VALUES ('trg_AuditoriaPedidos', @acao, SYSDATETIME(), SYSDATETIME(), @qtd, 'SUCESSO',
            CONCAT('Operação ', @acao, ' detectada em Fato_Pedido afetando ', @qtd,
                   ' pedido(s). PedidoSKs: ',
                   STUFF((SELECT TOP (20) ',' + CAST(d.PedidoSK AS VARCHAR(20))
                          FROM deleted d ORDER BY d.PedidoSK FOR XML PATH('')), 1, 1, '')));
END;
GO

----------------------------------------------------------------------
-- trg_AtualizacaoPreco : AFTER UPDATE de PrecoAtual em Dim_Produto.
----------------------------------------------------------------------
CREATE OR ALTER TRIGGER dim.trg_AtualizacaoPreco
ON dim.Dim_Produto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(PrecoAtual)
    BEGIN
        INSERT INTO dim.Hist_PrecoProduto (ProdutoSK, PrecoAntigo, PrecoNovo)
        SELECT i.ProdutoSK, d.PrecoAtual, i.PrecoAtual
        FROM inserted i
        JOIN deleted  d ON d.ProdutoSK = i.ProdutoSK
        WHERE i.PrecoAtual <> d.PrecoAtual;   -- só registra mudança real
    END
END;
GO

PRINT '>> 09_triggers.sql concluído (2 triggers).';
GO
