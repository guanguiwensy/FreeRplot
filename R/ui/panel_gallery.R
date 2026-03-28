# =============================================================================
# File   : R/ui/panel_gallery.R
# Purpose: Chart Gallery tab UI — a pill-tabset of all registered chart types
#          grouped by CHART_MENU_GROUPS.  Clicking a card switches the active
#          chart and loads its sample data.
#          Mirrors server output$chart_gallery_ui in R/modules/mod_plot.R.
#
# Exports:
#   tab_gallery_ui()
#     Returns the complete content for the "Chart Library" tabPanel.
#     The actual gallery buttons are rendered server-side via uiOutput so that
#     the active state highlights correctly at runtime.
#     No parameters.
# =============================================================================

tab_gallery_ui <- function() {
  div(class = "tab-pane-shell gallery-pane-shell p-3", uiOutput("chart_gallery_ui"))
}
