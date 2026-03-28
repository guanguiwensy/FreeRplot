# =============================================================================
# File   : test_resizable_layout.R
# Purpose: Minimal regression check for the resizable IDE-style layout shell.
#          Verifies that the top-level UI exposes the expected splitter
#          containers, handles, and client-side script entrypoints.
#
# Usage:
#   & 'I:\R\R\R-4.4.2\bin\R.exe' -q -f test_resizable_layout.R
#
# Exit:
#   Stops with an error if any required layout marker is missing.
# =============================================================================

suppressWarnings(suppressMessages(source("global.R")))
suppressWarnings(suppressMessages(source("ui.R")))

tags <- htmltools::renderTags(ui)
markup <- paste(tags$head, tags$html, sep = "\n")

checks <- list(
  app_shell = 'id="app-shell"',
  main_resizer = 'id="main-resizer"',
  workspace_shell = 'id="workspace-shell"',
  workspace_resizer = 'id="workspace-resizer"',
  panes_script = 'src="panes.js"',
  plot_preview_card = 'plot-preview-card',
  workbench_shell = 'workbench-shell'
)

missing <- names(checks)[!vapply(checks, function(pattern) {
  grepl(pattern, markup, fixed = TRUE)
}, logical(1))]

if (!file.exists(file.path("www", "panes.js"))) {
  missing <- c(missing, "panes_js_file")
}

if (length(unique(missing)) > 0) {
  stop(
    sprintf(
      "Resizable layout markers missing: %s",
      paste(unique(missing), collapse = ", ")
    )
  )
}

cat("Resizable layout UI markers: PASS\n")
