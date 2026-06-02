# =============================================================
# functions.R - Ilha de Calor Urbana / RS
# Acesso ao banco geografico PostGIS e calculo de LST por municipio
# Fonte raster:  MODIS MOD11A2.061 LST Day 1km (NASA LP DAAC / AppEEARS)
# Fonte vetor:   Malha Municipal IBGE 2025 - RS (SIRGAS2000 / EPSG:4326)
# =============================================================

library(DBI)
library(RPostgres)
library(sf)

# ---- Conexao (parametrizada por variaveis de ambiente) ------
# Defaults rodam contra o Postgres local; no docker-compose o host vira "db".
pgconf <- list(
  host     = Sys.getenv("PGHOST",     "localhost"),
  port     = Sys.getenv("PGPORT",     "5432"),
  dbname   = Sys.getenv("PGDATABASE", "ilha-de-calor"),
  user     = Sys.getenv("PGUSER",     "postgres"),
  password = Sys.getenv("PGPASSWORD", "postgres")
)

conectar <- function() {
  dbConnect(RPostgres::Postgres(),
            host     = pgconf$host,
            port     = pgconf$port,
            dbname   = pgconf$dbname,
            user     = pgconf$user,
            password = pgconf$password)
}

# Executa SQL que retorna data.frame comum
executeQuery <- function(sql) {
  con <- conectar()
  on.exit(dbDisconnect(con))
  dbGetQuery(con, sql)
}

# ---- Fator de conversao MODIS LST -> graus Celsius ----------
# valor_bruto * 0.02 (Kelvin) - 273.15 (Celsius)
LST_CELSIUS <- "(stats).mean::numeric*0.02-273.15"

# ---- Listas para os filtros em cascata ----------------------
listar_rgint <- function() {
  executeQuery(
    "SELECT DISTINCT nm_rgint FROM municipios
     WHERE nm_rgint IS NOT NULL ORDER BY nm_rgint"
  )$nm_rgint
}

listar_rgi <- function(rgint = NULL) {
  rgint <- if (is.null(rgint) || !nzchar(rgint)) "Todas"
           else gsub("'", "''", rgint)
  executeQuery(sprintf(
    "SELECT DISTINCT nm_rgi FROM municipios
     WHERE nm_rgi IS NOT NULL
       AND ('%1$s' = 'Todas' OR nm_rgint = '%1$s')
     ORDER BY nm_rgi", rgint))$nm_rgi
}

# Retorna vetor nomeado (cd_mun -> nm_mun) para selectInput
listar_municipios <- function(rgint = NULL, rgi = NULL) {
  rgint <- if (is.null(rgint) || !nzchar(rgint)) "Todas"
           else gsub("'", "''", rgint)
  rgi   <- if (is.null(rgi)   || !nzchar(rgi))   "Todas"
           else gsub("'", "''", rgi)
  df <- executeQuery(sprintf(
    "SELECT cd_mun, nm_mun FROM municipios
     WHERE ('%1$s' = 'Todas' OR nm_rgint = '%1$s')
       AND ('%2$s' = 'Todas' OR nm_rgi   = '%2$s')
     ORDER BY nm_mun", rgint, rgi))
  setNames(df$cd_mun, df$nm_mun)
}

# ---- Dados para TABELA e GRAFICO (sem geometria) ------------
# Recorta o raster por municipio (ST_Clip) e resume (ST_SummaryStats).
# O filtro opcional e resolvido no proprio SQL: havendo cd_muns usa-se a
# lista; caso contrario aplicam-se rgint/rgi ('Todas' = sem filtro).
lst_dados <- function(rgint = NULL, rgi = NULL, cd_muns = NULL) {
  muns <- "NULL::text[]"
  if (length(cd_muns)) {
    vals <- paste(sprintf("'%s'", gsub("'", "''", cd_muns)), collapse = ", ")
    muns <- sprintf("ARRAY[%s]::text[]", vals)
  }
  rgint <- if (is.null(rgint) || !nzchar(rgint)) "Todas"
           else gsub("'", "''", rgint)
  rgi   <- if (is.null(rgi)   || !nzchar(rgi))   "Todas"
           else gsub("'", "''", rgi)
  executeQuery(sprintf("
    WITH base AS (
      SELECT m.cd_mun, m.nm_mun, m.nm_rgi, m.nm_rgint, m.area_km2, m.geom,
             ST_SummaryStats(ST_Clip(r.rast, m.geom, true)) AS stats
      FROM municipios m
      JOIN dados_raster r ON ST_Intersects(r.rast, m.geom)
      WHERE CASE
              WHEN %1$s IS NOT NULL THEN m.cd_mun::text = ANY(%1$s)
              ELSE ('%2$s' = 'Todas' OR m.nm_rgint = '%2$s')
               AND ('%3$s' = 'Todas' OR m.nm_rgi   = '%3$s')
            END
    )
    SELECT cd_mun, nm_mun, nm_rgi, nm_rgint,
           ROUND(area_km2::numeric, 1)                    AS area_km2,
           ROUND(((stats).mean::numeric*0.02-273.15), 2)  AS lst_media,
           ROUND(((stats).min::numeric *0.02-273.15), 2)  AS lst_min,
           ROUND(((stats).max::numeric *0.02-273.15), 2)  AS lst_max,
           (stats).count                                  AS n_pixels
    FROM base
    WHERE (stats).count > 0
    ORDER BY lst_media DESC NULLS LAST", muns, rgint, rgi))
}

# ---- Dados para MAPA Leaflet (objeto sf com geometria) ------
lst_geo <- function(rgint = NULL, rgi = NULL, cd_muns = NULL) {
  muns <- "NULL::text[]"
  if (length(cd_muns)) {
    vals <- paste(sprintf("'%s'", gsub("'", "''", cd_muns)), collapse = ", ")
    muns <- sprintf("ARRAY[%s]::text[]", vals)
  }
  rgint <- if (is.null(rgint) || !nzchar(rgint)) "Todas"
           else gsub("'", "''", rgint)
  rgi   <- if (is.null(rgi)   || !nzchar(rgi))   "Todas"
           else gsub("'", "''", rgi)
  con <- conectar()
  on.exit(dbDisconnect(con))
  st_read(con, quiet = TRUE, query = sprintf("
    WITH base AS (
      SELECT m.cd_mun, m.nm_mun, m.nm_rgi, m.nm_rgint, m.area_km2, m.geom,
             ST_SummaryStats(ST_Clip(r.rast, m.geom, true)) AS stats
      FROM municipios m
      JOIN dados_raster r ON ST_Intersects(r.rast, m.geom)
      WHERE CASE
              WHEN %1$s IS NOT NULL THEN m.cd_mun::text = ANY(%1$s)
              ELSE ('%2$s' = 'Todas' OR m.nm_rgint = '%2$s')
               AND ('%3$s' = 'Todas' OR m.nm_rgi   = '%3$s')
            END
    )
    SELECT cd_mun, nm_mun, nm_rgi, nm_rgint,
           ROUND(area_km2::numeric, 1)                    AS area_km2,
           ROUND(((stats).mean::numeric*0.02-273.15), 2)  AS lst_media,
           ROUND(((stats).min::numeric *0.02-273.15), 2)  AS lst_min,
           ROUND(((stats).max::numeric *0.02-273.15), 2)  AS lst_max,
           (stats).count                                  AS n_pixels, base.geom
    FROM base
    WHERE (stats).count > 0
    ORDER BY lst_media DESC NULLS LAST", muns, rgint, rgi))
}
