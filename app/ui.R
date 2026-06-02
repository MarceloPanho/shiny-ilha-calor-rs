# =============================================================
# ui.R - Ilha de Calor Urbana / RS
# =============================================================
library(shiny)
library(DT)
library(leaflet)
library(plotly)

shinyUI(fluidPage(
  titlePanel("Ilha de Calor Urbana - Rio Grande do Sul (MODIS LST)"),

  tabsetPanel(
    id = "modo", type = "tabs",

    # ---------- PARTE 1: CONSULTA UNICA ----------------------
    tabPanel(
      "Consulta Unica",
      sidebarLayout(
        sidebarPanel(
          width = 3,
          helpText("Temperatura de superficie (LST) media por municipio.",
                   "Filtre por regiao para refinar a consulta."),
          selectInput("rgint_u", "Regiao Intermediaria",
                      choices = c("Todas"), selected = "Todas"),
          selectInput("rgi_u", "Regiao Imediata",
                      choices = c("Todas"), selected = "Todas"),
          selectInput("municipio_u", "Municipio em destaque",
                      choices = NULL)
        ),
        mainPanel(
          tabsetPanel(
            type = "tabs",
            tabPanel("Mapa",    leafletOutput("mapa_u", height = 600)),
            tabPanel("Grafico", plotlyOutput("grafico_u", height = 600)),
            tabPanel("Tabela",  DT::DTOutput("tabela_u"))
          )
        )
      )
    ),

    # ---------- PARTE 2: CONSULTA COMPARATIVA ----------------
    tabPanel(
      "Consulta Comparativa",
      sidebarLayout(
        sidebarPanel(
          width = 3,
          helpText("Compare a ilha de calor entre dois municipios."),
          selectInput("municipio_a", "Municipio A", choices = NULL),
          selectInput("municipio_b", "Municipio B", choices = NULL)
        ),
        mainPanel(
          tabsetPanel(
            type = "tabs",
            tabPanel("Mapa",    leafletOutput("mapa_c", height = 600)),
            tabPanel("Grafico", plotlyOutput("grafico_c", height = 600)),
            tabPanel("Tabela",  DT::DTOutput("tabela_c"))
          )
        )
      )
    )
  ),

  tags$hr(),
  tags$small(
    "Raster: MODIS MOD11A2.061 LST Day 1km (NASA LP DAAC). ",
    "Vetor: Malha Municipal IBGE 2025 - RS. ",
    "Conversao: valor x 0.02 - 273.15 = graus Celsius."
  )
))
