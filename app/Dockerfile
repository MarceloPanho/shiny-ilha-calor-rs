# =============================================================
# Imagem da aplicacao Shiny (Ilha de Calor / RS)
# Base rocker/geospatial: ja traz GDAL/GEOS/PROJ, sf e terra.
# =============================================================
FROM rocker/geospatial:4.3.3

# Pacotes R adicionais usados pela aplicacao
RUN install2.r --error --skipinstalled \
    shiny \
    DT \
    leaflet \
    plotly \
    DBI \
    RPostgres \
 && rm -rf /tmp/downloaded_packages

WORKDIR /app
COPY ui.R server.R functions.R /app/

EXPOSE 3838

# Sobe o app escutando em todas as interfaces
CMD ["R", "-e", "shiny::runApp('/app', host='0.0.0.0', port=3838)"]
