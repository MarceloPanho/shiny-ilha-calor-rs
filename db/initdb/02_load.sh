#!/usr/bin/env bash
# =============================================================
# Importa os dados geograficos no PostGIS (roda 1x na criacao).
# - Raster MODIS LST  -> tabela public.dados_raster (raster2pgsql)
# - Vetor municipios  -> tabela public.municipios   (shp2pgsql)
# Os arquivos de origem sao montados em /data (ver docker-compose.yml):
#   /data/raster/*.tif  e  /data/vetor/RS_Municipios_2025/*.shp
# =============================================================
set -euo pipefail

DB="${POSTGRES_DB:-ilha-de-calor}"
TIF=$(ls /data/raster/MOD11A2*.tif | head -1)
SHP=$(ls /data/vetor/*/*.shp | head -1)

echo ">> Importando raster MODIS LST: $TIF"
raster2pgsql -s 4326 -I -M -F "$TIF" -a public.dados_raster \
  | psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$DB"

echo ">> Importando shapefile de municipios: $SHP"
shp2pgsql -s 4326 -I "$SHP" public.municipios \
  | psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$DB"

echo ">> Carga concluida."
psql -U "$POSTGRES_USER" -d "$DB" -c \
  "SELECT (SELECT count(*) FROM dados_raster) AS rasters,
          (SELECT count(*) FROM municipios)   AS municipios;"
