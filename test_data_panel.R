# =============================================================================
# File   : test_data_panel.R
# Purpose: Focused regression checks for the Data tab behavior.
#          Covers:
#            1. imported user data is not silently overwritten on chart switch
#            2. gallery chart switch does not silently overwrite user data
#            3. CSV download semantics and label stay aligned
#            4. paste import empty-state warning is shown
#            5. valid paste import updates rv$current_data
#            6. CSV upload handles Chinese data reliably
#
# Usage:
#   & 'I:\R\R\R-4.4.2\bin\R.exe' -q -f test_data_panel.R
# =============================================================================

suppressWarnings(suppressMessages(source("global.R")))
suppressWarnings(suppressMessages(source("ui.R")))
suppressWarnings(suppressMessages(source("server.R")))

assert_true <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

assert_equal <- function(x, y, msg) {
  if (!isTRUE(all.equal(x, y, check.attributes = FALSE))) {
    stop(msg, call. = FALSE)
  }
}

capture_notifications <- local({
  bucket <- list()

  list(
    reset = function() {
      bucket <<- list()
      invisible(NULL)
    },
    push = function(ui, type = NULL, duration = NULL, ...) {
      bucket <<- c(bucket, list(list(
        ui = paste(as.character(ui), collapse = ""),
        type = type %||% NA_character_,
        duration = duration %||% NA_real_
      )))
      invisible(NULL)
    },
    all = function() bucket
  )
})

with_notification_capture <- function(expr) {
  old_exists <- exists("showNotification", envir = .GlobalEnv, inherits = FALSE)
  if (old_exists) {
    old_fn <- get("showNotification", envir = .GlobalEnv, inherits = FALSE)
  }

  mod_data_env <- environment(init_mod_data)
  mod_data_old_exists <- exists("showNotification", envir = mod_data_env, inherits = FALSE)
  if (mod_data_old_exists) {
    mod_data_old_fn <- get("showNotification", envir = mod_data_env, inherits = FALSE)
  }

  assign("showNotification", capture_notifications$push, envir = .GlobalEnv)
  assign("showNotification", capture_notifications$push, envir = mod_data_env)
  on.exit({
    if (old_exists) {
      assign("showNotification", old_fn, envir = .GlobalEnv)
    } else {
      rm("showNotification", envir = .GlobalEnv)
    }

    if (mod_data_old_exists) {
      assign("showNotification", mod_data_old_fn, envir = mod_data_env)
    } else {
      rm("showNotification", envir = mod_data_env)
    }
  }, add = TRUE)

  capture_notifications$reset()
  force(expr)
}

test_data_ui_labels <- function() {
  markup <- as.character(tab_data_ui())

  expected_labels <- c(
    "\u52a0\u8f7d\u793a\u4f8b\u6570\u636e",
    "\u4e0b\u8f7d\u793a\u4f8b\u6570\u636e",
    "\u9009\u62e9\u6587\u4ef6",
    "\u4e0a\u4f20\u6570\u636e\u6587\u4ef6",
    "\u652f\u6301 .csv / .tsv / .xlsx",
    "\u6570\u636e\u5bfc\u5165",
    "\u6587\u4ef6\u5bfc\u5165",
    "\u7c98\u8d34\u6570\u636e\uff08Excel / WPS\uff09",
    "\u9996\u884c\u4e3a\u8868\u5934",
    "\u5bfc\u5165\u5230\u8868\u683c",
    "\u5f53\u524d\u6570\u636e\u6765\u6e90",
    "\u5f53\u524d\u56fe\u8868\u5b57\u6bb5",
    "\u5f53\u524d\u6570\u636e\u8868"
  )

  missing <- expected_labels[!vapply(expected_labels, function(label) {
    grepl(label, markup, fixed = TRUE)
  }, logical(1))]

  assert_true(length(missing) == 0, paste("Data tab labels missing:", paste(missing, collapse = ", ")))
}

test_data_ui_scroll_and_button_styles <- function() {
  markup <- as.character(tab_data_ui())
  css <- paste(readLines("www/styles.css", warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  assert_true(
    grepl("data-action-btn", markup, fixed = TRUE),
    "Data top action buttons should expose a dedicated styling class."
  )

  expected_css <- c(
    "overflow-y: auto;",
    "overflow-x: hidden;",
    "scrollbar-gutter: stable;",
    "display: inline-flex;",
    "justify-content: center;",
    "border-radius: 999px;"
  )

  missing_css <- expected_css[!vapply(expected_css, function(rule) {
    grepl(rule, css, fixed = TRUE)
  }, logical(1))]

  assert_true(
    length(missing_css) == 0,
    paste("Data tab style rules missing:", paste(missing_css, collapse = ", "))
  )
}

test_data_table_scroll_and_active_tab_styles <- function() {
  css <- paste(readLines("www/styles.css", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  panel_data_src <- paste(readLines("R/ui/panel_data.R", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  mod_data_src <- paste(readLines("R/modules/mod_data.R", warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  expected_css <- c(
    "background: #0d4aa2;",
    "color: #ffffff;",
    "font-weight: 700;",
    "text-shadow: none;",
    "flex: 0 0 auto;",
    "overflow: visible;"
  )

  missing_css <- expected_css[!vapply(expected_css, function(rule) {
    grepl(rule, css, fixed = TRUE)
  }, logical(1))]

  assert_true(
    length(missing_css) == 0,
    paste("Data table emphasis or active-tab style rules missing:", paste(missing_css, collapse = ", "))
  )

  assert_true(
    grepl('rHandsontableOutput\\("data_table", height = "200px"\\)', panel_data_src),
    "Current data table should be rendered with the original 200px height."
  )

  assert_true(
    !grepl("observeEvent\\(input\\$data_table,", mod_data_src),
    "Current data table should no longer use the live-edit observer."
  )

  disallowed_snippets <- c(
    "readOnly = FALSE",
    "highlightRow = TRUE",
    "highlightCol = TRUE",
    "scrollbar-color: #6f89ab #e4edf6;",
    ".handsontable td.current"
  )

  leaked <- disallowed_snippets[vapply(disallowed_snippets, function(snippet) {
    any(grepl(snippet, c(css, mod_data_src), fixed = TRUE))
  }, logical(1))]

  assert_true(
    length(leaked) == 0,
    paste("Current data table should not keep enhanced table rules:", paste(leaked, collapse = ", "))
  )
}

test_chart_switch_preserves_user_data <- function() {
  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = data.frame(user_x = 1:3, user_y = 4:6),
      current_data_source = "upload"
    )
    init_mod_data(input, output, session, rv)
    list(rv = rv)
  }

  shiny::testServer(server_under_test, {
    original <- rv$current_data
    session$setInputs(chart_type_select = "bar")
    assert_equal(rv$current_data, original, "Chart switch should not overwrite imported user data.")
  })
}

test_gallery_switch_preserves_user_data <- function() {
  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = data.frame(user_x = 10:12, user_y = 20:22),
      current_data_source = "upload",
      current_plot = NULL,
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
    original <- rv$current_data
    session$setInputs(gallery_bar = 1)
    assert_equal(rv$current_data, original, "Gallery chart switch should not overwrite imported user data.")
  })
}

test_download_csv_semantics <- function() {
  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = data.frame(user_x = 10:12, user_y = 20:22),
      current_plot = NULL,
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
    out_file <- output$download_csv
    assert_true(grepl("scatter_basic_sample_data\\.csv$", out_file), "CSV download filename should describe sample data.")
    out_df <- utils::read.csv(out_file, stringsAsFactors = FALSE)
    assert_equal(out_df, CHARTS[["scatter_basic"]]$sample_data, "CSV download should export current chart sample data.")
  })
}

test_empty_paste_warning <- function() {
  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = data.frame(x = 1:2, y = 3:4)
    )
    init_mod_data(input, output, session, rv)
    list(rv = rv)
  }

  with_notification_capture(
    shiny::testServer(server_under_test, {
      session$setInputs(chart_type_select = "scatter_basic")
      session$setInputs(paste_data_area = "   ")
      session$setInputs(paste_import_btn = 1)
      notes <- capture_notifications$all()
      assert_true(length(notes) >= 1, "Empty paste should trigger a warning notification.")
      assert_true(any(vapply(notes, function(note) {
        grepl("\u7c98\u8d34\u533a\u4e3a\u7a7a", note$ui, fixed = TRUE) && identical(note$type, "warning")
      }, logical(1))), "Empty paste warning text should be shown from the Data module.")
    })
  )
}

test_valid_paste_import <- function() {
  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = data.frame(x = 1:2, y = 3:4)
    )
    init_mod_data(input, output, session, rv)
    list(rv = rv)
  }

  with_notification_capture(
    shiny::testServer(server_under_test, {
      session$setInputs(chart_type_select = "scatter_basic")
      session$setInputs(paste_has_header = TRUE)
      session$setInputs(paste_data_area = "x\ty\n1\t2\n3\t4")
      session$setInputs(paste_import_btn = 1)

      expected <- data.frame(x = c(1, 3), y = c(2, 4))
      assert_equal(rv$current_data, expected, "Valid paste import should update rv$current_data.")

      notes <- capture_notifications$all()
      assert_true(any(vapply(notes, function(note) {
        identical(note$type, "message")
      }, logical(1))), "Successful paste import should show a success notification.")
    })
  )
}

test_csv_upload_chinese_data <- function() {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  upload_text <- paste(
    "category,value",
    "\u4e2d\u6587\u7ec4,1",
    "\u6d4b\u8bd5\u7ec4,2",
    sep = "\n"
  )
  writeBin(charToRaw(upload_text), tmp)

  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = data.frame(x = 1:2, y = 3:4)
    )
    init_mod_data(input, output, session, rv)
    list(rv = rv)
  }

  shiny::testServer(server_under_test, {
    session$setInputs(chart_type_select = "bar")
    session$setInputs(upload_file = list(
      name = "upload.csv",
      size = file.info(tmp)$size,
      type = "text/csv",
      datapath = tmp
    ))

    assert_true(
      "\u4e2d\u6587\u7ec4" %in% rv$current_data$category,
      "CSV upload should preserve Chinese text values."
    )
  })
}

test_tsv_upload_chinese_data <- function() {
  tmp <- tempfile(fileext = ".tsv")
  on.exit(unlink(tmp), add = TRUE)

  upload_text <- paste(
    "category\tvalue",
    "\u4e2d\u6587\u7ec4\t1",
    "\u6d4b\u8bd5\u7ec4\t2",
    sep = "\n"
  )
  writeBin(charToRaw(upload_text), tmp)

  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = data.frame(x = 1:2, y = 3:4)
    )
    init_mod_data(input, output, session, rv)
    list(rv = rv)
  }

  shiny::testServer(server_under_test, {
    session$setInputs(chart_type_select = "bar")
    session$setInputs(upload_file = list(
      name = "upload.tsv",
      size = file.info(tmp)$size,
      type = "text/tab-separated-values",
      datapath = tmp
    ))

    assert_true(
      "\u4e2d\u6587\u7ec4" %in% rv$current_data$category,
      "TSV upload should preserve Chinese text values."
    )
  })
}

test_xlsx_upload_first_sheet <- function() {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    cat("[SKIP] xlsx_upload_first_sheet (openxlsx unavailable)\n")
    return(invisible(NULL))
  }

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  openxlsx::write.xlsx(
    list(
      "\u9996\u4e2aSheet" = data.frame(
        category = c("\u4e2d\u6587\u7ec4", "\u6d4b\u8bd5\u7ec4"),
        value = c(1, 2),
        stringsAsFactors = FALSE
      ),
      "\u7b2c\u4e8c\u4e2aSheet" = data.frame(
        category = c("A", "B"),
        value = c(9, 10),
        stringsAsFactors = FALSE
      )
    ),
    file = tmp
  )

  server_under_test <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      current_data = data.frame(x = 1:2, y = 3:4)
    )
    init_mod_data(input, output, session, rv)
    list(rv = rv)
  }

  shiny::testServer(server_under_test, {
    session$setInputs(chart_type_select = "bar")
    session$setInputs(upload_file = list(
      name = "upload.xlsx",
      size = file.info(tmp)$size,
      type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      datapath = tmp
    ))

    assert_true(
      identical(rv$current_data$category[[1]], "\u4e2d\u6587\u7ec4"),
      "XLSX upload should read the first sheet."
    )
  })
}

tests <- list(
  data_ui_labels = test_data_ui_labels,
  data_ui_scroll_and_button_styles = test_data_ui_scroll_and_button_styles,
  data_table_scroll_and_active_tab_styles = test_data_table_scroll_and_active_tab_styles,
  chart_switch_preserves_user_data = test_chart_switch_preserves_user_data,
  gallery_switch_preserves_user_data = test_gallery_switch_preserves_user_data,
  download_csv_semantics = test_download_csv_semantics,
  empty_paste_warning = test_empty_paste_warning,
  valid_paste_import = test_valid_paste_import,
  csv_upload_chinese_data = test_csv_upload_chinese_data,
  tsv_upload_chinese_data = test_tsv_upload_chinese_data,
  xlsx_upload_first_sheet = test_xlsx_upload_first_sheet
)

for (name in names(tests)) {
  fn <- tests[[name]]
  fn()
  cat(sprintf("[PASS] %s\n", name))
}

cat("Data panel regression checks: PASS\n")
