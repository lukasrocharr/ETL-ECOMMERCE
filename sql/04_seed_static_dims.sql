/*======================================================================
  04_seed_static_dims.sql
  Carga das dimensões "de dicionário" (estáticas) e do calendário.
  Idempotente: usa padrões NOT EXISTS / MERGE para não duplicar.
======================================================================*/
USE EcommerceDW;
GO

----------------------------------------------------------------------
-- Dim_TipoEvento
----------------------------------------------------------------------
MERGE dim.Dim_TipoEvento AS d
USING (VALUES
        ('view',     'Visualização de produto', 1),
        ('cart',     'Adição ao carrinho',      2),
        ('purchase', 'Compra efetivada',        3)
      ) AS s(EventTypeCodigo, Descricao, OrdemFunil)
   ON d.EventTypeCodigo = s.EventTypeCodigo
 WHEN NOT MATCHED THEN
    INSERT (EventTypeCodigo, Descricao, OrdemFunil)
    VALUES (s.EventTypeCodigo, s.Descricao, s.OrdemFunil);
GO

----------------------------------------------------------------------
-- Dim_FaixaPreco
----------------------------------------------------------------------
MERGE dim.Dim_FaixaPreco AS d
USING (VALUES
        ('Baixo',  0.00,    50.00),
        ('Medio',  50.01,   300.00),
        ('Alto',   300.01,  1000.00),
        ('Premium',1000.01, 9999999.00)
      ) AS s(FaixaNome, ValorMinimo, ValorMaximo)
   ON d.FaixaNome = s.FaixaNome
 WHEN NOT MATCHED THEN
    INSERT (FaixaNome, ValorMinimo, ValorMaximo)
    VALUES (s.FaixaNome, s.ValorMinimo, s.ValorMaximo);
GO

----------------------------------------------------------------------
-- Dim_OrigemTrafego
----------------------------------------------------------------------
MERGE dim.Dim_OrigemTrafego AS d
USING (VALUES
        ('Organico', 'Busca orgânica / SEO'),
        ('Pago',     'Mídia paga (Ads)'),
        ('Direto',   'Acesso direto'),
        ('Social',   'Redes sociais'),
        ('Email',    'Campanhas de e-mail')
      ) AS s(Canal, Descricao)
   ON d.Canal = s.Canal
 WHEN NOT MATCHED THEN
    INSERT (Canal, Descricao) VALUES (s.Canal, s.Descricao);
GO

----------------------------------------------------------------------
-- Dim_MetodoPagamento
----------------------------------------------------------------------
MERGE dim.Dim_MetodoPagamento AS d
USING (VALUES
        ('Cartao Credito', 1),
        ('Cartao Debito',  0),
        ('Pix',            0),
        ('Boleto',         0)
      ) AS s(Metodo, PermiteParcelamento)
   ON d.Metodo = s.Metodo
 WHEN NOT MATCHED THEN
    INSERT (Metodo, PermiteParcelamento) VALUES (s.Metodo, s.PermiteParcelamento);
GO

----------------------------------------------------------------------
-- Dim_StatusTransacao
----------------------------------------------------------------------
MERGE dim.Dim_StatusTransacao AS d
USING (VALUES
        ('Aprovado', 1),
        ('Recusado', 0),
        ('Pendente', 0)
      ) AS s(Status, EhConcluido)
   ON d.Status = s.Status
 WHEN NOT MATCHED THEN
    INSERT (Status, EhConcluido) VALUES (s.Status, s.EhConcluido);
GO

----------------------------------------------------------------------
-- Dim_Dispositivo
----------------------------------------------------------------------
MERGE dim.Dim_Dispositivo AS d
USING (VALUES ('Desktop'), ('Mobile'), ('Tablet')) AS s(Plataforma)
   ON d.Plataforma = s.Plataforma
 WHEN NOT MATCHED THEN
    INSERT (Plataforma) VALUES (s.Plataforma);
GO

----------------------------------------------------------------------
-- Dim_CampanhaPromo (datas festivas relevantes para e-commerce)
----------------------------------------------------------------------
MERGE dim.Dim_CampanhaPromo AS d
USING (VALUES
        ('Black Friday 2024',   '2024-11-25', '2024-11-29'),
        ('Cyber Monday 2024',   '2024-12-02', '2024-12-02'),
        ('Natal 2024',          '2024-12-15', '2024-12-24'),
        ('Dia das Maes 2024',   '2024-05-06', '2024-05-12'),
        ('Promo Inverno 2024',  '2024-07-01', '2024-07-15')
      ) AS s(NomeCampanha, DataInicio, DataFim)
   ON d.NomeCampanha = s.NomeCampanha
 WHEN NOT MATCHED THEN
    INSERT (NomeCampanha, DataInicio, DataFim)
    VALUES (s.NomeCampanha, s.DataInicio, s.DataFim);
GO

----------------------------------------------------------------------
-- Dim_Geografia (semente macro; usada pela transformação por hash)
----------------------------------------------------------------------
MERGE dim.Dim_Geografia AS d
USING (VALUES
        ('Brasil','Sudeste'), ('Brasil','Sul'), ('Brasil','Nordeste'),
        ('Brasil','Norte'),   ('Brasil','Centro-Oeste'),
        ('Argentina','Pampa'),('Estados Unidos','Costa Leste')
      ) AS s(Pais, Regiao)
   ON d.Pais = s.Pais AND d.Regiao = s.Regiao
 WHEN NOT MATCHED THEN
    INSERT (Pais, Regiao) VALUES (s.Pais, s.Regiao);
GO

----------------------------------------------------------------------
-- Dim_Tempo (calendário 2024-01-01 .. 2025-12-31)
----------------------------------------------------------------------
;WITH Numeros AS (
    SELECT TOP (DATEDIFF(DAY,'2024-01-01','2026-01-01'))
           n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
),
Datas AS (
    SELECT d = DATEADD(DAY, n, CAST('2024-01-01' AS DATE)) FROM Numeros
)
INSERT INTO dim.Dim_Tempo
    (TempoSK, DataCompleta, Ano, Mes, NomeMes, Dia, Trimestre,
     DiaSemana, NomeDiaSemana, EhDiaUtil, EhFimDeSemana)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), d, 112)),
    d,
    YEAR(d),
    MONTH(d),
    DATENAME(MONTH, d),
    DAY(d),
    DATEPART(QUARTER, d),
    DATEPART(WEEKDAY, d),
    DATENAME(WEEKDAY, d),
    CASE WHEN DATEPART(WEEKDAY, d) IN (1,7) THEN 0 ELSE 1 END,
    CASE WHEN DATEPART(WEEKDAY, d) IN (1,7) THEN 1 ELSE 0 END
FROM Datas src
WHERE NOT EXISTS (SELECT 1 FROM dim.Dim_Tempo t
                  WHERE t.TempoSK = CONVERT(INT, CONVERT(CHAR(8), src.d, 112)));
GO

PRINT '>> 04_seed_static_dims.sql concluído.';
GO
