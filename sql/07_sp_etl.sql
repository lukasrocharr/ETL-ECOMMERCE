/*======================================================================
  07_sp_etl.sql
  Stored Procedures de ETL/CRUD (3 obrigatórias) + gerador de amostra.

    sp_GenerateSyntheticData : popula stg.EventosRaw com o MESMO layout
                               do CSV do Kaggle, com funil coerente
                               (view -> cart -> purchase). Permite
                               executar todo o pipeline sem o arquivo de
                               vários GB. Gera > 500k eventos.
    sp_ExtractKaggleData     : extração robusta. Se um caminho de CSV for
                               informado usa BULK INSERT; caso contrário
                               gera a amostra sintética.
    sp_TransformEventos      : limpeza, tipagem, fuso horário e
                               enriquecimento (dispositivo/origem/geo).
    sp_LoadFatoNavegacao     : carga DML transacional (BEGIN TRAN/COMMIT)
                               das dimensões e de TODAS as fatos.
======================================================================*/
USE EcommerceDW;
GO

/*=====================================================================
  Gerador da amostra sintética (formato idêntico ao Kaggle).
=====================================================================*/
CREATE OR ALTER PROCEDURE dbo.sp_GenerateSyntheticData
    @QtdSessoes INT = 420000,   -- ~420k sessões => ~590k eventos
    @NumProdutos INT = 2000,
    @NumUsuarios INT = 60000
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ini DATETIME2(0) = SYSDATETIME();
    INSERT INTO fato.Audit_CargaETL (NomeProcesso, Etapa, InicioExec)
    VALUES ('sp_GenerateSyntheticData','GERACAO_AMOSTRA',@ini);
    DECLARE @audit BIGINT = SCOPE_IDENTITY();

    BEGIN TRY
        ------------------------------------------------------------------
        -- Catálogo de produtos estável (cada product_id mantém
        -- categoria/marca/preço fixos, como no dado real).
        ------------------------------------------------------------------
        DECLARE @cats TABLE (idx INT, category_code VARCHAR(60), category_id BIGINT);
        INSERT INTO @cats VALUES
            (0,'electronics.smartphone',          2053013555631882655),
            (1,'electronics.audio.headphone',     2053013553031414607),
            (2,'computers.notebook',              2053013556168753601),
            (3,'appliances.kitchen.refrigerator', 2053013557192217207),
            (4,'apparel.shoes',                   2053013554658804075),
            (5,'furniture.living_room.sofa',      2053013560346280633),
            (6,'electronics.video.tv',            2053013555321504139),
            (7,'kids.toys',                       2053013558920217191),
            (8,'auto.accessories.player',         2053013563693335403),
            (9,'construction.tools.light',        2053013563911439225);

        DECLARE @brands TABLE (idx INT, brand VARCHAR(40));
        INSERT INTO @brands VALUES
            (0,'samsung'),(1,'apple'),(2,'xiaomi'),(3,'huawei'),(4,'lg'),
            (5,'sony'),(6,'dell'),(7,'hp'),(8,'lenovo'),(9,'nike'),
            (10,'adidas'),(11,'bosch'),(12,'philips'),(13,'asus'),(14,NULL); -- NULL => testa limpeza

        DROP TABLE IF EXISTS #cat;
        ;WITH P AS (
            SELECT TOP (@NumProdutos)
                   pid = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            FROM sys.all_objects a CROSS JOIN sys.all_objects b
        )
        SELECT
            p.pid AS product_id,
            c.category_code,
            c.category_id,
            b.brand,
            CAST(((p.pid * 37) % 1500) + (p.pid % 100) * 0.01 + 5 AS DECIMAL(12,2)) AS price
        INTO #cat
        FROM P p
        JOIN @cats   c ON c.idx = p.pid % 10
        JOIN @brands b ON b.idx = p.pid % 15;

        ------------------------------------------------------------------
        -- Sessões base: 1 usuário + 1 produto + horário + sorteios.
        ------------------------------------------------------------------
        DROP TABLE IF EXISTS #sess;
        ;WITH N AS (
            SELECT TOP (@QtdSessoes)
                   n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            FROM sys.all_objects a CROSS JOIN sys.all_objects b
        )
        SELECT
            n,
            user_id      = 1 + ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % @NumUsuarios,
            product_id   = 1 + ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % @NumProdutos,
            base_time    = DATEADD(SECOND, ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % 31449600, CAST('2024-01-01' AS DATETIME2(0))),
            r_cart       = ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % 100,
            r_buy        = ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % 100,
            user_session = CONCAT('sess-', n, '-', ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % 100000)
        INTO #sess
        FROM N;

        TRUNCATE TABLE stg.EventosRaw;

        ------------------------------------------------------------------
        -- VIEW: toda sessão tem ao menos 1 visualização.
        ------------------------------------------------------------------
        INSERT INTO stg.EventosRaw
            (event_time, event_type, product_id, category_id, category_code, brand, price, user_id, user_session)
        SELECT
            CONVERT(VARCHAR(19), s.base_time, 120) + ' UTC',
            'view', c.product_id, c.category_id, c.category_code, c.brand,
            CONVERT(VARCHAR(20), c.price), s.user_id, s.user_session
        FROM #sess s JOIN #cat c ON c.product_id = s.product_id;

        ------------------------------------------------------------------
        -- CART: ~30% das sessões adicionam ao carrinho (+ alguns min).
        ------------------------------------------------------------------
        INSERT INTO stg.EventosRaw
            (event_time, event_type, product_id, category_id, category_code, brand, price, user_id, user_session)
        SELECT
            CONVERT(VARCHAR(19), DATEADD(MINUTE, 3 + (s.r_cart % 10), s.base_time), 120) + ' UTC',
            'cart', c.product_id, c.category_id, c.category_code, c.brand,
            CONVERT(VARCHAR(20), c.price), s.user_id, s.user_session
        FROM #sess s JOIN #cat c ON c.product_id = s.product_id
        WHERE s.r_cart < 30;

        ------------------------------------------------------------------
        -- PURCHASE: ~35% de quem colocou no carrinho efetiva a compra.
        ------------------------------------------------------------------
        INSERT INTO stg.EventosRaw
            (event_time, event_type, product_id, category_id, category_code, brand, price, user_id, user_session)
        SELECT
            CONVERT(VARCHAR(19), DATEADD(MINUTE, 8 + (s.r_buy % 15), s.base_time), 120) + ' UTC',
            'purchase', c.product_id, c.category_id, c.category_code, c.brand,
            CONVERT(VARCHAR(20), c.price), s.user_id, s.user_session
        FROM #sess s JOIN #cat c ON c.product_id = s.product_id
        WHERE s.r_cart < 30 AND s.r_buy < 35;

        DECLARE @linhas BIGINT = (SELECT COUNT_BIG(*) FROM stg.EventosRaw);

        UPDATE fato.Audit_CargaETL
           SET FimExec = SYSDATETIME(), LinhasAfetadas = @linhas,
               Status = 'SUCESSO',
               Mensagem = CONCAT('Amostra sintética gerada: ', @linhas, ' eventos brutos.')
         WHERE AuditSK = @audit;
    END TRY
    BEGIN CATCH
        UPDATE fato.Audit_CargaETL
           SET FimExec = SYSDATETIME(), Status = 'ERRO', Mensagem = ERROR_MESSAGE()
         WHERE AuditSK = @audit;
        THROW;
    END CATCH
END;
GO

/*=====================================================================
  Extração (E do ETL).
=====================================================================*/
CREATE OR ALTER PROCEDURE dbo.sp_ExtractKaggleData
    @CaminhoArquivo NVARCHAR(4000) = NULL  -- NULL => usa amostra sintética
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ini DATETIME2(0) = SYSDATETIME();
    INSERT INTO fato.Audit_CargaETL (NomeProcesso, Etapa, InicioExec)
    VALUES ('sp_ExtractKaggleData','EXTRACAO',@ini);
    DECLARE @audit BIGINT = SCOPE_IDENTITY();

    BEGIN TRY
        IF @CaminhoArquivo IS NULL
        BEGIN
            EXEC dbo.sp_GenerateSyntheticData;  -- modo demonstração
        END
        ELSE
        BEGIN
            -- Extração robusta do CSV real do Kaggle via BULK INSERT.
            TRUNCATE TABLE stg.EventosRaw;
            DECLARE @sql NVARCHAR(MAX) = N'
                BULK INSERT stg.EventosRaw
                FROM ' + QUOTENAME(@CaminhoArquivo, '''') + N'
                WITH (
                    FIRSTROW = 2,            -- pula cabeçalho
                    FIELDTERMINATOR = '','',
                    ROWTERMINATOR = ''0x0a'',
                    CODEPAGE = ''65001'',    -- UTF-8
                    TABLOCK,
                    MAXERRORS = 1000
                );';
            EXEC sys.sp_executesql @sql;
        END

        DECLARE @linhas BIGINT = (SELECT COUNT_BIG(*) FROM stg.EventosRaw);
        UPDATE fato.Audit_CargaETL
           SET FimExec = SYSDATETIME(), LinhasAfetadas = @linhas, Status = 'SUCESSO',
               Mensagem = CONCAT('Extração concluída. Origem: ',
                                 ISNULL(@CaminhoArquivo,'AMOSTRA_SINTETICA'),
                                 '. Linhas: ', @linhas)
         WHERE AuditSK = @audit;
    END TRY
    BEGIN CATCH
        UPDATE fato.Audit_CargaETL
           SET FimExec = SYSDATETIME(), Status = 'ERRO', Mensagem = ERROR_MESSAGE()
         WHERE AuditSK = @audit;
        THROW;
    END CATCH
END;
GO

/*=====================================================================
  Transformação (T do ETL): raw -> clean.
  - converte event_time (string 'UTC') em datetime2;
  - descarta linhas inválidas (tipo/preço/produto);
  - trata marcas nulas (-> UNKNOWN);
  - separa category_code em Categoria/Subcategoria;
  - infere dispositivo/origem/geografia de forma determinística.
=====================================================================*/
CREATE OR ALTER PROCEDURE dbo.sp_TransformEventos
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ini DATETIME2(0) = SYSDATETIME();
    INSERT INTO fato.Audit_CargaETL (NomeProcesso, Etapa, InicioExec)
    VALUES ('sp_TransformEventos','TRANSFORMACAO',@ini);
    DECLARE @audit BIGINT = SCOPE_IDENTITY();

    BEGIN TRY
        TRUNCATE TABLE stg.EventosClean;

        INSERT INTO stg.EventosClean
            (EventTime, EventType, ProductID, CategoryID, CategoryCode,
             CategoriaNome, SubcategoriaNome, Marca, Preco, UserID, UserSession,
             DataEvento, HoraDoDia, Dispositivo, OrigemTrafego, GeoPais, GeoRegiao)
        SELECT
            ec.EventTime,
            ec.EventType,
            ec.ProductID,
            ec.CategoryID,
            ec.CategoryCode,
            ec.CategoriaNome,
            ec.SubcategoriaNome,
            ec.Marca,
            ec.Preco,
            ec.UserID,
            ec.UserSession,
            CAST(ec.EventTime AS DATE),
            DATEPART(HOUR, ec.EventTime),
            -- DISPOSITIVO (determinístico por sessão)
            CASE WHEN ABS(CONVERT(BIGINT, CHECKSUM(ec.UserSession))) % 100 < 55 THEN 'Mobile'
                 WHEN ABS(CONVERT(BIGINT, CHECKSUM(ec.UserSession))) % 100 < 90 THEN 'Desktop'
                 ELSE 'Tablet' END,
            -- ORIGEM DE TRÁFEGO
            CASE ABS(CONVERT(BIGINT, CHECKSUM(ec.UserSession,'org'))) % 100 / 20
                 WHEN 0 THEN 'Organico' WHEN 1 THEN 'Pago'
                 WHEN 2 THEN 'Direto'   WHEN 3 THEN 'Social'
                 ELSE 'Email' END,
            'Brasil',
            -- REGIÃO
            CASE ABS(CONVERT(BIGINT, CHECKSUM(ec.UserSession,'geo'))) % 5
                 WHEN 0 THEN 'Sudeste' WHEN 1 THEN 'Sul'
                 WHEN 2 THEN 'Nordeste' WHEN 3 THEN 'Norte'
                 ELSE 'Centro-Oeste' END
        FROM (
            SELECT
                TRY_CONVERT(DATETIME2(0), REPLACE(r.event_time,' UTC','')) AS EventTime,
                LOWER(LTRIM(RTRIM(r.event_type)))                          AS EventType,
                TRY_CONVERT(BIGINT, r.product_id)                          AS ProductID,
                TRY_CONVERT(BIGINT, r.category_id)                         AS CategoryID,
                NULLIF(LTRIM(RTRIM(r.category_code)),'')                   AS CategoryCode,
                -- categoria = 1º nível
                CASE WHEN CHARINDEX('.', ISNULL(NULLIF(r.category_code,''),'desconhecida')) > 0
                     THEN LEFT(r.category_code, CHARINDEX('.', r.category_code) - 1)
                     ELSE ISNULL(NULLIF(LTRIM(RTRIM(r.category_code)),''),'desconhecida') END AS CategoriaNome,
                -- subcategoria = demais níveis
                CASE WHEN CHARINDEX('.', ISNULL(r.category_code,'')) > 0
                     THEN STUFF(r.category_code, 1, CHARINDEX('.', r.category_code), '')
                     ELSE 'geral' END                                      AS SubcategoriaNome,
                UPPER(ISNULL(NULLIF(LTRIM(RTRIM(r.brand)),''),'UNKNOWN'))  AS Marca,
                TRY_CONVERT(DECIMAL(12,2), r.price)                        AS Preco,
                TRY_CONVERT(BIGINT, r.user_id)                            AS UserID,
                NULLIF(LTRIM(RTRIM(r.user_session)),'')                    AS UserSession
            FROM stg.EventosRaw r
        ) ec
        WHERE ec.EventTime  IS NOT NULL          -- descarta datas inválidas
          AND ec.ProductID  IS NOT NULL
          AND ec.UserID     IS NOT NULL
          AND ec.UserSession IS NOT NULL
          AND ec.Preco      IS NOT NULL AND ec.Preco >= 0
          AND ec.EventType IN ('view','cart','purchase');

        DECLARE @linhas BIGINT = @@ROWCOUNT;
        DECLARE @descartadas BIGINT =
            (SELECT COUNT_BIG(*) FROM stg.EventosRaw) - @linhas;

        UPDATE fato.Audit_CargaETL
           SET FimExec = SYSDATETIME(), LinhasAfetadas = @linhas, Status = 'SUCESSO',
               Mensagem = CONCAT('Transformação OK. Válidas: ', @linhas,
                                 ' | Descartadas: ', @descartadas)
         WHERE AuditSK = @audit;
    END TRY
    BEGIN CATCH
        UPDATE fato.Audit_CargaETL
           SET FimExec = SYSDATETIME(), Status = 'ERRO', Mensagem = ERROR_MESSAGE()
         WHERE AuditSK = @audit;
        THROW;
    END CATCH
END;
GO

/*=====================================================================
  Carga (L do ETL): clean -> dimensões -> fatos.
  Tudo dentro de uma transação para garantir atomicidade.
=====================================================================*/
CREATE OR ALTER PROCEDURE dbo.sp_LoadFatoNavegacao
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- qualquer erro aborta a transação

    DECLARE @ini DATETIME2(0) = SYSDATETIME();
    INSERT INTO fato.Audit_CargaETL (NomeProcesso, Etapa, InicioExec)
    VALUES ('sp_LoadFatoNavegacao','CARGA_DML',@ini);
    DECLARE @audit BIGINT = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------------------
        -- 1) Dimensões derivadas dos dados (NOT EXISTS = idempotente).
        ----------------------------------------------------------------
        INSERT INTO dim.Dim_Categoria (CategoriaNome)
        SELECT DISTINCT c.CategoriaNome
        FROM stg.EventosClean c
        WHERE NOT EXISTS (SELECT 1 FROM dim.Dim_Categoria d WHERE d.CategoriaNome = c.CategoriaNome);

        INSERT INTO dim.Dim_Subcategoria (CategoriaSK, SubcategoriaNome)
        SELECT DISTINCT cat.CategoriaSK, c.SubcategoriaNome
        FROM stg.EventosClean c
        JOIN dim.Dim_Categoria cat ON cat.CategoriaNome = c.CategoriaNome
        WHERE NOT EXISTS (
            SELECT 1 FROM dim.Dim_Subcategoria s
            WHERE s.CategoriaSK = cat.CategoriaSK AND s.SubcategoriaNome = c.SubcategoriaNome);

        INSERT INTO dim.Dim_Marca (MarcaNome)
        SELECT DISTINCT c.Marca
        FROM stg.EventosClean c
        WHERE NOT EXISTS (SELECT 1 FROM dim.Dim_Marca m WHERE m.MarcaNome = c.Marca);

        -- Produto: 1 linha por ProductID (atributos do registro mais recente).
        ;WITH ProdSrc AS (
            SELECT c.ProductID,
                   c.CategoriaNome, c.SubcategoriaNome, c.Marca, c.Preco,
                   rn = ROW_NUMBER() OVER (PARTITION BY c.ProductID ORDER BY c.EventTime DESC)
            FROM stg.EventosClean c
        )
        INSERT INTO dim.Dim_Produto (ProductID, CategoriaSK, SubcategoriaSK, MarcaSK, FaixaPrecoSK, PrecoAtual)
        SELECT ps.ProductID, cat.CategoriaSK, sub.SubcategoriaSK, m.MarcaSK, fp.FaixaPrecoSK, ps.Preco
        FROM ProdSrc ps
        JOIN dim.Dim_Categoria cat ON cat.CategoriaNome = ps.CategoriaNome
        JOIN dim.Dim_Subcategoria sub ON sub.CategoriaSK = cat.CategoriaSK AND sub.SubcategoriaNome = ps.SubcategoriaNome
        JOIN dim.Dim_Marca m ON m.MarcaNome = ps.Marca
        JOIN dim.Dim_FaixaPreco fp ON ps.Preco BETWEEN fp.ValorMinimo AND fp.ValorMaximo
        WHERE ps.rn = 1
          AND NOT EXISTS (SELECT 1 FROM dim.Dim_Produto p WHERE p.ProductID = ps.ProductID);

        -- Usuario
        INSERT INTO dim.Dim_Usuario (UserID, PrimeiroEvento, UltimoEvento)
        SELECT c.UserID, MIN(c.EventTime), MAX(c.EventTime)
        FROM stg.EventosClean c
        WHERE NOT EXISTS (SELECT 1 FROM dim.Dim_Usuario u WHERE u.UserID = c.UserID)
        GROUP BY c.UserID;

        ----------------------------------------------------------------
        -- 2) Limpa fatos (full refresh) na ordem das dependências.
        ----------------------------------------------------------------
        TRUNCATE TABLE fato.Fato_Pagamento;
        TRUNCATE TABLE fato.Fato_ItemPedido;
        TRUNCATE TABLE fato.Fato_AbandonoCarrinho;
        DELETE FROM fato.Fato_Pedido;            -- referenciada por FK -> DELETE
        TRUNCATE TABLE fato.Fato_EventosNavegacao;

        ----------------------------------------------------------------
        -- 3) Fato principal de navegação (> 500k linhas).
        ----------------------------------------------------------------
        INSERT INTO fato.Fato_EventosNavegacao
            (TempoSK, HoraDoDia, UsuarioSK, ProdutoSK, TipoEventoSK,
             OrigemTrafegoSK, DispositivoSK, GeografiaSK, CampanhaSK,
             UserSession, EventTime, Preco)
        SELECT
            CONVERT(INT, CONVERT(CHAR(8), c.DataEvento, 112)),
            c.HoraDoDia,
            u.UsuarioSK, p.ProdutoSK, te.TipoEventoSK,
            ot.OrigemTrafegoSK, disp.DispositivoSK, geo.GeografiaSK,
            camp.CampanhaSK,
            c.UserSession, c.EventTime, c.Preco
        FROM stg.EventosClean c
        JOIN dim.Dim_Usuario u        ON u.UserID = c.UserID
        JOIN dim.Dim_Produto p        ON p.ProductID = c.ProductID
        JOIN dim.Dim_TipoEvento te    ON te.EventTypeCodigo = c.EventType
        JOIN dim.Dim_OrigemTrafego ot ON ot.Canal = c.OrigemTrafego
        JOIN dim.Dim_Dispositivo disp ON disp.Plataforma = c.Dispositivo
        JOIN dim.Dim_Geografia geo    ON geo.Pais = c.GeoPais AND geo.Regiao = c.GeoRegiao
        LEFT JOIN dim.Dim_CampanhaPromo camp
               ON c.DataEvento BETWEEN camp.DataInicio AND camp.DataFim;

        ----------------------------------------------------------------
        -- 4) Fato_Pedido: 1 linha por sessão que efetivou compra.
        --    Método/Status atribuídos deterministicamente por sessão.
        ----------------------------------------------------------------
        ;WITH Compras AS (
            SELECT c.UserSession,
                   MAX(c.EventTime) AS DataHora,
                   MAX(c.UserID)    AS UserID,
                   COUNT(*)         AS QtdItens,
                   SUM(c.Preco)     AS ValorTotal
            FROM stg.EventosClean c
            WHERE c.EventType = 'purchase'
            GROUP BY c.UserSession
        )
        INSERT INTO fato.Fato_Pedido
            (UserSession, TempoSK, UsuarioSK, MetodoPagamentoSK, StatusTransacaoSK,
             DataHoraPedido, QtdItens, ValorTotal)
        SELECT
            co.UserSession,
            CONVERT(INT, CONVERT(CHAR(8), CAST(co.DataHora AS DATE), 112)),
            u.UsuarioSK,
            mp.MetodoPagamentoSK,
            st.StatusTransacaoSK,
            co.DataHora, co.QtdItens, co.ValorTotal
        FROM Compras co
        JOIN dim.Dim_Usuario u ON u.UserID = co.UserID
        JOIN dim.Dim_MetodoPagamento mp
              ON mp.MetodoPagamentoSK = 1 + ABS(CONVERT(BIGINT, CHECKSUM(co.UserSession,'pay'))) % 4
        JOIN dim.Dim_StatusTransacao st
              ON st.Status = CASE WHEN ABS(CONVERT(BIGINT, CHECKSUM(co.UserSession,'st'))) % 100 < 85 THEN 'Aprovado'
                                  WHEN ABS(CONVERT(BIGINT, CHECKSUM(co.UserSession,'st'))) % 100 < 95 THEN 'Recusado'
                                  ELSE 'Pendente' END;

        ----------------------------------------------------------------
        -- 5) Fato_ItemPedido: 1 linha por evento purchase da sessão.
        ----------------------------------------------------------------
        INSERT INTO fato.Fato_ItemPedido (PedidoSK, ProdutoSK, Quantidade, PrecoUnitario)
        SELECT ped.PedidoSK, p.ProdutoSK, 1, c.Preco
        FROM stg.EventosClean c
        JOIN fato.Fato_Pedido ped ON ped.UserSession = c.UserSession
        JOIN dim.Dim_Produto p    ON p.ProductID = c.ProductID
        WHERE c.EventType = 'purchase';

        ----------------------------------------------------------------
        -- 6) Fato_Pagamento: 1 transação por pedido.
        ----------------------------------------------------------------
        INSERT INTO fato.Fato_Pagamento
            (PedidoSK, MetodoPagamentoSK, StatusTransacaoSK, TempoSK, DataHoraPagamento, ValorPago)
        SELECT
            ped.PedidoSK, ped.MetodoPagamentoSK, ped.StatusTransacaoSK,
            ped.TempoSK, ped.DataHoraPedido,
            CASE WHEN st.EhConcluido = 1 THEN ped.ValorTotal ELSE 0 END
        FROM fato.Fato_Pedido ped
        JOIN dim.Dim_StatusTransacao st ON st.StatusTransacaoSK = ped.StatusTransacaoSK;

        ----------------------------------------------------------------
        -- 7) Fato_AbandonoCarrinho: cart sem purchase na mesma sessão.
        ----------------------------------------------------------------
        INSERT INTO fato.Fato_AbandonoCarrinho
            (UserSession, TempoSK, HoraDoDia, UsuarioSK, ProdutoSK,
             DispositivoSK, DataHoraCarrinho, ValorAbandonado)
        SELECT
            c.UserSession,
            CONVERT(INT, CONVERT(CHAR(8), c.DataEvento, 112)),
            c.HoraDoDia, u.UsuarioSK, p.ProdutoSK, disp.DispositivoSK,
            c.EventTime, c.Preco
        FROM stg.EventosClean c
        JOIN dim.Dim_Usuario u        ON u.UserID = c.UserID
        JOIN dim.Dim_Produto p        ON p.ProductID = c.ProductID
        JOIN dim.Dim_Dispositivo disp ON disp.Plataforma = c.Dispositivo
        WHERE c.EventType = 'cart'
          AND NOT EXISTS (
                SELECT 1 FROM stg.EventosClean pc
                WHERE pc.UserSession = c.UserSession AND pc.EventType = 'purchase');

        DECLARE @linhasFato BIGINT = (SELECT COUNT_BIG(*) FROM fato.Fato_EventosNavegacao);

        COMMIT TRANSACTION;

        UPDATE fato.Audit_CargaETL
           SET FimExec = SYSDATETIME(), LinhasAfetadas = @linhasFato, Status = 'SUCESSO',
               Mensagem = CONCAT('Carga concluída. Fato principal: ', @linhasFato, ' linhas.')
         WHERE AuditSK = @audit;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        UPDATE fato.Audit_CargaETL
           SET FimExec = SYSDATETIME(), Status = 'ERRO', Mensagem = ERROR_MESSAGE()
         WHERE AuditSK = @audit;
        THROW;
    END CATCH
END;
GO

PRINT '>> 07_sp_etl.sql concluído (4 procedures de ETL).';
GO
