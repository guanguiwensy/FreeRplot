# =============================================================================
# File   : test_r_code_sync.R
# Purpose: Focused regression checks for the template-style R code pipeline.
#          Covers:
#            1. exported R code includes current data and current settings blocks
#            2. exported R code uses readable chart templates instead of inlined plot_fn internals
#            3. R code output updates with current inputs without requiring Generate Plot
#            4. code-view UI exposes line numbers and syntax highlighting
#
# Usage:
#   & 'I:\R\R\R-4.4.2\bin\R.exe' -q -f test_r_code_sync.R
# =============================================================================

suppressWarnings(suppressMessages(source("global.R")))
suppressWarnings(suppressMessages(source("ui.R")))
suppressWarnings(suppressMessages(source("server.R")))

assert_true <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

test_r_code_output_prefers_readable_template_blocks <- function() {
  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = data.frame(
        x = c(101, 104, 108),
        y = c(3.2, 4.1, 4.8),
        group = c("甲组", "乙组", "甲组"),
        stringsAsFactors = FALSE
      ),
      current_plot = NULL,
      current_plot_code = NULL,
      suggestion = NULL,
      api_config = list(),
      pending_intent = NULL,
      patch_history = list(),
      messages = list()
    )
    init_mod_plot(input, output, session, rv)
    list(rv = rv)
  }

  shiny::testServer(server_under_test, {
    session$setInputs(chart_type_select = "scatter_basic")
    session$setInputs(plot_title = "模板测试图")
    session$setInputs(plot_width_in = 9)
    session$setInputs(plot_height_in = 5)
    session$setInputs(plot_dpi = 180)
    session$setInputs(x_range_mode = "manual", x_min = 100, x_max = 110)
    session$setInputs(y_range_mode = "manual", y_min = 3, y_max = 5)
    session$flushReact()

    code <- output$r_code_output

    expected_snippets <- c(
      "# ---- Current Data ----",
      "data <- structure(",
      "# ---- Current Settings ----",
      "plot_width_in  <- 9",
      "x_range_mode   <- \"manual\"",
      "# ---- Chart Template ----",
      "library(ggplot2)"
    )

    missing <- expected_snippets[!vapply(expected_snippets, function(snippet) {
      grepl(snippet, code, fixed = TRUE)
    }, logical(1))]

    assert_true(
      length(missing) == 0,
      paste("Template-style R code missing snippets:", paste(missing, collapse = ", "))
    )

    assert_true(
      !grepl("plot_fn <- function", code, fixed = TRUE),
      "Template-style R code should not inline the full plot_fn implementation."
    )
  })
}

test_build_r_code_view_ui_has_line_numbers_and_highlight <- function() {
  markup <- paste(as.character(build_r_code_view_ui(
    "x <- 1\n# comment\nprint(\"hi\")\nif (TRUE) y <- x + 1"
  )), collapse = "")

  expected_bits <- c(
    "code-line-number",
    "code-token-comment",
    "code-token-string",
    "code-token-keyword",
    "code-token-function"
  )

  missing <- expected_bits[!vapply(expected_bits, function(bit) {
    grepl(bit, markup, fixed = TRUE)
  }, logical(1))]

  assert_true(
    length(missing) == 0,
    paste("Code view markup missing highlight bits:", paste(missing, collapse = ", "))
  )
}

test_r_code_updates_with_current_inputs_without_generate <- function() {
  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = CHARTS[["scatter_basic"]]$sample_data,
      current_plot = NULL,
      current_plot_code = NULL,
      suggestion = NULL,
      api_config = list(),
      pending_intent = NULL,
      patch_history = list(),
      messages = list()
    )
    init_mod_plot(input, output, session, rv)
    list(rv = rv)
  }

  shiny::testServer(server_under_test, {
    session$setInputs(chart_type_select = "scatter_basic")
    session$setInputs(plot_title = "第一次标题")
    session$flushReact()

    code_before <- output$r_code_output
    assert_true(
      grepl("第一次标题", code_before, fixed = TRUE),
      "Template-style R code should reflect the current title immediately."
    )

    session$setInputs(plot_title = "第二次标题")
    session$flushReact()
    code_after <- output$r_code_output

    assert_true(
      !identical(code_after, code_before) &&
        grepl("第二次标题", code_after, fixed = TRUE),
      "Template-style R code should update with current inputs without waiting for Generate Plot."
    )
  })
}

tests <- list(
  r_code_output_prefers_readable_template_blocks = test_r_code_output_prefers_readable_template_blocks,
  build_r_code_view_ui_has_line_numbers_and_highlight = test_build_r_code_view_ui_has_line_numbers_and_highlight,
  r_code_updates_with_current_inputs_without_generate = test_r_code_updates_with_current_inputs_without_generate
)

for (name in names(tests)) {
  fn <- tests[[name]]
  fn()
  cat(sprintf("[PASS] %s\n", name))
}

cat("R code template regression checks: PASS\n")
