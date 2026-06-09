#!/usr/bin/env bash
#=====================================================================
# run_local.sh
# Sobe um SQL Server 2022 em contêiner Docker e executa todo o projeto
# (DDL -> seeds -> objetos programáveis -> ETL -> validação -> demos).
# Uso:   ./run_local.sh
# Requisitos: docker em execução. Não precisa de SQL Server instalado.
#=====================================================================
set -euo pipefail

CONTAINER="ecommerce_dw"
IMAGE="mcr.microsoft.com/mssql/server:2022-latest"
SA_PASS="Str0ng!Passw0rd2024"
SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ">> Verificando Docker..."
docker info >/dev/null 2>&1 || { echo "ERRO: o daemon do Docker não está ativo. Rode: sudo systemctl start docker"; exit 1; }

# (Re)cria o contêiner
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo ">> Removendo contêiner anterior..."
    docker rm -f "$CONTAINER" >/dev/null
fi

echo ">> Subindo SQL Server 2022..."
docker run -d --name "$CONTAINER" \
    -e "ACCEPT_EULA=Y" \
    -e "MSSQL_SA_PASSWORD=$SA_PASS" \
    -e "MSSQL_PID=Developer" \
    -p 1433:1433 \
    "$IMAGE" >/dev/null

echo -n ">> Aguardando o SQL Server aceitar conexões"
for i in $(seq 1 60); do
    if docker exec "$CONTAINER" $SQLCMD -S localhost -U sa -P "$SA_PASS" -C -Q "SELECT 1" >/dev/null 2>&1; then
        echo " pronto!"
        break
    fi
    echo -n "."
    sleep 2
    if [ "$i" -eq 60 ]; then echo; echo "ERRO: timeout aguardando SQL Server"; docker logs "$CONTAINER" | tail -30; exit 1; fi
done

echo ">> Copiando scripts para o contêiner..."
docker exec "$CONTAINER" mkdir -p /sql
docker cp "$HERE/sql/." "$CONTAINER:/sql/"

run() {
    echo ">> Executando $1"
    docker exec "$CONTAINER" $SQLCMD -S localhost -U sa -P "$SA_PASS" -C -b -i "/sql/$1"
}

run 00_create_database.sql
run 01_ddl_staging.sql
run 02_ddl_dimensions.sql
run 03_ddl_facts.sql
run 04_seed_static_dims.sql
run 05_functions.sql
run 06_views.sql
run 07_sp_etl.sql
run 08_sp_analytics.sql
run 09_triggers.sql
run 10_indexes.sql
run 11_dcl_security.sql
run 12_run_pipeline.sql
run 13_demo_triggers_seguranca.sql

echo ""
echo ">> CONCLUIDO. O banco EcommerceDW está ativo no contêiner '$CONTAINER' (porta 1433)."
echo ">> Conectar:  docker exec -it $CONTAINER $SQLCMD -S localhost -U sa -P '$SA_PASS' -C -d EcommerceDW"
echo ">> Parar/remover:  docker rm -f $CONTAINER"
