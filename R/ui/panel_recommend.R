# =============================================================================
# File   : R/ui/panel_recommend.R
# Purpose: Independent chart recommendation panel shown below AI chat.
#
# Exports:
#   chart_recommend_panel_ui()
#     Returns the recommendation card with:
#       - refresh button: "图形推荐"
#       - candidate actions: "选择" / "推荐理由"
#       - collapse toggle for hide/show
# =============================================================================

chart_recommend_panel_ui <- function() {
  card(
    id = "chart-recommend-card",
    class = "recommend-card pane-card",
    style = "display:flex; flex-direction:column; min-height:0;",
    card_header(
      div(
        class = "d-flex align-items-center justify-content-between gap-2 flex-wrap",
        div(
          class = "d-flex align-items-center gap-2",
          span("图形推荐")
        ),
        div(
          class = "d-flex align-items-center gap-2",
          actionButton(
            "recommend_run_btn",
            "图形推荐",
            class = "btn btn-sm btn-primary"
          ),
          tags$button(
            type = "button",
            class = "btn btn-outline-secondary btn-sm pane-ctrl-btn",
            title = "Minimize recommendation panel",
            `data-pane-action` = "toggle-sub-min",
            `data-pane-target` = "left-pane-recommend",
            icon("minus")
          ),
          tags$button(
            type = "button",
            class = "btn btn-outline-secondary btn-sm pane-ctrl-btn",
            title = "Maximize recommendation panel",
            `data-pane-action` = "toggle-sub-max",
            `data-pane-target` = "left-pane-recommend",
            icon("expand")
          )
        )
      )
    ),
    div(
      id = "recommend_panel_body",
      class = "recommend-panel-body",
      uiOutput("chart_recommend_ui")
    )
  )
}
