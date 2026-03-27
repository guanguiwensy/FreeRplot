# =============================================================================
# File   : R/ui/panel_code.R
# Purpose: R Code tab UI — copy-to-clipboard button and the verbatim code
#          output box.  The copy button uses inline JS (copyRCode()) defined
#          in ui.R's <head> block.
#          Mirrors server output$r_code_output in R/modules/mod_plot.R.
#
# Exports:
#   tab_code_ui()
#     Returns the complete content for the "R Code" tabPanel.
#     No parameters.
# =============================================================================

tab_code_ui <- function() {
  div(
    class = "p-3",
    div(
      style = "position: relative;",
      tags$button(
        id      = "copy_code_btn",
        "Copy Code",
        onclick = "copyRCode()",
        class   = "btn btn-sm btn-outline-secondary",
        style   = paste0(
          "position:absolute; top:6px; right:6px; z-index:10; ",
          "font-size:0.78rem;"
        )
      ),
      verbatimTextOutput("r_code_output")
    )
  )
}
