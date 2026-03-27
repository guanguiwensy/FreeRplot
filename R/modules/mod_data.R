# R/modules/mod_data.R
# Data-side server logic: sample loading, upload/paste import, and table editing.

init_mod_data <- function(input, output, session, rv) {

  observeEvent(input$chart_type_select, {
    rv$current_data <- CHARTS[[input$chart_type_select]]$sample_data
  }, ignoreNULL = TRUE)

  observeEvent(input$load_sample_btn, {
    rv$current_data <- CHARTS[[input$chart_type_select]]$sample_data
  })

  observeEvent(input$upload_file, {
    req(input$upload_file)
    tryCatch({
      data <- read.csv(input$upload_file$datapath, stringsAsFactors = FALSE,
                       encoding = "UTF-8")
      rv$current_data <- data
    }, error = function(e) {
      showNotification(paste("文件读取失败:", e$message), type = "error", duration = 5)
    })
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
