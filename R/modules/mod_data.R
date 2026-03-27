# =============================================================================
# File   : R/modules/mod_data.R
# Purpose: Data server module — loads sample data when the chart type changes,
#          handles CSV file upload, handles Excel/WPS text paste, and renders
#          the editable rhandsontable grid.
#
# Depends: R/utils/logger.R  (log_debug, log_warn, safe_run)
#
# Exported functions:
#   init_mod_data(input, output, session, rv)
#     Registers all observers and outputs for data management.
#     Parameters:
#       input   [Shiny input]
#       output  [Shiny output]
#       session [Shiny session]
#       rv      [reactiveValues]  reads/writes rv$current_data
#
# Key observers / outputs:
#   observeEvent(input$chart_type_select)  auto-load sample data on chart switch
#   observeEvent(input$load_sample_btn)    manual sample data load
#   observeEvent(input$upload_file)        CSV upload → rv$current_data
#   observeEvent(input$paste_import_btn)   paste text → rv$current_data
#   output$data_table  renderRHandsontable — editable grid from rv$current_data
# =============================================================================

MODULE <- "mod_data"

init_mod_data <- function(input, output, session, rv) {

  observeEvent(input$chart_type_select, {
    log_debug(MODULE, "chart switched to '%s', loading sample data", input$chart_type_select)
    rv$current_data <- CHARTS[[input$chart_type_select]]$sample_data
  }, ignoreNULL = TRUE)

  observeEvent(input$load_sample_btn, {
    log_debug(MODULE, "load_sample_btn: chart='%s'", input$chart_type_select)
    rv$current_data <- CHARTS[[input$chart_type_select]]$sample_data
  })

  observeEvent(input$upload_file, {
    req(input$upload_file)
    log_info(MODULE, "upload_file: '%s'", input$upload_file$name)
    result <- safe_run(MODULE, {
      read.csv(input$upload_file$datapath, stringsAsFactors = FALSE, encoding = "UTF-8")
    })
    if (is.null(result)) {
      showNotification("File read failed. Check the file encoding (UTF-8 required).", type = "error", duration = 5)
    } else {
      rv$current_data <- result
      log_info(MODULE, "upload OK: %d rows x %d cols", nrow(result), ncol(result))
    }
  })

  observeEvent(input$paste_import_btn, {
    txt <- trimws(input$paste_data_area %||% "")
    if (!nzchar(txt)) {
      showNotification("粘贴区为空，请先粘贴数据。", type = "warning", duration = 3)
      return()
    }

    first_line <- trimws(strsplit(txt, "\n")[[1]][1])
    sep <- if (grepl("\t", first_line)) {
      "\t"
    } else if (grepl(";", first_line)) {
      ";"
    } else {
      ","
    }

    tryCatch({
      df <- read.table(
        text             = txt,
        sep              = sep,
        header           = isTRUE(input$paste_has_header),
        stringsAsFactors = FALSE,
        fill             = TRUE,
        quote            = "\"",
        check.names      = FALSE,
        encoding         = "UTF-8"
      )

      if (nrow(df) == 0 || ncol(df) == 0) {
        showNotification("未能解析出有效数据，请检查内容格式。", type = "warning", duration = 4)
        return()
      }

      rv$current_data <- df
      updateTextAreaInput(session, "paste_data_area", value = "")
      showNotification(
        paste0("✅ 已导入 ", nrow(df), " 行 × ", ncol(df), " 列"),
        type = "message", duration = 3
      )
    }, error = function(e) {
      showNotification(paste("解析失败:", e$message), type = "error", duration = 5)
    })
  })

  output$data_table <- renderRHandsontable({
    req(rv$current_data)
    rhandsontable(
      rv$current_data,
      rowHeaders = TRUE,
      stretchH   = "all",
      overflow   = "visible",
      colHeaders = names(rv$current_data)
    ) |>
      hot_context_menu(allowRowEdit = TRUE, allowColEdit = FALSE)
  })

  invisible(NULL)
}
