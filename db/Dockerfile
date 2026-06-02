# =============================================================
# Imagem do banco: PostGIS + ferramentas de carga (raster2pgsql,
# shp2pgsql), ausentes na imagem postgis/postgis base.
# Instaladas em build (como root) para os scripts de init usarem.
# =============================================================
FROM postgis/postgis:16-3.4

RUN apt-get update \
 && apt-get install -y --no-install-recommends postgis \
 && rm -rf /var/lib/apt/lists/*
