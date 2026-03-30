# =============================================================================
# File   : R/ui/panel_plot.R
# Purpose: Plot preview card UI — chart type selector, generate/download
#          buttons, overlay toolbar, and plot output area.
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
    fill  = TRUE,
    card_header(
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

          overlay_toolbar_ui(),

          downloadButton("download_plot",     "PNG", class = "btn btn-outline-secondary btn-sm"),
          downloadButton("download_plot_pdf", "PDF", class = "btn btn-outline-secondary btn-sm"),

          div(
            class = "pane-header-controls",
            tags$button(
              type = "button",
              class = "btn btn-outline-secondary btn-sm pane-ctrl-btn",
              title = "Minimize chart panel",
              `data-pane-action` = "toggle-min",
              `data-pane-target` = "pane-right-top",
              icon("minus")
            ),
            tags$button(
              type = "button",
              class = "btn btn-outline-secondary btn-sm pane-ctrl-btn",
              title = "Maximize chart panel",
              `data-pane-action` = "toggle-max",
              `data-pane-target` = "pane-right-top",
              icon("expand")
            )
          )
        )
      )
    ),

    bslib::as_fill_carrier(
      div(
        class = "plot-stage",
        div(
          id = "plot-overlay-host",
          class = "plot-overlay-host",
          bslib::as_fill_carrier(
            plotOutput("main_plot", fill = TRUE)
          ),
          tags$svg(
            id = "overlay_svg",
            class = "overlay-svg",
            viewBox = "0 0 1000 1000",
            preserveAspectRatio = "none",
            `aria-label` = "Overlay editor layer"
          )
        )
      )
    )
  )
}
