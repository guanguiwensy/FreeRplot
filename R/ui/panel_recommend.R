# =============================================================================
# File   : R/ui/panel_recommend.R
# Purpose: Chart recommendation panel shown below AI chat (left column).
#          Static shell only — dynamic content is rendered by
#          output$chart_recommend_ui in R/ui/chat_renderers.R.
#
#          Interaction flow:
#            "图形推荐" button (recommend_run_btn)
#              → settings modal: column selection + count (rec_col_select,
#                rec_count, rec_run_confirm_btn)
#              → recommendation engine runs in server
#              → chart_recommend_ui fills with preview card grid
#              → each card has a "使用" button (rec_select_{chart_id})
#
# Exports:
#   chart_recommend_panel_ui()
#     Returns the bslib card shell with header controls and
#     uiOutput("chart_recommend_ui") body.  No parameters.
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
