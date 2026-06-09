# Manual de Uso das Rotinas

## 1. Subir o ambiente

```bash
sudo systemctl start docker      # garante o daemon ativo
./run_local.sh                   # cria o banco e roda tudo de ponta a ponta
```

Para conectar manualmente ao banco já no ar:

```bash
docker exec -it ecommerce_dw /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P 'Str0ng!Passw0rd2024' -C -No -d EcommerceDW
```

## 2. Reexecutar apenas o ETL

Os scripts são **idempotentes**. Para recarregar os dados sem recriar o schema:

```sql
EXEC dbo.sp_ExtractKaggleData;     -- amostra sintética (~590k eventos)
EXEC dbo.sp_TransformEventos;
EXEC dbo.sp_LoadFatoNavegacao;
```

### Usar o CSV real do Kaggle
1. Baixe o arquivo (ex.: `2019-Oct.csv`) e copie para o contêiner:
   ```bash
   docker cp 2019-Oct.csv ecommerce_dw:/data/2019-Oct.csv
   ```
2. Troque a extração:
   ```sql
   EXEC dbo.sp_ExtractKaggleData @CaminhoArquivo = N'/data/2019-Oct.csv';
   EXEC dbo.sp_TransformEventos;
   EXEC dbo.sp_LoadFatoNavegacao;
   ```

## 3. Rodar as análises

```sql
-- Pergunta 1: funil de conversão por categoria (filtro opcional)
EXEC dbo.sp_AnaliseFunilConversao;
EXEC dbo.sp_AnaliseFunilConversao @CategoriaNome = 'electronics';

-- Pergunta 2: horários de abandono (Top N opcional)
EXEC dbo.sp_AnaliseAbandonoHorario @TopN = 10;

-- Pergunta 3: receita por marca
SELECT * FROM dbo.vw_ReceitaPorMarca ORDER BY ReceitaTotal DESC;
```

## 4. Funções utilitárias

```sql
SELECT dbo.fn_ClassificarTicket(749.90);            -- -> 'Alto'
SELECT dbo.fn_CalcularSessaoMinutos('sess-123-45'); -- minutos até a compra (ou NULL)
```

## 5. Monitorar a carga

```sql
SELECT * FROM dbo.vw_MonitoramentoCarga ORDER BY AuditSK DESC;
```

## 6. Demonstrar performance dos índices

```sql
SET STATISTICS IO, TIME ON;
EXEC dbo.sp_AnaliseFunilConversao;     -- compare antes/depois de 10_indexes.sql
SET STATISTICS IO, TIME OFF;
```

## 7. Testar segurança (DCL)

```sql
EXECUTE AS USER = 'usr_bi';
    SELECT * FROM dbo.vw_ReceitaPorMarca;   -- OK
    SELECT * FROM fato.Fato_Pedido;          -- ERRO: permissão negada
REVERT;
```

## 8. Encerrar

```bash
docker rm -f ecommerce_dw     # remove o contêiner (e os dados)
```

## Solução de problemas

| Sintoma | Causa provável | Ação |
|---|---|---|
| `daemon do Docker não está ativo` | serviço parado | `sudo systemctl start docker` |
| `Login failed for user 'sa'` | senha fraca rejeitada | use senha forte (≥8, maiúscula/número/símbolo) |
| Carga abaixo de 500k | `@QtdSessoes` reduzido | rode `EXEC sp_GenerateSyntheticData @QtdSessoes = 420000` |
| `Cannot truncate ... referenced by FK` | ordem de limpeza | já tratado em `sp_LoadFatoNavegacao` (DELETE no pai) |
