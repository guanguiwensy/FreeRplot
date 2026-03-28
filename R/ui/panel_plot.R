# =============================================================================
# File   : R/ui/panel_plot.R
# Purpose: Plot preview card UI — chart type selector, generate/download
#          buttons, and the spinner-wrapped plot output area.
#          Mirrors render logic in R/modules/mod_plot.R (output$main_plot).
#
# Exports:
#   plot_preview_card_ui()
#     Returns a bslib card with the chart selector header and plot area.
#     No parameters — choices are built from CHARTS (available after global.R).
# =============================================================================

plot_preview_card_ui <- function() {
  card(
    class = "plot-preview-card pane-card",
    style = "height: 100%; display: flex; flex-direction: column; min-height: 0;",
    card_header(
      style = "flex-shrink: 0;",
      div(
        class = "d-flex align-items-center gap-2 flex-wrap",
        span("Chart Preview"),
        div(
          class = "ms-auto d-flex align-items-center gap-2 flex-wrap",

          # Two-level grouped dropdown (rendered as <optgroup> by selectize.js)
          selectInput(
            "chart_type_select",
            label    = NULL,
            choices  = build_grouped_choices(CHARTS),
            selected = "scatter_basic",
            width    = "185px"
          ),

          actionButton(
            "generate_btn", "Generate",
            class = "btn btn-success btn-sm",
            icon  = icon("wand-magic-sparkles")
          ),

          downloadButton("download_plot",     "PNG", class = "btn btn-outline-secondary btn-sm"),
          downloadButton("download_plot_pdf", "PDF", class = "btn btn-outline-secondary btn-sm")
        )
      )
    ),

    div(
      class = "plot-stage",
      shinycssloaders::withSpinner(
        plotOutput("main_plot", height = "100%", width = "100%"),
        color = "#2c7be5",
        type  = 6
      )
    )
  )
}
