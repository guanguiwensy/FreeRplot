# =============================================================================
# File   : R/modules/mod_plot.R
# Purpose: Plot server module — reacts to generate_btn, renders the ggplot to
#          the main canvas, exports R code, handles PNG/PDF downloads, and
#          builds the chart gallery tab.
#
# Depends: R/plot_core.R    (generate_plot, COLOR_PALETTES, CHART_THEMES)
#          R/ui_helpers.R   (collect_options, CHART_MENU_GROUPS)
#          R/utils/logger.R (log_debug, log_error, safe_run)
#
# Exported functions:
#   init_mod_plot(input, output, session, rv)
#     Registers all observers and outputs for the plot panel.
#     Parameters:
#       input   [Shiny input]
#       output  [Shiny output]
#       session [Shiny session]
#       rv      [reactiveValues]  uses: rv$current_data, rv$current_plot
#
# Key reactives / outputs:
#   active_data()          reactive — returns live table data (edited or rv$current_data)
#   build_plot_options()   reactive — collects all input widgets into an options list
#   output$main_plot       renderPlot — renders rv$current_plot or placeholder
#   output$r_code_output   renderText — reproducible R code block
#   output$download_plot   downloadHandler — PNG
#   output$download_plot_pdf downloadHandler — PDF
#   output$download_csv    downloadHandler — sample data CSV
#   output$chart_gallery_ui renderUI — pill-tabset of chart buttons
# =============================================================================

MODULE <- "mod_plot"

init_mod_plot <- function(input, output, session, rv) {

  as_num_or <- function(x, default = NA_real_) {
    v <- suppressWarnings(as.numeric(x))
    if (length(v) == 0 || is.na(v[1])) default else v[1]
  }

  is_probably_numeric <- function(x) {
    if (is.null(x)) return(FALSE)
    if (is.numeric(x)) return(TRUE)
    sx <- suppressWarnings(as.numeric(x))
    !all(is.na(sx))
  }

  active_data <- reactive({
    tryCatch({
      tbl <- hot_to_r(input$data_table)
      expected <- names(rv$current_data)
      if (is.null(tbl) || !all(expected %in% names(tbl))) rv$current_data else tbl
    }, error = function(e) rv$current_data)
  })

  build_plot_options <- reactive({
    data <- active_data()
    x_col <- if (ncol(data) >= 1) names(data)[1] else NULL
    y_col <- if (ncol(data) >= 2) names(data)[2] else NULL

    width_in <- as_num_or(input$plot_width_in, 10)
    height_in <- as_num_or(input$plot_height_in, 6)
    dpi <- as_num_or(input$plot_dpi, 150)

    width_in <- min(max(width_in, 2), 40)
    height_in <- min(max(height_in, 2), 40)
    dpi <- min(max(dpi, 72), 600)

    x_min <- as_num_or(input$x_min, NA_real_)
    x_max <- as_num_or(input$x_max, NA_real_)
    y_min <- as_num_or(input$y_min, NA_real_)
    y_max <- as_num_or(input$y_max, NA_real_)

    c(
      list(
        title = input$plot_title,
        x_label = input$x_label,
        y_label = input$y_label,
        palette = input$color_palette,
        theme = input$chart_theme,
        plot_width_in = width_in,
        plot_height_in = height_in,
        plot_dpi = dpi,
        x_range_mode = input$x_range_mode %||% "auto",
        x_min = x_min,
        x_max = x_max,
        y_range_mode = input$y_range_mode %||% "auto",
        y_min = y_min,
        y_max = y_max,
        x_is_numeric = if (!is.null(x_col)) is_probably_numeric(data[[x_col]]) else FALSE,
        y_is_numeric = if (!is.null(y_col)) is_probably_numeric(data[[y_col]]) else FALSE
      ),
      collect_options(input)
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
    if (!is.null(note)) {
      paste(note, paste0("data <- ", dput_txt), sep = "\n")
    } else {
      paste0("data <- ", dput_txt)
    }
  }

  observeEvent(input$generate_btn, {
    req(input$chart_type_select)
    log_debug(MODULE, "generate_btn: chart=%s", input$chart_type_select)

    data <- active_data()
    if (is.null(data) || nrow(data) == 0) {
      showNotification("Data is empty. Please load or input data first.", type = "warning")
      return()
    }

    options <- build_plot_options()

    p <- safe_run(MODULE, generate_plot(input$chart_type_select, data, options))
    if (is.null(p)) {
      showNotification(
        paste0("Plot failed for '", input$chart_type_select, "'. Check RPLOT_LOG=DEBUG for details."),
        type = "error", duration = 8
      )
      return()
    }

    log_info(MODULE, "plot generated: chart=%s rows=%d", input$chart_type_select, nrow(data))
    rv$current_plot <- p
  })

  output$main_plot <- renderPlot({
    p <- if (is.null(rv$current_plot)) {
      ggplot2::ggplot() +
        ggplot2::annotate("text", x = 0.5, y = 0.5,
                          label = "Click [Generate Plot] to render.",
                          size = 5.2, color = "#adb5bd") +
        ggplot2::theme_void()
    } else {
      rv$current_plot
    }

    tryCatch({
      if (inherits(p, "circos_plot")) {
        p$draw()
      } else {
        print(p)
      }
    }, error = function(e) {
      print(
        ggplot2::ggplot() +
          ggplot2::annotate("text", x = 0.5, y = 0.5,
                            label = paste("Render failed:", e$message),
                            size = 4, color = "#dc3545") +
          ggplot2::theme_void()
      )
    })
  }, bg = "white", height = function() {
    ct <- isolate(input$chart_type_select)
    if (is.null(ct)) return(340)
    if (ct == "circos") return(500)
    if (ct == "dna_many") {
      n <- max(1, nrow(isolate(rv$current_data)))
      return(max(340, 80 + n * 60))
    }
    if (ct %in% c("dna_single", "dna_methylation")) return(460)
    340
  })

  output$r_code_output <- renderText({
    req(input$chart_type_select)

    chart <- CHARTS[[input$chart_type_select]]
    data <- active_data()
    opts <- build_plot_options()

    settings_block <- paste0(
      "# ---- Current Settings ----\n",
      "plot_width_in  <- ", opts$plot_width_in %||% 10, "\n",
      "plot_height_in <- ", opts$plot_height_in %||% 6, "\n",
      "plot_dpi       <- ", opts$plot_dpi %||% 150, "\n",
      "x_range_mode   <- \"", opts$x_range_mode %||% "auto", "\"\n",
      "x_min          <- ", ifelse(is.na(opts$x_min), "NA", as.character(opts$x_min)), "\n",
      "x_max          <- ", ifelse(is.na(opts$x_max), "NA", as.character(opts$x_max)), "\n",
      "y_range_mode   <- \"", opts$y_range_mode %||% "auto", "\"\n",
      "y_min          <- ", ifelse(is.na(opts$y_min), "NA", as.character(opts$y_min)), "\n",
      "y_max          <- ", ifelse(is.na(opts$y_max), "NA", as.character(opts$y_max)), "\n"
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
      }, error = function(e) paste("# Code generation failed:", e$message))
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

  output$download_plot <- downloadHandler(
    filename = function() paste0(input$chart_type_select, "_", Sys.Date(), ".png"),
    content = function(file) {
      req(rv$current_plot)
      p <- rv$current_plot
      opts <- build_plot_options()
      w <- as_num_or(opts$plot_width_in, 10)
      h <- as_num_or(opts$plot_height_in, 6)
      dpi <- as_num_or(opts$plot_dpi, 150)

      if (inherits(p, "circos_plot")) {
        grDevices::png(file, width = w, height = h, units = "in", res = dpi)
        p$draw()
        grDevices::dev.off()
      } else {
        ggplot2::ggsave(file, plot = p, width = w, height = h, dpi = dpi, bg = "white")
      }
    }
  )

  output$download_plot_pdf <- downloadHandler(
    filename = function() paste0(input$chart_type_select, "_", Sys.Date(), ".pdf"),
    content = function(file) {
      req(rv$current_plot)
      p <- rv$current_plot
      opts <- build_plot_options()
      w <- as_num_or(opts$plot_width_in, 10)
      h <- as_num_or(opts$plot_height_in, 6)

      if (inherits(p, "circos_plot")) {
        grDevices::pdf(file, width = w, height = h)
        p$draw()
        grDevices::dev.off()
      } else {
        ggplot2::ggsave(file, plot = p, width = w, height = h, device = "pdf", bg = "white")
      }
    }
  )

  output$download_csv <- downloadHandler(
    filename = function() paste0(input$chart_type_select, "_template.csv"),
    content = function(file) {
      write.csv(CHARTS[[input$chart_type_select]]$sample_data, file, row.names = FALSE)
    }
  )

  output$chart_gallery_ui <- renderUI({
    tabs <- lapply(names(CHART_MENU_GROUPS), function(group_label) {
      ids <- CHART_MENU_GROUPS[[group_label]]
      valid_ids <- ids[ids %in% names(CHARTS)]
      if (length(valid_ids) == 0) return(NULL)

      items <- lapply(valid_ids, function(id) {
        c <- CHARTS[[id]]
        actionButton(
          inputId = paste0("gallery_", id),
          label = div(
            div(style = "font-weight:600; font-size:0.9rem;", c$name),
            div(style = "font-size:0.75rem; color:#6c757d;", c$name_en)
          ),
          class = paste0(
            "btn btn-outline-secondary btn-sm m-1",
            if (identical(input$chart_type_select, id)) " active" else ""
          ),
          style = "width:130px; text-align:left;"
        )
      })

      tabPanel(group_label, div(style = "display:flex; flex-wrap:wrap; padding-top:8px;", items))
    })

    do.call(tabsetPanel, c(list(type = "pills"), Filter(Negate(is.null), tabs)))
  })

  lapply(CHART_IDS, function(id) {
    observeEvent(input[[paste0("gallery_", id)]], {
      updateSelectInput(session, "chart_type_select", selected = id)
      rv$current_data <- CHARTS[[id]]$sample_data
    }, ignoreInit = TRUE)
  })

  invisible(NULL)
}