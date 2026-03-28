# =============================================================================
# File   : R/modules/mod_data.R
# Purpose: Data server module for the "Data" tab.
#          Handles sample-data switching, file import (.csv / .tsv / .xlsx),
#          Excel/WPS paste import, lightweight schema validation, source
#          tracking for the active table, and the editable rhandsontable grid.
#
# Depends: R/utils/logger.R  (log_debug, log_info, log_warn, log_error, safe_run)
#
# Exported functions:
#   init_mod_data(input, output, session, rv)
#     Registers all observers and outputs for data management.
#     Parameters:
#       input   [Shiny input]
#       output  [Shiny output]
#       session [Shiny session]
#       rv      [reactiveValues]  reads/writes:
#                 rv$current_data
#                 rv$current_data_source
#
# Key observers / outputs:
#   observeEvent(input$chart_type_select)  switches sample data only when safe
#   observeEvent(input$load_sample_btn)    explicit sample data reload
#   observeEvent(input$upload_file)        file import -> validate -> rv$current_data
#   observeEvent(input$paste_import_btn)   pasted table -> validate -> rv$current_data
#   output$data_source_ui                  current data-source badge
#   output$data_requirements_ui            current chart field summary
#   output$data_table                      editable grid from rv$current_data
# =============================================================================

local({
  .MODULE <- "mod_data"

  .as_plain_data_frame <- function(data) {
    if (is.null(data)) return(NULL)

    df <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
    df[] <- lapply(df, function(col) if (is.factor(col)) as.character(col) else col)

    if (ncol(df) > 0L) {
      names(df)[1] <- sub("^\ufeff", "", names(df)[1])
    }

    df
  }

  .same_data_frame <- function(x, y) {
    if (is.null(x) || is.null(y)) return(FALSE)
    isTRUE(all.equal(.as_plain_data_frame(x), .as_plain_data_frame(y), check.attributes = FALSE))
  }

  .live_table_data <- function(input, fallback = NULL) {
    tbl <- tryCatch(hot_to_r(input$data_table), error = function(e) NULL)
    if (is.null(tbl)) return(fallback)
    .as_plain_data_frame(tbl)
  }

  .sample_data_for_chart <- function(chart_id) {
    chart <- CHARTS[[chart_id]]
    if (is.null(chart) || !is.data.frame(chart$sample_data)) {
      stop(sprintf("Chart '%s' has no sample data.", chart_id))
    }
    .as_plain_data_frame(chart$sample_data)
  }

  .split_column_specs <- function(columns_txt) {
    if (!nzchar(columns_txt)) return(character(0))

    chars <- strsplit(columns_txt, "", fixed = TRUE)[[1]]
    parts <- character(0)
    current <- character(0)
    depth <- 0L

    for (ch in chars) {
      if (identical(ch, "(")) {
        depth <- depth + 1L
        current <- c(current, ch)
        next
      }

      if (identical(ch, ")")) {
        depth <- max(0L, depth - 1L)
        current <- c(current, ch)
        next
      }

      if (identical(ch, ",") && depth == 0L) {
        parts <- c(parts, paste(current, collapse = ""))
        current <- character(0)
        next
      }

      current <- c(current, ch)
    }

    parts <- c(parts, paste(current, collapse = ""))
    trimws(parts[nzchar(trimws(parts))])
  }

  .column_specs_for_chart <- function(chart_id) {
    if (is.null(chart_id) || !nzchar(chart_id) || is.null(CHARTS[[chart_id]])) {
      return(list())
    }

    chart <- CHARTS[[chart_id]]
    columns_txt <- trimws(as.character(chart$columns %||% ""))
    parts <- .split_column_specs(columns_txt)

    specs <- lapply(parts, function(part) {
      if (!nzchar(part)) return(NULL)

      name <- trimws(sub("\\s*\\(.*$", "", part))
      if (!nzchar(name)) return(NULL)

      desc <- if (grepl("(", part, fixed = TRUE)) {
        sub("^[^(]*\\((.*)\\)\\s*$", "\\1", part)
      } else {
        ""
      }

      list(
        name = name,
        optional = grepl("optional|可选", desc, ignore.case = TRUE),
        numeric = grepl("numeric|数值", desc, ignore.case = TRUE),
        desc = desc
      )
    })

    specs <- Filter(Negate(is.null), specs)

    if (length(specs) == 0L && !is.null(chart$sample_data)) {
      specs <- lapply(names(chart$sample_data), function(name) {
        list(name = name, optional = FALSE, numeric = FALSE, desc = "")
      })
    }

    specs
  }

  .align_import_columns <- function(df, chart_id) {
    specs <- .column_specs_for_chart(chart_id)
    if (length(specs) == 0L || ncol(df) == 0L) {
      return(list(ok = TRUE, data = df, renamed = FALSE, mapping_note = NULL))
    }

    old_names <- names(df)
    new_names <- old_names
    map_count <- min(length(specs), ncol(df))
    target_names <- vapply(specs[seq_len(map_count)], `[[`, character(1), "name")
    new_names[seq_len(map_count)] <- target_names

    if (anyDuplicated(new_names)) {
      dup_names <- unique(new_names[duplicated(new_names)])
      return(list(
        ok = FALSE,
        message = sprintf(
          "导入后的列名发生冲突：%s。请调整源数据后重试。",
          paste(dup_names, collapse = "、")
        )
      ))
    }

    names(df) <- new_names
    renamed <- !identical(old_names, new_names)
    mapping_note <- NULL

    if (renamed) {
      mapping_note <- paste(
        sprintf("%s→%s", old_names[seq_len(map_count)], new_names[seq_len(map_count)]),
        collapse = "；"
      )
    }

    list(ok = TRUE, data = df, renamed = renamed, mapping_note = mapping_note)
  }

  .validate_import_df <- function(df, chart_id) {
    df <- .as_plain_data_frame(df)

    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L || ncol(df) == 0L) {
      return(list(ok = FALSE, message = "未能解析出有效数据，请检查内容格式。"))
    }

    if (any(!nzchar(trimws(names(df))))) {
      return(list(ok = FALSE, message = "检测到空列名，请先补齐表头后再导入。"))
    }

    specs <- .column_specs_for_chart(chart_id)
    required_specs <- Filter(function(spec) !isTRUE(spec$optional), specs)

    if (length(required_specs) > 0L && ncol(df) < length(required_specs)) {
      return(list(
        ok = FALSE,
        message = sprintf(
          "当前图表至少需要 %d 列数据。可先点击“下载示例数据”查看格式。",
          length(required_specs)
        )
      ))
    }

    aligned <- .align_import_columns(df, chart_id)
    if (!isTRUE(aligned$ok)) return(aligned)
    df <- aligned$data

    required_names <- vapply(required_specs, `[[`, character(1), "name")
    missing_names <- setdiff(required_names, names(df))
    if (length(missing_names) > 0L) {
      return(list(
        ok = FALSE,
        message = sprintf(
          "当前图表缺少必需列：%s。可先点击“下载示例数据”查看格式。",
          paste(missing_names, collapse = "、")
        )
      ))
    }

    numeric_specs <- Filter(function(spec) {
      !isTRUE(spec$optional) && isTRUE(spec$numeric) && spec$name %in% names(df)
    }, specs)

    if (length(numeric_specs) > 0L) {
      bad_numeric <- vapply(numeric_specs, function(spec) {
        values <- suppressWarnings(as.numeric(df[[spec$name]]))
        !any(is.finite(values))
      }, logical(1))

      if (any(bad_numeric)) {
        bad_names <- vapply(numeric_specs[bad_numeric], `[[`, character(1), "name")
        return(list(
          ok = FALSE,
          message = sprintf("以下列需要为数值列：%s。", paste(bad_names, collapse = "、"))
        ))
      }
    }

    list(
      ok = TRUE,
      data = df,
      renamed = isTRUE(aligned$renamed),
      mapping_note = aligned$mapping_note %||% NULL
    )
  }

  .read_delimited_with_fallback <- function(path, sep, format_label) {
    encodings <- c("UTF-8-BOM", "UTF-8", "GB18030", "GBK", "")
    failures <- character()

    for (enc in encodings) {
      enc_label <- if (nzchar(enc)) enc else "default"
      log_debug(.MODULE, "trying %s import with fileEncoding='%s'", format_label, enc_label)

      args <- list(
        file = path,
        sep = sep,
        header = TRUE,
        stringsAsFactors = FALSE,
        fill = TRUE,
        quote = "\"",
        check.names = FALSE,
        comment.char = ""
      )
      if (nzchar(enc)) args$fileEncoding <- enc

      result <- tryCatch(
        suppressWarnings(do.call(utils::read.table, args)),
        error = function(e) e
      )

      if (!inherits(result, "error")) {
        return(list(
          ok = TRUE,
          data = .as_plain_data_frame(result),
          format = format_label,
          encoding = enc_label,
          log_detail = sprintf("encoding='%s'", enc_label)
        ))
      }

      failures <- c(failures, sprintf("%s: %s", enc_label, conditionMessage(result)))
    }

    log_error(.MODULE, "%s import failed for all encodings: %s", format_label, paste(failures, collapse = " | "))
    list(
      ok = FALSE,
      format = format_label,
      message = sprintf("%s 读取失败，请检查文件编码或内容格式。", format_label)
    )
  }

  .read_xlsx_first_sheet <- function(path) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      log_error(.MODULE, "readxl is not available for .xlsx import")
      return(list(
        ok = FALSE,
        format = "XLSX",
        message = "当前环境缺少 readxl 包，暂时无法读取 .xlsx 文件。"
      ))
    }

    sheets <- tryCatch(readxl::excel_sheets(path), error = function(e) e)
    if (inherits(sheets, "error") || length(sheets) == 0L) {
      msg <- if (inherits(sheets, "error")) conditionMessage(sheets) else "no sheets found"
      log_error(.MODULE, "XLSX sheet discovery failed: %s", msg)
      return(list(
        ok = FALSE,
        format = "XLSX",
        message = "无法识别 Excel 工作表，请检查文件内容。"
      ))
    }

    sheet_name <- sheets[[1]]
    result <- tryCatch(
      suppressWarnings(readxl::read_excel(path, sheet = 1, .name_repair = "minimal")),
      error = function(e) e
    )

    if (inherits(result, "error")) {
      log_error(.MODULE, "XLSX read failed on first sheet '%s': %s", sheet_name, conditionMessage(result))
      return(list(
        ok = FALSE,
        format = "XLSX",
        message = "Excel 读取失败，请检查文件格式。"
      ))
    }

    list(
      ok = TRUE,
      data = .as_plain_data_frame(result),
      format = "XLSX",
      sheet = sheet_name,
      log_detail = sprintf("sheet='%s'", sheet_name),
      success_detail = sprintf("已读取首个工作表：%s。", sheet_name)
    )
  }

  .uploaded_extension <- function(file_info) {
    name_ext <- tolower(tools::file_ext(file_info$name %||% ""))
    path_ext <- tolower(tools::file_ext(file_info$datapath %||% ""))
    if (nzchar(name_ext)) name_ext else path_ext
  }

  .read_uploaded_table <- function(file_info) {
    ext <- .uploaded_extension(file_info)
    path <- file_info$datapath %||% ""

    if (!nzchar(path)) {
      return(list(ok = FALSE, message = "未找到上传文件，请重试。"))
    }

    switch(
      ext,
      csv = .read_delimited_with_fallback(path, sep = ",", format_label = "CSV"),
      tsv = .read_delimited_with_fallback(path, sep = "\t", format_label = "TSV"),
      xlsx = .read_xlsx_first_sheet(path),
      {
        log_warn(.MODULE, "unsupported upload extension: '%s'", ext %||% "")
        list(ok = FALSE, message = "当前仅支持 .csv、.tsv 或 .xlsx 文件。")
      }
    )
  }

  .detect_delimiter <- function(text) {
    first_line <- trimws(strsplit(text, "\n", fixed = TRUE)[[1]][1] %||% "")

    if (grepl("\t", first_line, fixed = TRUE)) {
      list(sep = "\t", label = "tab")
    } else if (grepl(";", first_line, fixed = TRUE)) {
      list(sep = ";", label = "semicolon")
    } else {
      list(sep = ",", label = "comma")
    }
  }

  .parse_pasted_data <- function(text, sep, has_header) {
    utils::read.table(
      text = text,
      sep = sep,
      header = has_header,
      stringsAsFactors = FALSE,
      fill = TRUE,
      quote = "\"",
      check.names = FALSE,
      comment.char = "",
      encoding = "UTF-8"
    )
  }

  .capture_unsaved_table_edits <- function(input, rv) {
    live_data <- .live_table_data(input)
    if (is.null(live_data) || .same_data_frame(live_data, rv$current_data)) {
      return(FALSE)
    }

    rv$current_data <- live_data
    rv$current_data_source <- "user_edit"
    log_info(
      .MODULE,
      "captured unsaved table edits: %d rows x %d cols",
      nrow(live_data),
      ncol(live_data)
    )

    TRUE
  }

  .source_meta <- function(source) {
    switch(
      source %||% "sample",
      sample = list(label = "示例数据", class = "source-sample"),
      upload = list(label = "文件导入", class = "source-upload"),
      paste = list(label = "粘贴导入", class = "source-paste"),
      user_edit = list(label = "表格编辑", class = "source-user-edit"),
      list(label = "未知来源", class = "source-unknown")
    )
  }

  .data_dims_text <- function(df) {
    df <- .as_plain_data_frame(df)
    if (is.null(df) || !is.data.frame(df)) return("暂无数据")
    sprintf("%d 行 × %d 列", nrow(df), ncol(df))
  }

  .import_success_message <- function(df, source, renamed = FALSE, detail = NULL) {
    base <- sprintf("已从%s导入 %d 行 × %d 列。", source, nrow(df), ncol(df))
    extras <- c(if (isTRUE(renamed)) "已按当前图表映射列名。" else NULL, detail %||% NULL)

    if (length(extras) == 0L) {
      return(base)
    }

    paste(base, paste(extras, collapse = " "))
  }

  init_mod_data <<- function(input, output, session, rv) {

    output$data_source_ui <- renderUI({
      meta <- .source_meta(rv$current_data_source %||% "sample")

      tags$div(
        class = "data-source-chip",
        tags$span(class = paste("data-source-pill", meta$class), meta$label),
        tags$span(class = "data-source-dims", .data_dims_text(rv$current_data))
      )
    })

    output$data_requirements_ui <- renderUI({
      chart_id <- input$chart_type_select %||% ""
      specs <- .column_specs_for_chart(chart_id)

      if (length(specs) == 0L) {
        return(tags$span(class = "text-muted", "请先选择图表以查看字段要求。"))
      }

      tags$div(
        class = "data-requirements-list",
        lapply(specs, function(spec) {
          flags <- c(
            if (isTRUE(spec$optional)) "可选" else "必需",
            if (isTRUE(spec$numeric)) "数值" else NULL
          )

          tags$span(
            class = "data-requirement-badge",
            tags$span(class = "data-requirement-name", spec$name),
            if (length(flags) > 0L) {
              tags$span(class = "data-requirement-flags", paste(flags, collapse = " / "))
            }
          )
        })
      )
    })

    observeEvent(input$chart_type_select, {
      req(input$chart_type_select)
      chart_id <- input$chart_type_select

      .capture_unsaved_table_edits(input, rv)
      current_source <- rv$current_data_source %||% "sample"

      if (identical(current_source, "sample")) {
        log_debug(.MODULE, "chart switched to '%s', loading sample data", chart_id)
        rv$current_data <- .sample_data_for_chart(chart_id)
        rv$current_data_source <- "sample"
        return()
      }

      log_info(
        .MODULE,
        "chart switched to '%s'; preserving current data source='%s'",
        chart_id,
        current_source
      )
      showNotification(
        "已保留当前数据；如需切换为该图表示例数据，请点击“加载示例数据”。",
        type = "message",
        duration = 3
      )
    }, ignoreNULL = TRUE)

    observeEvent(input$load_sample_btn, {
      req(input$chart_type_select)
      chart_id <- input$chart_type_select

      log_info(.MODULE, "load_sample_btn: chart='%s'", chart_id)
      rv$current_data <- .sample_data_for_chart(chart_id)
      rv$current_data_source <- "sample"
    })

    observeEvent(input$upload_file, {
      req(input$upload_file, input$chart_type_select)
      chart_id <- input$chart_type_select
      file_name <- input$upload_file$name %||% input$upload_file$datapath %||% "unknown"

      log_info(.MODULE, "upload_file: chart='%s' file='%s'", chart_id, file_name)

      read_result <- safe_run(.MODULE, .read_uploaded_table(input$upload_file))
      if (is.null(read_result) || !isTRUE(read_result$ok)) {
        message <- read_result$message %||% "文件导入失败，请检查格式后重试。"
        showNotification(message, type = "error", duration = 5)
        shinyjs::reset("upload_file")
        return()
      }

      validated <- .validate_import_df(read_result$data, chart_id)
      if (!isTRUE(validated$ok)) {
        log_warn(.MODULE, "upload validation failed: %s", validated$message)
        showNotification(validated$message, type = "warning", duration = 5)
        shinyjs::reset("upload_file")
        return()
      }

      rv$current_data <- validated$data
      rv$current_data_source <- "upload"

      log_info(
        .MODULE,
        "upload OK: chart='%s' format='%s' rows=%d cols=%d %s",
        chart_id,
        read_result$format %||% "unknown",
        nrow(validated$data),
        ncol(validated$data),
        read_result$log_detail %||% ""
      )
      if (!is.null(validated$mapping_note) && nzchar(validated$mapping_note)) {
        log_info(.MODULE, "upload column mapping: %s", validated$mapping_note)
      }

      showNotification(
        .import_success_message(
          validated$data,
          read_result$format %||% "文件",
          renamed = validated$renamed,
          detail = read_result$success_detail %||% NULL
        ),
        type = "message",
        duration = 4
      )
      shinyjs::reset("upload_file")
    })

    observeEvent(input$paste_import_btn, {
      req(input$chart_type_select)
      chart_id <- input$chart_type_select
      txt <- trimws(input$paste_data_area %||% "")

      if (!nzchar(txt)) {
        log_warn(.MODULE, "paste import requested with empty text area")
        showNotification("粘贴区为空，请先粘贴数据。", type = "warning", duration = 3)
        return()
      }

      delimiter <- .detect_delimiter(txt)
      log_info(
        .MODULE,
        "paste import requested: chart='%s' delimiter='%s' header=%s",
        chart_id,
        delimiter$label,
        isTRUE(input$paste_has_header)
      )

      parsed <- safe_run(
        .MODULE,
        .parse_pasted_data(txt, delimiter$sep, isTRUE(input$paste_has_header))
      )

      if (is.null(parsed)) {
        showNotification("解析失败，请检查粘贴内容格式。", type = "error", duration = 5)
        return()
      }

      validated <- .validate_import_df(parsed, chart_id)
      if (!isTRUE(validated$ok)) {
        log_warn(.MODULE, "paste validation failed: %s", validated$message)
        showNotification(validated$message, type = "warning", duration = 5)
        return()
      }

      rv$current_data <- validated$data
      rv$current_data_source <- "paste"
      updateTextAreaInput(session, "paste_data_area", value = "")

      log_info(
        .MODULE,
        "paste import OK: chart='%s' rows=%d cols=%d",
        chart_id,
        nrow(validated$data),
        ncol(validated$data)
      )
      if (!is.null(validated$mapping_note) && nzchar(validated$mapping_note)) {
        log_info(.MODULE, "paste column mapping: %s", validated$mapping_note)
      }

      showNotification(
        .import_success_message(validated$data, "粘贴内容", renamed = validated$renamed),
        type = "message",
        duration = 4
      )
    })

    output$data_table <- renderRHandsontable({
      req(rv$current_data)
      rhandsontable(
        rv$current_data,
        rowHeaders = TRUE,
        stretchH = "all",
        overflow = "visible",
        colHeaders = names(rv$current_data)
      ) |>
        hot_context_menu(allowRowEdit = TRUE, allowColEdit = FALSE)
    })

    invisible(NULL)
  }
})
