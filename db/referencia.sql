-- ============================================================================
-- ILHA DE CALOR URBANA - RIO GRANDE DO SUL
-- Documentacao da estrutura do banco geografico + consultas espaciais de exemplo
--
-- ATENCAO: este arquivo e REFERENCIA/DOCUMENTACAO. Ele NAO e executado pelo
-- projeto. A criacao real do banco e feita pelos scripts em db/initdb/
-- (01_init.sql cria extensoes + tabela; 02_load.sh importa raster e shapefile).
-- As consultas abaixo podem ser rodadas a mao no psql/pgAdmin para explorar
-- os dados.
--
-- Conversao MODIS LST -> Celsius:  valor_bruto * 0.02 - 273.15
-- Raster: MODIS MOD11A2.061 LST Day 1km   |   Vetor: Malha Municipal IBGE 2025 (RS)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ESTRUTURA (reproduzida pelo db/initdb/01_init.sql)
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_raster;

-- Tabela que recebe o raster MODIS LST
CREATE TABLE IF NOT EXISTS public.dados_raster (
    id       BIGSERIAL PRIMARY KEY,
    date     DATE DEFAULT CURRENT_DATE,
    rast     RASTER,
    filename TEXT
);

-- A tabela "municipios" NAO e criada por DDL: o shp2pgsql a cria automaticamente
-- a partir do shapefile do IBGE, com todos os atributos (cd_mun, nm_mun, nm_rgi,
-- nm_rgint, cd_uf, sigla_uf, area_km2, geom MULTIPOLYGON em EPSG:4326, ...) e o
-- indice espacial GIST (flag -I).


-- ----------------------------------------------------------------------------
-- 2) IMPORTACAO DOS DADOS (executada pelo db/initdb/02_load.sh)
--    Caminhos relativos a raiz do repositorio.
-- ----------------------------------------------------------------------------
-- raster2pgsql -s 4326 -I -M -F data/raster/MOD11A2.061_LST_Day_1km_doy2026001000000_aid0001.tif \
--   -a public.dados_raster | psql -U postgres -d ilha-de-calor
--
-- shp2pgsql -s 4326 -I data/vetor/RS_Municipios_2025/RS_Municipios_2025.shp public.municipios \
--   | psql -U postgres -d ilha-de-calor


-- ----------------------------------------------------------------------------
-- 3) CONSULTA - TEMPERATURA EM UM PONTO (ST_Value)
--    Exemplo: centro de Porto Alegre
-- ----------------------------------------------------------------------------
SELECT ST_Value(rast, ST_SetSRID(ST_MakePoint(-51.2177, -30.0346), 4326)) * 0.02 - 273.15
       AS temp_celsius
FROM dados_raster
WHERE ST_Intersects(rast, ST_SetSRID(ST_MakePoint(-51.2177, -30.0346), 4326));


-- ----------------------------------------------------------------------------
-- 4) CONSULTA POR MUNICIPIO (a que a aplicacao usa em functions.R)
--    Recorta o raster pelo poligono de cada municipio (ST_Clip) e resume
--    (ST_SummaryStats). Exemplo: municipios da regiao intermediaria de POA.
-- ----------------------------------------------------------------------------
SELECT m.nm_mun,
       ROUND(((stats).mean::numeric * 0.02 - 273.15), 2) AS lst_media,
       ROUND(((stats).min ::numeric * 0.02 - 273.15), 2) AS lst_min,
       ROUND(((stats).max ::numeric * 0.02 - 273.15), 2) AS lst_max,
       (stats).count                                     AS n_pixels
FROM (
    SELECT m.gid, m.nm_mun,
           ST_SummaryStats(ST_Clip(r.rast, m.geom, true)) AS stats
    FROM municipios m
    JOIN dados_raster r ON ST_Intersects(r.rast, m.geom)
    WHERE m.nm_rgint = 'Porto Alegre'
) s
JOIN municipios m ON m.gid = s.gid
WHERE (s.stats).count > 0
ORDER BY lst_media DESC;


-- ----------------------------------------------------------------------------
-- 5) CONSULTA - DIFERENCA DE ILHA DE CALOR ENTRE DOIS MUNICIPIOS
--    (mesma logica da aba "Consulta Comparativa")
-- ----------------------------------------------------------------------------
WITH stats AS (
    SELECT m.nm_mun,
           (ST_SummaryStats(ST_Clip(r.rast, m.geom, true))).mean * 0.02 - 273.15 AS media
    FROM municipios m
    JOIN dados_raster r ON ST_Intersects(r.rast, m.geom)
    WHERE m.nm_mun IN ('Porto Alegre', 'Cachoeira do Sul')
)
SELECT
    ROUND(MAX(media) ::numeric, 2)                  AS mais_quente_c,
    ROUND(MIN(media) ::numeric, 2)                  AS mais_frio_c,
    ROUND((MAX(media) - MIN(media))::numeric, 2)    AS diferenca_ilha_de_calor_c
FROM stats;


-- ----------------------------------------------------------------------------
-- 6) CONSULTA - PIXELS COMO PONTOS (visualizacao no pgAdmin Geometry Viewer)
-- ----------------------------------------------------------------------------
SELECT ST_SetSRID(geom, 4326)                       AS geom,
       ROUND((val * 0.02 - 273.15)::numeric, 2)     AS temp_celsius
FROM (
    SELECT (ST_PixelAsPoints(rast, 1)).*
    FROM dados_raster
) pixels
WHERE val > 0;
