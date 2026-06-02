-- =============================================================
-- Inicializacao do banco geografico PostGIS (roda 1x na criacao)
-- Estrutura conforme db_raster_estrutura.sql
-- =============================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_raster;

-- Habilita drivers GDAL (necessario para operacoes raster avancadas)
ALTER DATABASE "ilha-de-calor" SET postgis.gdal_enabled_drivers = 'ENABLE_ALL';

-- Tabela que recebera o raster MODIS LST (importado via raster2pgsql no 02_load.sh)
CREATE TABLE IF NOT EXISTS public.dados_raster (
    id       BIGSERIAL PRIMARY KEY,
    date     DATE DEFAULT CURRENT_DATE,
    rast     RASTER,
    filename TEXT
);
