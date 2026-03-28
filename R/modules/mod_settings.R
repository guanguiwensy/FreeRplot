# =============================================================================
# File   : R/modules/mod_settings.R
# Purpose: Settings server module for scene templates, user recipes, dynamic
#          chart-specific controls, axis-range availability, and the unified
#          base-palette plus local color-override workflow.
#
# Depends: R/ui_helpers.R       (build_show_when_map, apply_show_when,
#                                 build_controls, collect_options)
#          R/preset_manager.R   (list_recipe_records, load_recipe, save_recipe,
#                                 delete_recipe, restore_recipe_inputs)
#          R/config_manager.R   (LLM_PROVIDERS, save_api_config, get_api_url)
#          R/plot_core.R        (COLOR_PALETTES, CHART_THEMES,
#                                 candidate_palette_columns,
#                                 infer_palette_target,
#                                 palette_values_for_levels,
#                                 palette_override_input_id)
#          R/bar_scene_presets.R / R/scatter_scene_presets.R
#          R/utils/logger.R     (log_info, log_warn, safe_run)
#
# Exported functions:
#   init_mod_settings(input, output, session, rv)
# =============================================================================

MODULE <- "mod_settings"

init_mod_settings <- function(input, output, session, rv) {

  is_probably_numeric <- function(x) {
    if (is.null(x)) return(FALSE)
    if (is.numeric(x)) return(TRUE)
    sx <- suppressWarnings(as.numeric(x))
    !all(is.na(sx))
  }

  current_chart <- reactive({
    CHARTS[[input$chart_type_select]]
  })

  current_defs <- reactive({
    defs <- current_chart()$options_def %||% list()
    Filter(function(d) !identical(d$id, "color_palette"), defs)
  })

  build_recipe_choices <- function() {
    records <- list_recipe_records(include_legacy = TRUE)
    if (length(records) == 0) return(c("\u6682\u65e0\u914d\u65b9" = ""))

    labels <- vapply(records, function(rec) {
      chart_label <- CHARTS[[rec$chart_id]]$name %||% rec$chart_id
      suffix <- if (identical(rec$source %||% "", "legacy")) "\uff08\u65e7\u7248\uff09" else ""
      paste0(rec$name, " [", chart_label, "]", suffix)
    }, character(1))

    setNames(vapply(records, `[[`, character(1), "name"), labels)
  }

  refresh_recipe_select <- function(selected = "") {
    choices <- build_recipe_choices()
    updateSelectInput(session, "recipe_select", choices = choices, selected = selected)
  }

  toggle_recipe_buttons <- function() {
    selected <- input$recipe_select %||% ""
    rec <- if (nzchar(selected)) load_recipe(selected, include_legacy = TRUE) else NULL

    shinyjs::toggleState("recipe_load_btn", condition = !is.null(rec))
    shinyjs::toggleState(
      "recipe_delete_btn",
      condition = !is.null(rec) && !identical(rec$source %||% "", "legacy")
    )
  }

  current_axis_state <- reactive({
    data <- rv$current_data
    list(
      x_numeric = if (!is.null(data) && ncol(data) >= 1) is_probably_numeric(data[[1]]) else FALSE,
      y_numeric = if (!is.null(data) && ncol(data) >= 2) is_probably_numeric(data[[2]]) else FALSE
    )
  })

  current_color_columns <- reactive({
    candidate_palette_columns(rv$current_data)
  })

  current_color_target <- reactive({
    if (input$chart_type_select %in% c("bar_value", "bar_horizontal", "bar_count", "bar_diverging")) {
      return(NULL)
    }

    choices <- current_color_columns()
    if (length(choices) == 0) return(NULL)

    requested <- input$palette_target_column %||% ""
    inferred <- infer_palette_target(input$chart_type_select, rv$current_data)

    if (nzchar(requested) && requested %in% choices) return(requested)
    if (!is.null(inferred) && inferred %in% choices) return(inferred)
    choices[[1]]
  })

  current_color_levels <- reactive({
    target <- current_color_target()
    if (is.null(target) || !(target %in% names(rv$current_data %||% list()))) return(character(0))
    unique(as.character(rv$current_data[[target]]))
  })

  collect_color_overrides <- function(base_palette = input$color_palette %||% names(COLOR_PALETTES)[1],
                                      target = current_color_target()) {
    levels <- current_color_levels()
    if (is.null(target) || length(levels) == 0) return(list())

    defaults <- palette_values_for_levels(levels, base_palette, list())
    overrides <- list()

    for (level in levels) {
      iid <- palette_override_input_id(target, level)
      val <- input[[iid]]
      if (is.null(val)) next
      val <- as.character(val)[1]
      if (!nzchar(val)) next
      if (!identical(toupper(val), toupper(defaults[[level]]))) {
        overrides[[level]] <- val
      }
    }

    overrides
  }

  current_color_settings <- reactive({
    list(
      base_palette = input$color_palette %||% names(COLOR_PALETTES)[1],
      target_column = current_color_target(),
      overrides = collect_color_overrides()
    )
  })

  restore_color_settings_inputs <- function(color_settings) {
    color_settings <- color_settings %||% list()
    target <- color_settings$target_column %||% current_color_target()
    if (!is.null(target) && target %in% current_color_columns()) {
      updateSelectInput(session, "palette_target_column", selected = target)
    }

    shinyjs::delay(150, {
      base_palette <- input$color_palette %||% color_settings$base_palette %||% names(COLOR_PALETTES)[1]
      active_target <- target %||% current_color_target()
      if (is.null(active_target)) return()

      levels <- unique(as.character(rv$current_data[[active_target]]))
      defaults <- palette_values_for_levels(levels, base_palette, list())
      overrides <- color_settings$overrides %||% list()

      for (level in levels) {
        iid <- palette_override_input_id(active_target, level)
        val <- overrides[[level]] %||% defaults[[level]]
        colourpicker::updateColourInput(session, iid, value = val)
      }
    })
  }

  build_current_recipe <- function(name) {
    chart_id <- isolate(input$chart_type_select)
    list(
      version = 1,
      name = name,
      chart_id = chart_id,
      global_settings = list(
        plot_title = isolate(input$plot_title) %||% "",
        x_label = isolate(input$x_label) %||% "",
        y_label = isolate(input$y_label) %||% "",
        color_palette = isolate(input$color_palette) %||% names(COLOR_PALETTES)[1],
        chart_theme = isolate(input$chart_theme) %||% names(CHART_THEMES)[1],
        plot_width_in = isolate(input$plot_width_in) %||% 10,
        plot_height_in = isolate(input$plot_height_in) %||% 6,
        plot_dpi = isolate(input$plot_dpi) %||% 150,
        x_range_mode = isolate(input$x_range_mode) %||% "auto",
        x_min = isolate(input$x_min),
        x_max = isolate(input$x_max),
        y_range_mode = isolate(input$y_range_mode) %||% "auto",
        y_min = isolate(input$y_min),
        y_max = isolate(input$y_max)
      ),
      chart_options = collect_options(input, current_defs()),
      color_settings = current_color_settings()
    )
  }

  open_save_recipe_modal <- function(default_name) {
    showModal(modalDialog(
      title = "\u4fdd\u5b58\u4e3a\u6211\u7684\u914d\u65b9",
      size = "s",
      easyClose = TRUE,
      footer = tagList(
        modalButton("\u53d6\u6d88"),
        actionButton("recipe_confirm_save_btn", "\u4fdd\u5b58", class = "btn btn-success btn-sm")
      ),
      textInput(
        "recipe_name_input",
        "\u914d\u65b9\u540d\u79f0",
        value = default_name,
        width = "100%",
        placeholder = "\u8f93\u5165\u914d\u65b9\u540d\u79f0"
      ),
      tags$small(
        class = "text-muted",
        "\u914d\u65b9\u4f1a\u8bb0\u5f55\u5f53\u524d\u56fe\u8868\u7c7b\u578b\u3001\u57fa\u7840\u6837\u5f0f\u3001\u989c\u8272\u8bbe\u7f6e\u548c\u4e13\u5c5e\u53c2\u6570\u3002"
      )
    ))
  }

  show_when_map <- build_show_when_map(CHARTS)
  all_sw_triggers <- unique(unlist(lapply(show_when_map, names)))

  observeEvent(input$chart_type_select, {
    cid <- input$chart_type_select
    shinyjs::delay(200, {
      apply_show_when(show_when_map, cid, input)
    })
    refresh_recipe_select()
  }, ignoreInit = FALSE)

  lapply(all_sw_triggers, function(trigger_id) {
    observeEvent(input[[trigger_id]], {
      apply_show_when(show_when_map, input$chart_type_select, input)
    }, ignoreNULL = FALSE, ignoreInit = TRUE)
  })

  observe({
    axis_state <- current_axis_state()

    if (!isTRUE(axis_state$x_numeric)) {
      if (!identical(input$x_range_mode %||% "auto", "auto")) {
        updateSelectInput(session, "x_range_mode", selected = "auto")
      }
      shinyjs::disable("x_range_mode")
    } else {
      shinyjs::enable("x_range_mode")
    }

    if (!isTRUE(axis_state$y_numeric)) {
      if (!identical(input$y_range_mode %||% "auto", "auto")) {
        updateSelectInput(session, "y_range_mode", selected = "auto")
      }
      shinyjs::disable("y_range_mode")
    } else {
      shinyjs::enable("y_range_mode")
    }
  })

  observe({
    toggle_recipe_buttons()
  })

  observeEvent(input$recipe_save_btn, {
    existing <- list_recipe_records(include_legacy = FALSE)
    suggested <- if (nzchar(input$recipe_select %||% "")) {
      input$recipe_select
    } else {
      paste0("\u914d\u65b9", length(existing) + 1)
    }
    open_save_recipe_modal(suggested)
  })

  observeEvent(input$recipe_confirm_save_btn, {
    name <- trimws(input$recipe_name_input %||% "")
    if (!nzchar(name)) {
      showNotification("\u8bf7\u8f93\u5165\u914d\u65b9\u540d\u79f0\u3002", type = "warning", duration = 3)
      return()
    }

    recipe <- build_current_recipe(name)
    save_recipe(name, recipe)
    removeModal()

    log_info(MODULE, "recipe saved: name=%s chart=%s", name, recipe$chart_id)
    refresh_recipe_select(selected = name)
    showNotification(
      paste0("\u914d\u65b9\u5df2\u4fdd\u5b58\uff1a", name),
      type = "message",
      duration = 3
    )
  })

  observeEvent(input$recipe_load_btn, {
    req(nzchar(input$recipe_select))
    recipe <- load_recipe(input$recipe_select, include_legacy = TRUE)

    if (is.null(recipe) || !nzchar(recipe$chart_id %||% "")) {
      log_warn(MODULE, "recipe load failed: missing or invalid record '%s'", input$recipe_select)
      showNotification("\u9009\u4e2d\u7684\u914d\u65b9\u4e0d\u5b58\u5728\u6216\u5df2\u635f\u574f\u3002", type = "warning", duration = 3)
      return()
    }

    if (!(recipe$chart_id %in% names(CHARTS))) {
      log_warn(MODULE, "recipe load failed: unknown chart_id '%s'", recipe$chart_id)
      showNotification("\u914d\u65b9\u4e2d\u7684\u56fe\u8868\u7c7b\u578b\u5df2\u4e0d\u53ef\u7528\u3002", type = "warning", duration = 3)
      return()
    }

    updateSelectInput(session, "chart_type_select", selected = recipe$chart_id)
    shinyjs::delay(350, {
      restore_recipe_inputs(recipe, CHARTS[[recipe$chart_id]], session)
      restore_color_settings_inputs(recipe$color_settings)
    })

    log_info(MODULE, "recipe loaded: name=%s chart=%s source=%s",
             recipe$name, recipe$chart_id, recipe$source %||% "recipe")
    showNotification(
      paste0("\u914d\u65b9\u5df2\u52a0\u8f7d\uff1a", recipe$name),
      type = "message",
      duration = 3
    )
  })

  observeEvent(input$recipe_delete_btn, {
    req(nzchar(input$recipe_select))
    recipe <- load_recipe(input$recipe_select, include_legacy = TRUE)
    req(!is.null(recipe))

    if (identical(recipe$source %||% "", "legacy")) {
      showNotification(
        "\u65e7\u7248 preset \u4e3a\u53ea\u8bfb\u6761\u76ee\uff0c\u8bf7\u5148\u53e6\u5b58\u4e3a\u65b0\u914d\u65b9\u540e\u518d\u5220\u9664\u3002",
        type = "warning",
        duration = 4
      )
      return()
    }

    showModal(modalDialog(
      title = "\u786e\u8ba4\u5220\u9664\u914d\u65b9",
      size = "s",
      easyClose = TRUE,
      footer = tagList(
        modalButton("\u53d6\u6d88"),
        actionButton("recipe_confirm_delete_btn", "\u5220\u9664", class = "btn btn-danger btn-sm")
      ),
      p(paste0("\u5220\u9664\u914d\u65b9 [", recipe$name, "] \uff1f\u8be5\u64cd\u4f5c\u4e0d\u53ef\u64a4\u9500\u3002"))
    ))
  })

  observeEvent(input$recipe_confirm_delete_btn, {
    name <- isolate(input$recipe_select)
    if (!delete_recipe(name)) {
      showNotification("\u5220\u9664\u5931\u8d25\uff0c\u672a\u627e\u5230\u5f53\u524d\u914d\u65b9\u3002", type = "warning", duration = 3)
      return()
    }

    removeModal()
    log_info(MODULE, "recipe deleted: name=%s", name)
    refresh_recipe_select(selected = "")
    showNotification(paste0("\u914d\u65b9\u5df2\u5220\u9664\uff1a", name), type = "message", duration = 3)
  })

  output$x_min_ui <- renderUI({
    if (!identical(input$x_range_mode %||% "auto", "manual")) return(div())
    numericInput("x_min", "\u0058 \u6700\u5c0f\u503c", value = NA_real_, step = 0.1, width = "100%")
  })

  output$x_max_ui <- renderUI({
    if (!identical(input$x_range_mode %||% "auto", "manual")) return(div())
    numericInput("x_max", "\u0058 \u6700\u5927\u503c", value = NA_real_, step = 0.1, width = "100%")
  })

  output$y_min_ui <- renderUI({
    if (!identical(input$y_range_mode %||% "auto", "manual")) return(div())
    numericInput("y_min", "\u0059 \u6700\u5c0f\u503c", value = NA_real_, step = 0.1, width = "100%")
  })

  output$y_max_ui <- renderUI({
    if (!identical(input$y_range_mode %||% "auto", "manual")) return(div())
    numericInput("y_max", "\u0059 \u6700\u5927\u503c", value = NA_real_, step = 0.1, width = "100%")
  })

  output$axis_hint_ui <- renderUI({
    axis_state <- current_axis_state()
    notes <- character(0)

    if (!isTRUE(axis_state$x_numeric)) {
      notes <- c(notes, "\u5f53\u524d X \u8f74\u4e0d\u662f\u6570\u503c\u8f74\uff0c\u4e0d\u652f\u6301\u624b\u52a8\u8303\u56f4\u3002")
    }
    if (!isTRUE(axis_state$y_numeric)) {
      notes <- c(notes, "\u5f53\u524d Y \u8f74\u4e0d\u662f\u6570\u503c\u8f74\uff0c\u4e0d\u652f\u6301\u624b\u52a8\u8303\u56f4\u3002")
    }

    if (length(notes) == 0) return(NULL)

    tags$div(
      class = "settings-inline-note settings-axis-note",
      lapply(notes, function(note) tags$div(note))
    )
  })

  output$color_settings_ui <- renderUI({
    chart_id <- input$chart_type_select
    if (chart_id %in% c("bar_value", "bar_horizontal", "bar_count", "bar_diverging")) {
      return(tags$p(
        class = "settings-inline-note",
        "\u8be5\u56fe\u5f62\u4e3b\u8981\u4f7f\u7528\u5355\u8272\u6216\u6b63\u8d1f\u53cc\u8272\u63a7\u4ef6\uff0c\u4e0d\u663e\u793a\u9010\u503c\u8986\u76d6\u7f16\u8f91\u5668\u3002"
      ))
    }

    choices <- current_color_columns()
    if (length(choices) == 0) {
      return(tags$p(
        class = "settings-inline-note",
        "\u5f53\u524d\u6570\u636e\u4e2d\u6ca1\u6709\u53ef\u7528\u4e8e\u79bb\u6563\u914d\u8272\u7684\u5206\u7c7b\u5b57\u6bb5\u3002"
      ))
    }

    target <- current_color_target()
    levels <- current_color_levels()
    defaults <- palette_values_for_levels(levels, input$color_palette %||% names(COLOR_PALETTES)[1], list())

    rows <- lapply(levels, function(level) {
      iid <- palette_override_input_id(target, level)
      reset_id <- paste0(iid, "_reset")
      current_val <- isolate(input[[iid]]) %||% defaults[[level]]

      div(
        class = "settings-color-row",
        div(
          class = "settings-color-label",
          tags$span(class = "settings-color-chip", style = paste0("background:", defaults[[level]], ";")),
          tags$span(level)
        ),
        div(
          class = "settings-color-controls",
          colourpicker::colourInput(
            inputId = iid,
            label = NULL,
            value = current_val,
            showColour = "background",
            returnName = FALSE
          ),
          actionButton(reset_id, "\u9ed8\u8ba4", class = "btn btn-sm btn-outline-secondary settings-mini-btn")
        )
      )
    })

    tagList(
      selectInput(
        "palette_target_column",
        "\u989c\u8272\u6620\u5c04\u5b57\u6bb5",
        choices = setNames(choices, choices),
        selected = target,
        width = "100%"
      ),
      tags$div(
        class = "settings-inline-note",
        "\u57fa\u7840 palette \u4f1a\u5148\u751f\u6210\u6240\u6709\u989c\u8272\uff0c\u4e0b\u65b9\u53ea\u9700\u8986\u76d6\u4f60\u60f3\u5355\u72ec\u8c03\u6574\u7684\u503c\u3002"
      ),
      div(class = "settings-color-grid", rows)
    )
  })

  observe({
    target <- current_color_target()
    levels <- current_color_levels()
    base_palette <- input$color_palette %||% names(COLOR_PALETTES)[1]
    defaults <- palette_values_for_levels(levels, base_palette, list())

    for (level in levels) local({
      current_level <- level
      current_target <- target
      reset_id <- paste0(palette_override_input_id(current_target, current_level), "_reset")
      color_input_id <- palette_override_input_id(current_target, current_level)

      observeEvent(input[[reset_id]], {
        colourpicker::updateColourInput(session, color_input_id, value = defaults[[current_level]])
      }, ignoreInit = TRUE)
    })
  })

  output$chart_opts_ui <- renderUI({
    defs <- current_defs()
    if (length(defs) == 0) {
      return(tags$p(class = "text-muted small mt-2", "\u5f53\u524d\u56fe\u8868\u6682\u65e0\u4e13\u5c5e\u8bbe\u7f6e\u3002"))
    }

    basic_defs <- Filter(function(d) (d$group %||% "basic") == "basic", defs)
    adv_defs <- Filter(function(d) (d$group %||% "basic") == "advanced", defs)

    tagList(
      if (length(basic_defs) > 0) build_controls(basic_defs),
      if (length(adv_defs) > 0) {
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel("\u9ad8\u7ea7\u8bbe\u7f6e", build_controls(adv_defs))
        )
      }
    )
  })

  build_scene_cards <- function(presets, id_prefix, family_label, active_chart_type) {
    cards <- lapply(presets, function(p) {
      actionButton(
        inputId = paste0(id_prefix, p$id),
        label = div(
          div(style = "font-size:1.25em; line-height:1.2;", p$icon),
          div(style = "font-weight:600; font-size:0.8rem; margin-top:2px;", p$name),
          div(style = "font-size:0.68rem; color:#6c757d; line-height:1.2;", p$desc)
        ),
        class = paste0(
          "btn btn-light btn-sm scene-card",
          if (identical(active_chart_type, p$chart_type)) " active border-primary" else ""
        ),
        style = paste0(
          "width:90px; height:80px; white-space:normal; text-align:center; ",
          "padding:4px 3px; border:1px solid #dee2e6; border-radius:10px; margin:2px;"
        )
      )
    })

    div(
      class = "settings-scene-block",
      div(class = "settings-inline-note settings-scene-label", family_label),
      div(style = "display:flex; flex-wrap:wrap; gap:4px;", cards)
    )
  }

  apply_scene_preset <- function(p) {
    updateSelectInput(session, "chart_type_select", selected = p$chart_type)

    if (!is.null(p$options$color_palette) && p$options$color_palette %in% names(COLOR_PALETTES)) {
      updateSelectInput(session, "color_palette", selected = p$options$color_palette)
    }

    shinyjs::delay(350, {
      chart <- CHARTS[[p$chart_type]]
      defs <- Filter(function(d) !identical(d$id, "color_palette"), chart$options_def %||% list())
      opts <- p$options %||% list()

      for (d in defs) {
        val <- opts[[d$id]]
        if (is.null(val)) next
        iid <- paste0("opt_", d$id)

        switch(
          d$type,
          slider = updateSliderInput(session, iid, value = val),
          checkbox = updateCheckboxInput(session, iid, value = isTRUE(val)),
          select = updateSelectInput(session, iid, selected = val),
          color = colourpicker::updateColourInput(session, iid, value = val),
          numeric = updateNumericInput(session, iid, value = val),
          text = updateTextInput(session, iid, value = val)
        )
      }
    })

    showNotification(
      paste0("\u5df2\u5e94\u7528\u5b98\u65b9\u573a\u666f\u6a21\u677f\uff1a", p$name),
      type = "message",
      duration = 3
    )
  }

  output$scene_templates_ui <- renderUI({
    current_id <- input$chart_type_select

    bar_ids <- if (length(BAR_FAMILY_IDS) > 0) BAR_FAMILY_IDS else character(0)
    scatter_ids <- if (length(SCATTER_FAMILY_IDS) > 0) SCATTER_FAMILY_IDS else character(0)

    blocks <- list()

    if (isTRUE(current_id %in% bar_ids)) {
      blocks[[length(blocks) + 1L]] <- build_scene_cards(
        BAR_SCENE_PRESETS,
        "bar_scene_",
        "\u67f1\u56fe\u5bb6\u65cf\u5b98\u65b9\u6a21\u677f",
        current_id
      )
    }
    if (isTRUE(current_id %in% scatter_ids)) {
      blocks[[length(blocks) + 1L]] <- build_scene_cards(
        SCATTER_SCENE_PRESETS,
        "scatter_scene_",
        "\u6563\u70b9\u56fe\u5bb6\u65cf\u5b98\u65b9\u6a21\u677f",
        current_id
      )
    }

    if (length(blocks) == 0) {
      return(tags$p(
        class = "settings-inline-note",
        "\u5f53\u524d\u56fe\u8868\u6682\u65e0\u5bf9\u5e94\u7684\u5b98\u65b9\u573a\u666f\u6a21\u677f\u3002"
      ))
    }

    do.call(tagList, blocks)
  })

  lapply(BAR_SCENE_PRESETS, function(p) {
    observeEvent(input[[paste0("bar_scene_", p$id)]], {
      apply_scene_preset(p)
    }, ignoreInit = TRUE)
  })

  lapply(SCATTER_SCENE_PRESETS, function(p) {
    observeEvent(input[[paste0("scatter_scene_", p$id)]], {
      apply_scene_preset(p)
    }, ignoreInit = TRUE)
  })

  # API settings modal
  observeEvent(input$settings_btn, {
    cfg <- isolate(rv$api_config)
    provider <- cfg$provider %||% "kimi"
    pinfo <- LLM_PROVIDERS[[provider]] %||% LLM_PROVIDERS$kimi
    provider_choices <- setNames(names(LLM_PROVIDERS), vapply(LLM_PROVIDERS, `[[`, character(1), "name"))

    showModal(modalDialog(
      title = "AI \u63a5\u53e3\u8bbe\u7f6e",
      size = "m",
      easyClose = TRUE,
      footer = tagList(
        modalButton("\u53d6\u6d88"),
        actionButton("api_save_btn", "\u4fdd\u5b58\u5e76\u5173\u95ed", class = "btn btn-primary btn-sm", icon = icon("floppy-disk"))
      ),
      selectInput("api_provider_select", "\u670d\u52a1\u5546", choices = provider_choices, selected = provider, width = "100%"),
      conditionalPanel(
        condition = "input.api_provider_select === 'custom'",
        textInput(
          "api_custom_url",
          "API URL\uff08OpenAI \u517c\u5bb9\uff09",
          value = cfg$custom_url %||% "",
          placeholder = "https://your-proxy.com/v1/chat/completions",
          width = "100%"
        )
      ),
      passwordInput(
        "api_key_input",
        "API Key",
        value = cfg$api_key %||% "",
        placeholder = pinfo$placeholder %||% "sk-...",
        width = "100%"
      ),
      uiOutput("api_model_ui"),
      tags$hr(),
      tags$small(
        class = "text-muted",
        icon("circle-info"),
        " API Key \u4ec5\u5728\u672c\u5730\u4f7f\u7528\uff0c\u4fdd\u5b58\u540e\u5199\u5165 ~/.r-plot-ai/api_config.json\u3002"
      )
    ))
  })

  output$api_model_ui <- renderUI({
    provider <- input$api_provider_select %||% isolate(rv$api_config$provider) %||% "kimi"
    pinfo <- LLM_PROVIDERS[[provider]] %||% LLM_PROVIDERS$kimi
    current <- isolate(rv$api_config$model) %||% ""

    if (identical(provider, "custom") || length(pinfo$models) == 0) {
      textInput("api_model_input", "\u6a21\u578b\u540d\u79f0", value = current, placeholder = "model-name", width = "100%")
    } else {
      sel <- if (current %in% pinfo$models) current else pinfo$models[1]
      selectInput("api_model_input", "\u6a21\u578b", choices = pinfo$models, selected = sel, width = "100%")
    }
  })

  observeEvent(input$api_save_btn, {
    provider <- input$api_provider_select %||% "kimi"
    api_key <- trimws(input$api_key_input %||% "")
    model <- trimws(input$api_model_input %||% "")
    custom_url <- trimws(input$api_custom_url %||% "")

    if (!nzchar(api_key)) {
      showNotification("API Key \u4e0d\u80fd\u4e3a\u7a7a\u3002", type = "warning", duration = 3)
      return()
    }

    cfg <- list(provider = provider, api_key = api_key, model = model, custom_url = custom_url)
    save_api_config(cfg)
    rv$api_config <- cfg
    removeModal()
    showNotification(
      tags$span(icon("check"), " API \u914d\u7f6e\u5df2\u4fdd\u5b58\uff0c\u91cd\u542f\u540e\u81ea\u52a8\u751f\u6548\u3002"),
      type = "message",
      duration = 3
    )
  })

  invisible(NULL)
}
