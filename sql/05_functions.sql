/*======================================================================
  05_functions.sql
  2 Functions (UDF) exigidas pelo SRS.
  - fn_ClassificarTicket   : classifica um valor monetário em faixa.
  - fn_CalcularSessaoMinutos : minutos entre o 1º view e a purchase de
                               uma sessão (NULL se a sessão não converteu).
  CREATE OR ALTER garante idempotência.
======================================================================*/
USE EcommerceDW;
GO

CREATE OR ALTER FUNCTION dbo.fn_ClassificarTicket (@Valor DECIMAL(12,2))
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @Faixa VARCHAR(20);

    SELECT TOP (1) @Faixa = fp.FaixaNome
    FROM dim.Dim_FaixaPreco fp
    WHERE @Valor >= fp.ValorMinimo AND @Valor <= fp.ValorMaximo
    ORDER BY fp.ValorMinimo;

    RETURN ISNULL(@Faixa, 'Indefinido');
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_CalcularSessaoMinutos (@UserSession VARCHAR(80))
RETURNS INT
AS
BEGIN
    DECLARE @PrimeiroView DATETIME2(0),
            @PrimeiraCompra DATETIME2(0);

    SELECT @PrimeiroView   = MIN(CASE WHEN te.OrdemFunil = 1 THEN e.EventTime END),
           @PrimeiraCompra = MIN(CASE WHEN te.OrdemFunil = 3 THEN e.EventTime END)
    FROM fato.Fato_EventosNavegacao e
    JOIN dim.Dim_TipoEvento te ON te.TipoEventoSK = e.TipoEventoSK
    WHERE e.UserSession = @UserSession;

    IF @PrimeiroView IS NULL OR @PrimeiraCompra IS NULL
        RETURN NULL;  -- sessão sem conversão

    RETURN DATEDIFF(MINUTE, @PrimeiroView, @PrimeiraCompra);
END;
GO

PRINT '>> 05_functions.sql concluído (2 functions).';
GO
