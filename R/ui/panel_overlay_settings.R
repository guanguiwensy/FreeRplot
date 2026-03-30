# =============================================================================
# File   : R/ui/panel_overlay_settings.R
# Purpose: Overlay settings section UI fragment used by the Settings tab.
#          Keeps overlay-specific controls separated from other chart settings.
#
# Exports:
#   overlay_settings_section_ui()
#     Returns a settings card for configuring overlay extra data sources.
# =============================================================================

overlay_settings_section_ui <- function() {
  div(
    class = "settings-section-card",
    div(class = "settings-section-title", "Overlay Layer"),
    tags$p(
      class = "settings-section-help",
      "Overlay uses a front-end SVG layer on top of the plot. It does not modify R plotting code."
    ),
    selectInput(
      "overlay_data_source",
      "Extra Data Source",
      choices = c("Shared Data" = "shared", "Custom JSON" = "custom"),
      selected = "shared",
      width = "100%"
    ),
    textAreaInput(
      "overlay_extra_data_json",
      "Custom Extra Data JSON",
      rows = 5,
      width = "100%",
      placeholder = "[{\"x\": 1, \"y\": 3, \"color\": \"#e63946\", \"size\": 3}, {\"x\": 2, \"y\": 5}]"
    ),
    tags$small(
      class = "settings-inline-note",
      "Custom JSON supports x/y fields. color/size are optional."
    ),
    tags$hr(style = "margin: 12px 0;"),
    div(class = "settings-section-subtitle", "Style & Annotation Editor"),
    tags$p(
      class = "settings-section-help",
      "Select an overlay object, then adjust style directly. Supports drag, resize, delete, color, opacity, and text font."
    ),
    div(
      class = "overlay-style-grid",
      div(
        class = "overlay-style-item",
        tags$label(`for` = "overlay_fill_color", "Fill"),
        tags$input(id = "overlay_fill_color", type = "color", value = "#66c2ff", class = "form-control form-control-color")
      ),
      div(
        class = "overlay-style-item",
        tags$label(`for` = "overlay_stroke_color", "Stroke"),
        tags$input(id = "overlay_stroke_color", type = "color", value = "#0d6efd", class = "form-control form-control-color")
      ),
      div(
        class = "overlay-style-item",
        tags$label(`for` = "overlay_stroke_width", "Stroke Width"),
        numericInput("overlay_stroke_width", NULL, value = 2, min = 0.5, max = 20, step = 0.5, width = "100%")
      ),
      div(
        class = "overlay-style-item",
        tags$label(`for` = "overlay_opacity", "Opacity"),
        numericInput("overlay_opacity", NULL, value = 0.85, min = 0.05, max = 1, step = 0.05, width = "100%")
      ),
      div(
        class = "overlay-style-item",
        tags$label(`for` = "overlay_font_size", "Font Size"),
        numericInput("overlay_font_size", NULL, value = 26, min = 8, max = 180, step = 1, width = "100%")
      ),
      div(
        class = "overlay-style-item",
        tags$label(`for` = "overlay_font_family", "Font Family"),
        selectInput(
          "overlay_font_family",
          NULL,
          choices = c(
            "Segoe UI" = "Segoe UI",
            "PingFang SC" = "PingFang SC",
            "Microsoft YaHei" = "Microsoft YaHei",
            "Arial" = "Arial",
            "Times New Roman" = "Times New Roman",
            "Courier New" = "Courier New"
          ),
          selected = "Segoe UI",
          width = "100%"
        )
      ),
      div(
        class = "overlay-style-item",
        tags$label(`for` = "overlay_font_weight", "Font Weight"),
        selectInput(
          "overlay_font_weight",
          NULL,
          choices = c("Normal" = "normal", "Medium" = "500", "Semibold" = "600", "Bold" = "700"),
          selected = "600",
          width = "100%"
        )
      ),
      div(
        class = "overlay-style-item",
        tags$label(`for` = "overlay_text_color", "Text Color"),
        tags$input(id = "overlay_text_color", type = "color", value = "#111111", class = "form-control form-control-color")
      )
    )
  )
}
