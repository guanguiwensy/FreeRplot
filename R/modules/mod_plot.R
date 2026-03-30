# =============================================================================
# File   : R/modules/mod_plot.R
# Purpose: Plot server module — renders the current plot object to main canvas,
#          handles base plot downloads, and builds the chart gallery tab.
#
# Depends: R/core/module_shared.R (shared_active_data_reactive,
#                                  shared_build_plot_options, shared_as_num_or)
#          R/ui_helpers.R         (CHART_MENU_GROUPS)
#          R/utils/logger.R       (log_info)
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
#   output$download_plot   downloadHandler — PNG
#   output$download_plot_pdf downloadHandler — PDF
#   output$download_csv    downloadHandler — current chart sample-data CSV
#   output$chart_gallery_ui renderUI — pill-tabset of chart buttons
# =============================================================================

MODULE <- "mod_plot"

init_mod_plot <- function(input, output, session, rv) {

  active_data <- shared_active_data_reactive(input, rv)

  build_plot_options <- reactive({
    shared_build_plot_options(
      input = input,
      data = active_data(),
      chart_id = input$chart_type_select,
      mapping = shared_collect_column_mapping(input)
    )
  })

  output$main_plot <- renderPlot({
    input$pane_resize_seq

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
  }, bg = "white")

  output$download_plot <- downloadHandler(
    filename = function() paste0(input$chart_type_select, "_", Sys.Date(), ".png"),
    content = function(file) {
      req(rv$current_plot)
      p <- rv$current_plot
      opts <- build_plot_options()
      w <- shared_as_num_or(opts$plot_width_in, 10)
      h <- shared_as_num_or(opts$plot_height_in, 6)
      dpi <- shared_as_num_or(opts$plot_dpi, 150)

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
      w <- shared_as_num_or(opts$plot_width_in, 10)
      h <- shared_as_num_or(opts$plot_height_in, 6)

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
    filename = function() paste0(input$chart_type_select, "_sample_data.csv"),
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
      log_info(MODULE, "gallery selected chart='%s'", id)
      updateSelectInput(session, "chart_type_select", selected = id)
    }, ignoreInit = TRUE)
  })

  invisible(NULL)
}
