# =============================================================
# server.R - Ilha de Calor Urbana / RS
# =============================================================
library(shiny)
library(DT)
library(leaflet)
library(plotly)
library(sf)

source("functions.R")

# Paleta de cores para temperatura (frio -> quente)
pal_lst <- function(valores) {
  colorNumeric("YlOrRd", domain = valores, na.color = "#cccccc")
}

shinyServer(function(input, output, session) {

  # ---- Carga inicial das listas (uma vez) -------------------
  rgints <- listar_rgint()
  updateSelectInput(session, "rgint_u", choices = c("Todas", rgints))

  munis_all <- listar_municipios()
  updateSelectizeInput(session, "municipio_a", choices = munis_all,
                       selected = munis_all[["Porto Alegre"]], server = TRUE)
  updateSelectizeInput(session, "municipio_b", choices = munis_all,
                       selected = munis_all[["Cachoeira do Sul"]], server = TRUE)

  # =========================================================
  # PARTE 1 - CONSULTA UNICA
  # =========================================================

  # Cascata: regiao intermediaria -> regiao imediata
  observeEvent(input$rgint_u, {
    rgis <- listar_rgi(input$rgint_u)
    updateSelectInput(session, "rgi_u", choices = c("Todas", rgis), selected = "Todas")
  })

  # Cascata: regiao -> lista de municipios em destaque
  observeEvent(list(input$rgint_u, input$rgi_u), {
    munis <- listar_municipios(input$rgint_u, input$rgi_u)
    updateSelectInput(session, "municipio_u", choices = munis)
  })

  # Dados (tabela/grafico) e geometria (mapa) reativos ao filtro
  dados_u <- reactive({
    lst_dados(rgint = input$rgint_u, rgi = input$rgi_u)
  })
  geo_u <- reactive({
    lst_geo(rgint = input$rgint_u, rgi = input$rgi_u)
  })

  output$mapa_u <- renderLeaflet({
    g <- geo_u()
    validate(need(nrow(g) > 0, "Nenhum municipio para o filtro selecionado."))
    pal <- pal_lst(g$lst_media)
    sel <- input$municipio_u
    leaflet(g) |>
      addProviderTiles(providers$CartoDB.Positron) |>
      addPolygons(
        fillColor   = ~pal(lst_media),
        weight      = ~ifelse(cd_mun == sel, 3, 0.6),
        color       = ~ifelse(cd_mun == sel, "#000000", "#666666"),
        fillOpacity = 0.75,
        label       = ~sprintf("%s: %.1f C", nm_mun, lst_media),
        highlightOptions = highlightOptions(weight = 3, color = "#000", bringToFront = TRUE)
      ) |>
      addLegend("bottomright", pal = pal, values = ~lst_media,
                title = "LST media (C)", opacity = 0.8)
  })

  output$grafico_u <- renderPlotly({
    d <- dados_u()
    validate(need(nrow(d) > 0, "Sem dados para o filtro."))
    d <- head(d[order(-d$lst_media), ], 20)            # 20 mais quentes
    d$nm_mun <- factor(d$nm_mun, levels = rev(d$nm_mun))
    plot_ly(d, x = ~lst_media, y = ~nm_mun, type = "bar", orientation = "h",
            marker = list(color = ~lst_media, colorscale = "YlOrRd"),
            hovertemplate = "%{y}: %{x:.1f} C<extra></extra>") |>
      layout(title = "Municipios mais quentes (LST media)",
             xaxis = list(title = "LST media (C)"), yaxis = list(title = ""))
  })

  output$tabela_u <- DT::renderDT({
    d <- dados_u()
    datatable(
      d[, c("nm_mun", "nm_rgi", "lst_media", "lst_min", "lst_max", "area_km2")],
      colnames = c("Municipio", "Regiao Imediata", "LST media (C)",
                   "LST min (C)", "LST max (C)", "Area (km2)"),
      rownames = FALSE, options = list(pageLength = 15)
    )
  })

  # =========================================================
  # PARTE 2 - CONSULTA COMPARATIVA
  # =========================================================

  dados_c <- reactive({
    req(input$municipio_a, input$municipio_b)
    lst_dados(cd_muns = c(input$municipio_a, input$municipio_b))
  })
  geo_c <- reactive({
    req(input$municipio_a, input$municipio_b)
    lst_geo(cd_muns = c(input$municipio_a, input$municipio_b))
  })

  output$mapa_c <- renderLeaflet({
    g <- geo_c()
    validate(need(nrow(g) > 0, "Selecione dois municipios validos."))
    pal <- pal_lst(g$lst_media)
    leaflet(g) |>
      addProviderTiles(providers$CartoDB.Positron) |>
      addPolygons(
        fillColor   = ~pal(lst_media),
        weight      = 2, color = "#000000", fillOpacity = 0.75,
        label       = ~sprintf("%s: %.1f C", nm_mun, lst_media)
      ) |>
      addLegend("bottomright", pal = pal, values = ~lst_media,
                title = "LST media (C)", opacity = 0.8)
  })

  output$grafico_c <- renderPlotly({
    d <- dados_c()
    validate(need(nrow(d) == 2, "Selecione dois municipios distintos."))
    plot_ly(d, x = ~nm_mun, y = ~lst_media, type = "bar", name = "Media",
            marker = list(color = "#e34a33")) |>
      add_trace(y = ~lst_min, name = "Minima", marker = list(color = "#fdbb84")) |>
      add_trace(y = ~lst_max, name = "Maxima", marker = list(color = "#b30000")) |>
      layout(barmode = "group",
             title = sprintf("Comparativo - diferenca de ilha de calor: %.1f C",
                             abs(d$lst_media[1] - d$lst_media[2])),
             yaxis = list(title = "LST (C)"), xaxis = list(title = ""))
  })

  output$tabela_c <- DT::renderDT({
    d <- dados_c()
    datatable(
      d[, c("nm_mun", "nm_rgint", "lst_media", "lst_min", "lst_max", "area_km2")],
      colnames = c("Municipio", "Regiao Intermediaria", "LST media (C)",
                   "LST min (C)", "LST max (C)", "Area (km2)"),
      rownames = FALSE, options = list(dom = "t")
    )
  })
})
