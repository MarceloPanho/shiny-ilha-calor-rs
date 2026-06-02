# 🌡️ Ilha de Calor Urbana — Rio Grande do Sul

> Aplicação web geoespacial que cruza **imagens de satélite** (temperatura de superfície) com a
> **malha municipal do RS** para mapear e comparar a intensidade da ilha de calor urbana.

<p>
  <img alt="R" src="https://img.shields.io/badge/R-Shiny-1A6FB6">
  <img alt="PostGIS" src="https://img.shields.io/badge/PostgreSQL-PostGIS-336791">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Compose-2496ED">
  <img alt="Leaflet" src="https://img.shields.io/badge/Mapas-Leaflet-199900">
</p>

## Demonstração

![Demonstração da aplicação: filtros em cascata, mapa coroplético de LST e comparação entre municípios](docs/demo.webp)

> Filtragem em cascata por região, mapa coroplético de temperatura e comparação entre dois municípios.

---

## Sobre o projeto

Cidades costumam ser mais quentes que as áreas rurais ao redor — o fenômeno da **ilha de calor
urbana**. Este projeto torna esse efeito visível e comparável usando dados públicos: pega o raster
de **temperatura de superfície (LST)** do satélite MODIS, recorta-o pelos polígonos de cada
município gaúcho **dentro do banco de dados** e expõe o resultado em uma interface interativa.

Construí o projeto como peça de portfólio para demonstrar um pipeline geoespacial completo —
**dado bruto → banco espacial → análise sob demanda → visualização web** — empacotado de forma
que qualquer pessoa rode com um único comando.

## O que este projeto demonstra

- **Análise geoespacial dentro do banco** — o cálculo da temperatura por município roda em SQL
  espacial (`ST_Clip` + `ST_SummaryStats`), recortando o raster pelo polígono sob demanda em vez
  de processar tudo na aplicação.
- **Modelagem de dados raster + vetor** num mesmo PostGIS (MODIS LST × malha IBGE).
- **Aplicação reativa em Shiny** com filtros em cascata, mapa coroplético, gráficos e tabelas
  sincronizados.
- **Infraestrutura reprodutível** — `docker compose up` sobe banco e app, importa os dados na
  primeira inicialização e persiste em volume.
- **Consultas montadas via `sprintf`** com filtros resolvidos no próprio SQL (`CASE`/`ANY`) e
  *escape* de aspas nos valores; conexão configurável por variáveis de ambiente.

## Funcionalidades

| Modo | O que faz |
|------|-----------|
| **Consulta Única** | Filtros em cascata (Região Intermediária → Região Imediata → Município) com **mapa Leaflet** coroplético de LST média, **gráfico** de ranking dos municípios mais quentes e **tabela** com LST média/mín/máx e área. |
| **Consulta Comparativa** | Compara dois municípios lado a lado — mapa com ambos destacados, gráfico de barras e tabela com a **diferença de ilha de calor** entre eles. |

## Stack

**R / Shiny** (UI reativa) · **PostgreSQL + PostGIS** (banco geoespacial raster e vetor) ·
**Leaflet** (mapas) · **plotly** (gráficos) · **sf / DBI / RPostgres** (ponte R ↔ banco) ·
**Docker Compose** (orquestração).

## Fontes dos dados

### 🛰️ Dados de Temperatura — LST (raster)

- **Instituição:** NASA — *Earthdata*
- **Plataforma:** NASA AppEEARS — <https://appeears.earthdatacloud.nasa.gov>
- **Produto:** `MOD11A2.061` — MODIS/Terra *Land Surface Temperature/Emissivity*
- **Resolução:** 8-Day L3 Global 1km
- **Camada:** `LST_Day_1km`
- **Conversão para °C:** `valor × 0.02 − 273.15`

### 🗺️ Limites Municipais — Shapefile (vetor)

- **Instituição:** IBGE — Instituto Brasileiro de Geografia e Estatística
- **Fonte:** <https://www.ibge.gov.br/geociencias/organizacao-do-territorio/malhas-territoriais/15774-malhas.html>
- **Arquivo:** `RS_Municipios_2025.shp`
- **Cobertura:** Malha Municipal 2025 do RS (499 municípios, SIRGAS2000 / EPSG:4326)

## Como funciona

```
MODIS LST (raster .tif)  ─┐
                          ├─► PostGIS ──► ST_Clip + ST_SummaryStats ──► Shiny ──► Leaflet / plotly / DT
Malha IBGE (shapefile)  ──┘   (raster +     (LST por município,           (UI reativa)
                               vetor)        calculada sob demanda)
```

A LST de cada município **não é pré-computada**: ao filtrar, a aplicação recorta o raster pelo
polígono correspondente e resume as estatísticas na hora — só para os municípios selecionados.
A estrutura do banco e consultas espaciais de exemplo estão em
[`db/referencia.sql`](db/referencia.sql).

## Como rodar (Docker — recomendado)

Pré-requisito: Docker + Docker Compose.

```bash
docker compose up --build
```

Sobe dois serviços:

1. **db** — PostGIS que, na primeira inicialização, cria as extensões e importa automaticamente o
   raster (`raster2pgsql`) e o shapefile (`shp2pgsql`) a partir dos arquivos do repositório.
2. **shiny** — a aplicação, que aguarda o banco ficar pronto.

Depois abra **<http://localhost:3838>**.

> A primeira subida demora alguns minutos (build da imagem + carga dos dados). As seguintes são
> rápidas, pois o banco fica persistido no volume `pgdata`.
> Para recarregar do zero: `docker compose down -v && docker compose up --build`.

<details>
<summary><strong>Rodar localmente (sem Docker)</strong></summary>

Requer R, PostgreSQL com PostGIS e as libs de sistema GDAL/GEOS/PROJ (e `abseil` para o `sf`).

```r
install.packages(c("shiny","DT","leaflet","plotly","DBI","RPostgres","sf"))
```

```bash
# extensões + tabela
psql -U postgres -d ilha-de-calor -f db/initdb/01_init.sql

raster2pgsql -s 4326 -I -M -F data/raster/MOD11A2.061_LST_Day_1km_doy2026001000000_aid0001.tif \
  -a public.dados_raster | psql -U postgres -d ilha-de-calor

shp2pgsql -s 4326 -I data/vetor/RS_Municipios_2025/RS_Municipios_2025.shp public.municipios \
  | psql -U postgres -d ilha-de-calor

R -e "shiny::runApp('app', port=3838)"
```

A conexão é parametrizada por variáveis de ambiente (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`,
`PGPASSWORD`); os *defaults* apontam para `localhost:5432`, banco `ilha-de-calor`, usuário
`postgres`.

</details>

## Estrutura do projeto

```
.
├── app/                  # aplicação Shiny
│   ├── ui.R              #   interface: 2 abas, filtros, mapa/gráfico/tabela
│   ├── server.R          #   lógica reativa
│   ├── functions.R       #   acesso ao PostGIS e cálculo de LST por município
│   └── Dockerfile        #   imagem da app (base rocker/geospatial)
├── db/                   # banco geográfico
│   ├── Dockerfile        #   PostGIS + loaders raster2pgsql/shp2pgsql
│   ├── referencia.sql    #   estrutura documentada + consultas espaciais de exemplo
│   └── initdb/           #   scripts executados na 1ª inicialização do banco
│       ├── 01_init.sql   #     extensões + tabela dados_raster
│       └── 02_load.sh    #     importa o raster e o shapefile
├── data/                 # dados de origem
│   ├── raster/           #   MOD11A2...LST_Day_1km...tif (MODIS)
│   └── vetor/            #   RS_Municipios_2025/ (shapefile IBGE)
├── docker-compose.yml
└── README.md
```

## Modelo de dados

- `dados_raster` — o raster MODIS LST (`rast`).
- `municipios` — polígonos dos 499 municípios + atributos IBGE (`cd_mun`, `nm_mun`, `nm_rgi`,
  `nm_rgint`, `area_km2`, `geom`).

---

<sub>Projeto de portfólio · dados públicos NASA MODIS e IBGE.</sub>
