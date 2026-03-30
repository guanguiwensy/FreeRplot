# =============================================================================
# File   : R/modules/mod_code.R
# Purpose: Code editor server module for the "R Code" tab.
#          Owns code-template population, editor execution, run status,
#          and standalone R code export text used by copy-to-clipboard.
#
# Depends: R/core/code_engine.R (get_editor_code)
#          R/core/module_shared.R (shared_active_data_reactive,
#                                   shared_build_plot_options,
#                                   shared_prepare_code_context)
#          R/utils/logger.R     (log_debug, log_info)
#
# Exported functions:
#   init_mod_code(input, output, session, rv)
# =============================================================================

local({
  .MODULE <- "mod_code"

  init_mod_code <<- function(input, output, session, rv) {

    active_data <- shared_active_data_reactive(input, rv)

    build_plot_options <- reactive({
      shared_build_plot_options(
        input = input,
        data = active_data(),
        chart_id = input$chart_type_select,
        mapping = shared_collect_column_mapping(input)
      )
    })

    data_to_r_code <- function(data, max_rows = 200L) {
      if (is.null(data) || nrow(data) == 0) {
        return("data <- data.frame()")
      }

      trimmed <- data
      note <- NULL

      if (nrow(data) > max_rows) {
        trimmed <- utils::head(data, max_rows)
        note <- paste0("# NOTE: showing first ", max_rows, " rows out of ", nrow(data), " total rows")
      }

      dput_txt <- paste(capture.output(dput(trimmed)), collapse = "\n")
      block <- paste0("data <- ", dput_txt)

      if (!is.null(note)) {
        paste(note, block, sep = "\n")
      } else {
        block
      }
    }

    current_export_code <- reactive({
      req(input$chart_type_select)

      chart <- CHARTS[[input$chart_type_select]]
      data <- active_data()
      opts <- build_plot_options()

      settings_block <- paste0(
        "# ---- Current Settings ----\n",
        "title          <- ", dQuote(opts$title %||% ""), "\n",
        "x_label        <- ", dQuote(opts$x_label %||% ""), "\n",
        "y_label        <- ", dQuote(opts$y_label %||% ""), "\n",
        "palette        <- ", dQuote(opts$palette %||% ""), "\n",
        "theme          <- ", dQuote(opts$theme %||% ""), "\n",
        "plot_width_in  <- ", opts$plot_width_in %||% 10, "\n",
        "plot_height_in <- ", opts$plot_height_in %||% 6, "\n",
        "plot_dpi       <- ", opts$plot_dpi %||% 150, "\n",
        "x_range_mode   <- ", dQuote(opts$x_range_mode %||% "auto"), "\n",
        "x_min          <- ", ifelse(is.na(opts$x_min), "NA", as.character(opts$x_min)), "\n",
        "x_max          <- ", ifelse(is.na(opts$x_max), "NA", as.character(opts$x_max)), "\n",
        "y_range_mode   <- ", dQuote(opts$y_range_mode %||% "auto"), "\n",
        "y_min          <- ", ifelse(is.na(opts$y_min), "NA", as.character(opts$y_min)), "\n",
        "y_max          <- ", ifelse(is.na(opts$y_max), "NA", as.character(opts$y_max))
      )

      template_code <- "# No chart template available."
      if (is.function(chart$code_template)) {
        template_code <- tryCatch({
          argn <- length(formals(chart$code_template))
          if (argn >= 2) {
            chart$code_template(opts, data)
          } else {
            chart$code_template(opts)
          }
        }, error = function(e) {
          paste("# Code generation failed:", e$message)
        })
      }

      paste(
        "# ---- Current Data ----",
        data_to_r_code(data),
        settings_block,
        "# ---- Chart Template ----",
        template_code,
        sep = "\n\n"
      )
    })

    observe({
      shinyjs::toggleState("copy_code_btn", condition = nzchar(current_export_code()))
    })

    observeEvent(input$chart_type_select, {
      req(input$chart_type_select)
      data <- isolate(rv$current_data) %||% data.frame()
      data_file <- isolate(rv$current_data_file %||% NULL)
      new_code <- get_editor_code(input$chart_type_select, data, data_file = data_file)
      shinyAce::updateAceEditor(session, "plot_code", value = new_code)
      rv$last_run_error <- NULL
      log_debug(.MODULE, "editor populated for chart '%s'", input$chart_type_select)
    }, ignoreInit = FALSE)

    .run_editor_code <- function() {
      code <- isolate(input$plot_code %||% "")
      raw_data <- active_data()
      chart_id <- isolate(input$chart_type_select %||% "")
      ctx <- shared_prepare_code_context(
        raw_data,
        chart_id = chart_id,
        mapping = shared_collect_column_mapping(input)
      )
      data <- ctx$data

      if (!nzchar(trimws(code))) {
        showNotification("编辑器为空，请先输入代码。", type = "warning")
        return()
      }
      # Defensive fix pass: normalize common unsafe snippets before eval.
      repaired_code <- tryCatch(.repair_generated_code(code), error = function(e) code)
      if (!identical(repaired_code, code)) {
        code <- repaired_code
        shinyAce::updateAceEditor(session, "plot_code", value = code)
      }
      if (is.null(data) || nrow(data) == 0) {
        showNotification("数据为空，请先载入数据。", type = "warning")
        return()
      }

      log_debug(.MODULE, "run_code: %d chars, chart=%s, rows=%d",
                nchar(code), isolate(input$chart_type_select), nrow(data))

      env <- new.env(parent = globalenv())
      env$data <- data
      env$df <- ctx$df
      env$col_names <- ctx$col_names
      env$num_cols <- ctx$num_cols
      env$extra_cols <- ctx$extra_cols
      env$x_col <- ctx$x_col
      env$y_col <- ctx$y_col
      env$size_col <- ctx$size_col
      env$group_col <- ctx$group_col
      env$label_col <- ctx$label_col

      result <- tryCatch(
        withCallingHandlers(
          eval(parse(text = code), envir = env),
          warning = function(w) invokeRestart("muffleWarning")
        ),
        error = function(e) {
          msg <- conditionMessage(e)
          log_debug(.MODULE, "run_code error: %s", msg)
          rv$last_run_error <- msg
          showNotification(paste0("执行错误：", msg), type = "error", duration = 8)
          NULL
        }
      )

      if (is.null(result)) return()

      p <- if (inherits(result, "ggplot")) {
        result
      } else {
        tryCatch(grDevices::recordPlot(), error = function(e) NULL) %||%
          tryCatch(ggplot2::last_plot(), error = function(e) NULL)
      }

      if (is.null(p)) {
        showNotification(
          "代码执行完毕，但未检测到图形对象。请确保代码返回 ggplot 或调用绘图函数。",
          type = "warning",
          duration = 6
        )
        return()
      }

      rv$current_plot <- p
      rv$last_run_error <- NULL
      rv$current_plot_code <- code
      log_info(.MODULE, "run_code OK: rows=%d", nrow(data))
    }

    observeEvent(input$generate_btn, { .run_editor_code() })
    observeEvent(input$run_code_btn, { .run_editor_code() })

    output$run_status_ui <- renderUI({
      err <- rv$last_run_error
      if (!is.null(err)) {
        tags$span(
          class = "badge bg-danger ms-1",
          style = "font-size:0.75rem; max-width:280px; white-space:normal;",
          icon("circle-xmark"), " ", substr(err, 1, 80)
        )
      } else if (!is.null(rv$current_plot)) {
        tags$span(
          class = "badge bg-success ms-1",
          style = "font-size:0.75rem;",
          icon("circle-check"), " OK"
        )
      } else {
        NULL
      }
    })

    output$r_code_output <- renderText({
      current_export_code()
    })

    output$r_code_copy_store <- renderUI({
      tags$textarea(
        id = "r_code_copy_store",
        class = "code-copy-store",
        readonly = "readonly",
        `aria-hidden` = "true",
        current_export_code()
      )
    })

    output$r_code_view <- renderUI({
      build_r_code_view_ui(current_export_code())
    })

    invisible(NULL)
  }
})
