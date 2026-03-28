# =============================================================================
# File   : test_code_panel.R
# Purpose: Focused regression checks for the R code panel.
#          Covers:
#            1. code panel toolbar labels and synchronized code view slots
#            2. clipboard helper supports both primary and fallback paths
#            3. code panel CSS exposes editor-style layout rules
#
# Usage:
#   & 'I:\R\R\R-4.4.2\bin\R.exe' -q -f test_code_panel.R
# =============================================================================

suppressWarnings(suppressMessages(source("global.R")))
suppressWarnings(suppressMessages(source("ui.R")))
suppressWarnings(suppressMessages(source("server.R")))

assert_true <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

test_code_panel_ui_labels <- function() {
  markup <- as.character(tab_code_ui())

  expected_labels <- c(
    "可复现 R 代码",
    "复制代码",
    "当前图表对应的模板化 R 代码输出"
  )

  missing <- expected_labels[!vapply(expected_labels, function(label) {
    grepl(label, markup, fixed = TRUE)
  }, logical(1))]

  assert_true(
    length(missing) == 0,
    paste("R code panel labels missing:", paste(missing, collapse = ", "))
  )

  assert_true(
    !grepl("Copy Code", markup, fixed = TRUE),
    "R code panel should not keep the old English copy button label."
  )

  expected_slots <- c(
    "r_code_output",
    "r_code_copy_store",
    "r_code_view",
    "code-raw-store"
  )

  missing_slots <- expected_slots[!vapply(expected_slots, function(slot) {
    grepl(slot, markup, fixed = TRUE)
  }, logical(1))]

  assert_true(
    length(missing_slots) == 0,
    paste("R code panel view slots missing:", paste(missing_slots, collapse = ", "))
  )
}

test_copy_helper_has_primary_and_fallback_paths <- function() {
  ui_src <- paste(readLines("ui.R", warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  expected_snippets <- c(
    "r_code_copy_store",
    ".value",
    "navigator.clipboard.writeText",
    "document.execCommand('copy')",
    "copy_code_btn",
    "已复制",
    "复制失败"
  )

  missing <- expected_snippets[!vapply(expected_snippets, function(snippet) {
    grepl(snippet, ui_src, fixed = TRUE)
  }, logical(1))]

  assert_true(
    length(missing) == 0,
    paste("Copy helper snippets missing:", paste(missing, collapse = ", "))
  )

  assert_true(
    !grepl("document.getElementById\\('r_code_output'\\)", ui_src),
    "Copy helper should read from the dedicated hidden copy store instead of the textOutput host."
  )
}

test_code_panel_editor_styles <- function() {
  css <- paste(readLines("www/styles.css", warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  expected_rules <- c(
    ".code-toolbar",
    ".code-toolbar-title",
    ".code-copy-btn",
    ".code-pre-shell",
    ".code-line-number",
    ".code-token-comment",
    ".code-token-string",
    ".code-token-keyword",
    "white-space: pre;",
    "overflow-x: auto;"
  )

  missing <- expected_rules[!vapply(expected_rules, function(rule) {
    grepl(rule, css, fixed = TRUE)
  }, logical(1))]

  assert_true(
    length(missing) == 0,
    paste("R code panel style rules missing:", paste(missing, collapse = ", "))
  )
}

tests <- list(
  code_panel_ui_labels = test_code_panel_ui_labels,
  copy_helper_has_primary_and_fallback_paths = test_copy_helper_has_primary_and_fallback_paths,
  code_panel_editor_styles = test_code_panel_editor_styles
)

for (name in names(tests)) {
  fn <- tests[[name]]
  fn()
  cat(sprintf("[PASS] %s\n", name))
}

cat("R code panel regression checks: PASS\n")
