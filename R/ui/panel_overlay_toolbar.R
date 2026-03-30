# =============================================================================
# File   : R/ui/panel_overlay_toolbar.R
# Purpose: Overlay toolbar UI fragment used by the plot preview header.
#          Keeps overlay-specific controls separated from the core plot panel.
#
# Exports:
#   overlay_toolbar_ui()
#     Returns a tagList with overlay tool controls and combined export buttons.
# =============================================================================

overlay_toolbar_ui <- function() {
  tagList(
    selectInput(
      "overlay_tool",
      label = NULL,
      choices = c(
        "Select" = "select",
        "Triangle" = "triangle",
        "Rectangle" = "rect",
        "Arrow" = "arrow",
        "Text" = "text",
        "Extra Data" = "extra_data",
        "Inset" = "inset"
      ),
      selected = "select",
      width = "128px"
    ),
    textInput(
      "overlay_text_value",
      label = NULL,
      value = "Label",
      width = "120px",
      placeholder = "Text"
    ),
    actionButton("overlay_delete_btn", "Delete", class = "btn btn-outline-secondary btn-sm"),
    actionButton("overlay_clear_btn", "Clear Overlay", class = "btn btn-outline-secondary btn-sm"),
    downloadButton("download_combined_svg", "SVG+Overlay", class = "btn btn-outline-secondary btn-sm"),
    downloadButton("download_combined_pdf", "PDF+Overlay", class = "btn btn-outline-secondary btn-sm")
  )
}
