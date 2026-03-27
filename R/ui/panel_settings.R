# =============================================================================
# File   : R/ui/panel_settings.R
# Purpose: Settings tab UI — preset management row, global plot parameters
#          (title/labels/palette/theme/dimensions/axis ranges), and the
#          dynamic chart-specific options area.
#          Mirrors server logic in R/modules/mod_settings.R.
#
# Exports:
#   tab_settings_ui()
#     Returns the complete content for the "Settings" tabPanel.
#     No parameters — palette/theme choices come from global COLOR_PALETTES
#     and CHART_THEMES constants defined in R/plot_core.R.
# =============================================================================

tab_settings_ui <- function() {
  div(
    class = "p-3",

    # ── Preset row ────────────────────────────────────────────────────────
    div(
      class = "d-flex align-items-center gap-2 mb-1",
      tags$small(class = "text-muted fw-semibold text-nowrap", "Preset"),
      div(
        style = "flex:1; min-width:80px;",
        selectInput("preset_select", label = NULL,
                    choices = c("-- No Presets --" = ""), width = "100%")
      ),
      actionButton("preset_load_btn",   "Load",   class = "btn btn-sm btn-outline-primary", title = "Load selected preset"),
      actionButton("preset_save_btn",   "Save",   class = "btn btn-sm btn-outline-success", title = "Save current settings"),
      actionButton("preset_delete_btn", "Delete", class = "btn btn-sm btn-outline-danger",  title = "Delete selected preset")
    ),
    tags$hr(style = "margin: 4px 0 10px;"),

    # ── Title / labels ────────────────────────────────────────────────────
    layout_columns(
      col_widths = c(6, 6),
      textInput("plot_title", "Plot Title", placeholder = "(optional)"),
      textInput("x_label",    "X Label",    placeholder = "(optional)")
    ),
    layout_columns(
      col_widths = c(6, 6),
      textInput("y_label", "Y Label", placeholder = "(optional)"),
      selectInput("color_palette", "Palette",
                  choices  = names(COLOR_PALETTES),
                  selected = names(COLOR_PALETTES)[1])
    ),

    # ── Theme ─────────────────────────────────────────────────────────────
    selectInput("chart_theme", "Theme",
                choices  = names(CHART_THEMES),
                selected = names(CHART_THEMES)[1],
                width    = "100%"),

    # ── Export dimensions ─────────────────────────────────────────────────
    layout_columns(
      col_widths = c(4, 4, 4),
      numericInput("plot_width_in",  "Width (in)",  value = 10,  min = 2,  max = 40,  step = 0.5,  width = "100%"),
      numericInput("plot_height_in", "Height (in)", value = 6,   min = 2,  max = 40,  step = 0.5,  width = "100%"),
      numericInput("plot_dpi",       "PNG DPI",     value = 150, min = 72, max = 600, step = 10,   width = "100%")
    ),

    # ── Axis ranges ───────────────────────────────────────────────────────
    layout_columns(
      col_widths = c(4, 4, 4),
      selectInput("x_range_mode", "X Range",
                  choices = c("Auto" = "auto", "Manual" = "manual"),
                  selected = "auto", width = "100%"),
      numericInput("x_min", "X Min", value = NA_real_, step = 0.1, width = "100%"),
      numericInput("x_max", "X Max", value = NA_real_, step = 0.1, width = "100%")
    ),
    layout_columns(
      col_widths = c(4, 4, 4),
      selectInput("y_range_mode", "Y Range",
                  choices = c("Auto" = "auto", "Manual" = "manual"),
                  selected = "auto", width = "100%"),
      numericInput("y_min", "Y Min", value = NA_real_, step = 0.1, width = "100%"),
      numericInput("y_max", "Y Max", value = NA_real_, step = 0.1, width = "100%")
    ),
    tags$hr(style = "margin: 10px 0 6px;"),

    # ── Scene template cards (rendered server-side, shown for bar/scatter) ─
    uiOutput("bar_scene_ui"),
    uiOutput("scatter_scene_ui"),

    # ── Chart-specific option controls (generated from options_def) ────────
    uiOutput("chart_opts_ui")
  )
}
