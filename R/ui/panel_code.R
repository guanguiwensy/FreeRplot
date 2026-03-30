# =============================================================================
# FILE:    R/ui/panel_code.R
# PURPOSE: Code tab UI — shinyAce editor that is both the source of truth for
#          plot generation and an editable, exportable R code window.
#
#          Architecture (code-first):
#            1. Chart selection → server populates editor via updateAceEditor()
#            2. User edits code freely (syntax-highlighted, Ctrl+Enter = Run)
#            3. AI modifies code via search/replace patches, then auto-runs
#            4. "Copy standalone" exports a self-contained script with data inline
#
# Exports:
#   tab_code_ui()
#     Returns the full content div for the "Code" tabPanel.
#     No parameters.
#
# Shiny I/O contract:
#   input$plot_code          [chr] live editor content (shinyAce binding)
#   input$run_code_btn       [int] click counter for the Run button
#   output$run_status_ui     renderUI — success badge / error message
#   output$r_code_output     renderText — hidden raw export (for copy)
#   output$r_code_copy_store renderUI  — hidden store for copy-to-clipboard
# =============================================================================

tab_code_ui <- function() {
  div(
    class = "tab-pane-shell code-pane-shell p-3",

    # ── Toolbar ───────────────────────────────────────────────────────────────
    div(
      class = "code-toolbar",
      div(
        class = "code-toolbar-copy",
        div(class = "code-toolbar-title", "可编辑 R 代码"),
        div(class = "code-toolbar-note",
            "直接编辑代码，按 Run 或 Ctrl+Enter 执行；AI 对话也会在此修改代码")
      ),
      div(
        class = "d-flex gap-2 align-items-center",

        # Run status badge (success / error)
        uiOutput("run_status_ui", inline = TRUE),

        # Copy standalone script button
        tags$button(
          id    = "copy_code_btn",
          class = "btn btn-sm code-copy-btn",
          type  = "button",
          onclick           = "copyRCode()",
          `data-default-label` = "复制完整代码",
          `data-success-label` = "已复制",
          `data-failed-label`  = "复制失败",
          "复制完整代码"
        )
      )
    ),

    # ── shinyAce editor ───────────────────────────────────────────────────────
    div(
      class = "code-editor-wrap",
      style = "border: 1px solid #dee2e6; border-radius: 6px; overflow: hidden; margin-top: 8px;",

      shinyAce::aceEditor(
        outputId   = "plot_code",
        value      = paste0(
          "# Data/context is prepared by backend before code execution.\n",
          "# Select a chart type to load its template.\n\n",
          "ggplot(data, aes(x = .data[[x_col]], y = .data[[y_col]])) +\n",
          "  geom_point(alpha = 0.8, size = 3) +\n",
          "  labs(title = \"\", x = x_col, y = y_col) +\n",
          "  theme_minimal()\n"
        ),
        mode       = "r",
        theme      = "chrome",
        fontSize   = 13,
        tabSize    = 2,
        useSoftTabs = TRUE,
        showLineNumbers = TRUE,
        highlightActiveLine = TRUE,
        autoComplete = "disabled",
        height     = "340px",
        # Ctrl+Enter triggers run_code_btn (handled by JS below)
        hotkeys    = list(
          run_code = list(
            win = "Ctrl-Return",
            mac = "Command-Return"
          )
        )
      )
    ),

    # Ctrl+Enter hotkey → click the run button (shinyAce fires input$plot_code_run_code)
    tags$script(HTML(
      "$(document).on('shiny:inputchanged', function(e) {
         if (e.name === 'plot_code_run_code') {
           $('#run_code_btn').click();
         }
       });"
    )),

    # ── Run button ────────────────────────────────────────────────────────────
    div(
      class = "d-flex align-items-center gap-2 mt-2",
      actionButton(
        "run_code_btn", "Run",
        class = "btn btn-success btn-sm",
        icon  = icon("play")
      ),
      tags$small(
        class = "text-muted",
        "Ctrl+Enter"
      )
    ),

    # ── Hidden stores for copy-to-clipboard ───────────────────────────────────
    div(
      class = "code-raw-store",
      style = "display:none;",
      textOutput("r_code_output"),
      uiOutput("r_code_copy_store")
    )
  )
}
