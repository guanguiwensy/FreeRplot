# =============================================================================
# File   : R/ui/panel_code.R
# Purpose: R Code tab UI — shallow IDE-style toolbar and the synchronized code
#          output area. The visible pane renders line numbers and syntax
#          highlighting, while a hidden raw-text store keeps copy-to-clipboard
#          output clean. The code shown here is a readable template-style
#          export, not a 1:1 dump of the internal plot execution path.
#
# Exports:
#   tab_code_ui()
#     Returns the complete content for the "R Code" tabPanel.
#     No parameters.
# =============================================================================

tab_code_ui <- function() {
  div(
    class = "tab-pane-shell code-pane-shell p-3",
    div(
      class = "code-panel-card",
      div(
        class = "code-toolbar",
        div(
          class = "code-toolbar-copy",
          div(class = "code-toolbar-title", "可复现 R 代码"),
          div(class = "code-toolbar-note", "当前图表对应的模板化 R 代码输出")
        ),
        tags$button(
          id = "copy_code_btn",
          "复制代码",
          onclick = "copyRCode()",
          class = "btn btn-sm code-copy-btn",
          type = "button",
          `data-default-label` = "复制代码",
          `data-success-label` = "已复制",
          `data-failed-label` = "复制失败"
        )
      ),
      div(
        class = "code-pre-shell",
        div(
          class = "code-raw-store",
          textOutput("r_code_output"),
          uiOutput("r_code_copy_store")
        ),
        uiOutput("r_code_view")
      )
    )
  )
}
