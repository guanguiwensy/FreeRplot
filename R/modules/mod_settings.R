# R/modules/mod_settings.R
# Settings-side server logic: show_when, presets, settings modal, scene templates.

init_mod_settings <- function(input, output, session, rv) {

  # show_when conditional visibility
  sw_map <- build_show_when_map(CHARTS)
  all_sw_triggers <- unique(unlist(lapply(sw_map, names)))

  observeEvent(input$chart_type_select, {
    cid <- input$chart_type_select

    shinyjs::delay(250, {
      apply_show_when(sw_map, cid, input)
    })

    if (identical(cid, "bar_count")) {
      showNotification(
        tags$span(icon("circle-info"), "Count mode only needs one category column."),
        type = "message", duration = 4
      )
    }

    if (identical(cid, "bar_errorbar")) {
      showNotification(
        tags$span(icon("circle-info"), "Error bar mode suggests mean+sd/se or ymin+ymax columns."),
        type = "message", duration = 5
      )
    }
  }, ignoreInit = FALSE)

  lapply(all_sw_triggers, function(trigger_id) {
    observeEvent(input[[trigger_id]], {
      apply_show_when(sw_map, input$chart_type_select, input)
    }, ignoreNULL = FALSE, ignoreInit = TRUE)
  })

  # Preset management
  refresh_preset_select <- function(chart_id) {
    nms <- list_preset_names(chart_id)
    choices <- if (length(nms) == 0) {
      c("-- No Presets --" = "")
    } else {
      c("-- Select Preset --" = "", setNames(nms, nms))
    }
    updateSelectInput(session, "preset_select", choices = choices, selected = "")
  }

  observeEvent(input$chart_type_select, {
    refresh_preset_select(input$chart_type_select)
  }, ignoreInit = FALSE)

  observeEvent(input$preset_load_btn, {
    req(nzchar(input$preset_select))

    chart_id <- input$chart_type_select
    presets <- load_presets(chart_id)
    values <- presets[[input$preset_select]]

    if (is.null(values)) {
      showNotification("Selected preset is missing or corrupted.", type = "warning", duration = 3)
      return()
    }

    restore_preset_inputs(CHARTS[[chart_id]], values, session)
    showNotification(paste0("Preset loaded: ", input$preset_select), type = "message", duration = 2)
  })

  observeEvent(input$preset_save_btn, {
    existing <- list_preset_names(input$chart_type_select)
    suggested <- paste0("Preset", length(existing) + 1)

    showModal(modalDialog(
      title = "Save Current Settings as Preset",
      size = "s",
      easyClose = TRUE,
      footer = tagList(
        modalButton("Cancel"),
        actionButton("preset_confirm_save_btn", "Save", class = "btn btn-success btn-sm")
      ),
      textInput(
        "preset_name_input", "Preset Name",
        value = suggested,
        width = "100%",
        placeholder = "Enter preset name"
      )
    ))
  })

  observeEvent(input$preset_confirm_save_btn, {
    name <- trimws(input$preset_name_input %||% "")
    if (!nzchar(name)) {
      showNotification("Please enter a preset name.", type = "warning", duration = 3)
      return()
    }

    chart_id <- isolate(input$chart_type_select)
    values <- c(
      list(
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
      collect_options(input)
    )

    save_preset(chart_id, name, values)
    removeModal()

    refresh_preset_select(chart_id)
    updateSelectInput(session, "preset_select", selected = name)
    showNotification(paste0("Preset saved: ", name), type = "message", duration = 2)
  })

  observeEvent(input$preset_delete_btn, {
    req(nzchar(input$preset_select))
    name <- input$preset_select

    showModal(modalDialog(
      title = "Confirm Delete",
      size = "s",
      easyClose = TRUE,
      footer = tagList(
        modalButton("Cancel"),
        actionButton("preset_confirm_delete_btn", "Delete", class = "btn btn-danger btn-sm")
      ),
      p(paste0("Delete preset [", name, "]? This action cannot be undone."))
    ))
  })

  observeEvent(input$preset_confirm_delete_btn, {
    name <- isolate(input$preset_select)
    chart_id <- isolate(input$chart_type_select)

    delete_preset(chart_id, name)
    removeModal()
    refresh_preset_select(chart_id)
    showNotification(paste0("Preset deleted: ", name), type = "message", duration = 2)
  })

  # API settings modal
  observeEvent(input$settings_btn, {
    cfg      <- isolate(rv$api_config)
    provider <- cfg$provider %||% "kimi"
    pinfo    <- LLM_PROVIDERS[[provider]] %||% LLM_PROVIDERS$kimi
    models   <- if (length(pinfo$models) > 0) pinfo$models else "custom-model"

    provider_choices <- setNames(names(LLM_PROVIDERS), vapply(LLM_PROVIDERS, `[[`, character(1), "name"))

    showModal(modalDialog(
      title = "AI 接口设置",
      size  = "m",
      easyClose = TRUE,
      footer = tagList(
        modalButton("取消"),
        actionButton("api_save_btn", "保存并关闭", class = "btn btn-primary btn-sm",
                     icon = icon("floppy-disk"))
      ),

      # Provider select
      selectInput("api_provider_select", "服务商",
                  choices  = provider_choices,
                  selected = provider,
                  width    = "100%"),

      # Custom URL (only shown for "custom")
      conditionalPanel(
        condition = "input.api_provider_select === 'custom'",
        textInput("api_custom_url", "API URL (OpenAI 兼容)",
                  value       = cfg$custom_url %||% "",
                  placeholder = "https://your-proxy.com/v1/chat/completions",
                  width       = "100%")
      ),

      # API Key
      passwordInput("api_key_input", "API Key",
                    value       = cfg$api_key %||% "",
                    placeholder = pinfo$placeholder %||% "sk-...",
                    width       = "100%"),

      # Model
      uiOutput("api_model_ui"),

      tags$hr(),
      tags$small(
        class = "text-muted",
        icon("circle-info"), " API Key 仅在本地使用，",
        tags$strong("保存后写入 ~/.r-plot-ai/api_config.json"),
        "，重启应用自动读取，无需重复输入。"
      )
    ))
  })

  # Dynamic model selector inside modal
  output$api_model_ui <- renderUI({
    provider <- input$api_provider_select %||% isolate(rv$api_config$provider) %||% "kimi"
    pinfo    <- LLM_PROVIDERS[[provider]] %||% LLM_PROVIDERS$kimi
    current  <- isolate(rv$api_config$model) %||% ""

    if (identical(provider, "custom") || length(pinfo$models) == 0) {
      textInput("api_model_input", "模型名称",
                value       = current,
                placeholder = "model-name",
                width       = "100%")
    } else {
      sel <- if (current %in% pinfo$models) current else pinfo$models[1]
      selectInput("api_model_input", "模型",
                  choices  = pinfo$models,
                  selected = sel,
                  width    = "100%")
    }
  })

  # Save config to disk + update rv
  observeEvent(input$api_save_btn, {
    provider   <- input$api_provider_select %||% "kimi"
    api_key    <- trimws(input$api_key_input %||% "")
    model      <- trimws(input$api_model_input %||% "")
    custom_url <- trimws(input$api_custom_url %||% "")

    if (!nzchar(api_key)) {
      showNotification("API Key 不能为空。", type = "warning", duration = 3)
      return()
    }

    cfg <- list(provider = provider, api_key = api_key, model = model, custom_url = custom_url)
    save_api_config(cfg)
    rv$api_config <- cfg
    removeModal()
    showNotification(
      tags$span(icon("check"), " API 配置已保存，重启后自动生效。"),
      type = "message", duration = 3
    )
  })

  # Dynamic chart-specific options panel
  output$chart_opts_ui <- renderUI({
    chart <- CHARTS[[input$chart_type_select]]
    defs <- chart$options_def
    if (is.null(defs)) defs <- list()

    if (length(defs) == 0) {
      return(tags$p(class = "text-muted small mt-2", "No chart-specific settings for this chart."))
    }

    basic_defs <- Filter(function(d) (d$group %||% "basic") == "basic", defs)
    adv_defs <- Filter(function(d) (d$group %||% "basic") == "advanced", defs)

    tagList(
      if (length(basic_defs) > 0) build_controls(basic_defs),
      if (length(adv_defs) > 0)
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel("Advanced", build_controls(adv_defs))
        )
    )
  })

  build_scene_cards <- function(presets, id_prefix, active_chart_type) {
    cards <- lapply(presets, function(p) {
      actionButton(
        inputId = paste0(id_prefix, p$id),
        label = div(
          div(style = "font-size:1.3em; line-height:1.2;", p$icon),
          div(style = "font-weight:600; font-size:0.78rem; margin-top:2px;", p$name),
          div(style = "font-size:0.68rem; color:#6c757d; line-height:1.2;", p$desc)
        ),
        class = paste0(
          "btn btn-light btn-sm scene-card",
          if (identical(active_chart_type, p$chart_type)) " active border-primary" else ""
        ),
        style = paste0(
          "width:86px; height:76px; white-space:normal; text-align:center; ",
          "padding:4px 3px; border:1px solid #dee2e6; border-radius:8px; ",
          "margin:2px; vertical-align:top;"
        )
      )
    })

    tagList(
      tags$p(class = "text-muted small mb-1 mt-1", style = "font-weight:600; letter-spacing:.03em;", "Scene Templates"),
      div(style = "display:flex; flex-wrap:wrap; gap:2px; margin-bottom:4px;", cards),
      tags$hr(style = "margin: 8px 0 6px;")
    )
  }

  apply_scene_preset <- function(p) {
    updateSelectInput(session, "chart_type_select", selected = p$chart_type)

    shinyjs::delay(450, {
      chart <- CHARTS[[p$chart_type]]
      defs <- chart$options_def %||% list()
      opts <- p$options

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
      tags$span(icon("wand-magic-sparkles"), paste0("Scene template applied: ", p$name)),
      type = "message", duration = 2
    )
  }

  output$bar_scene_ui <- renderUI({
    bar_ids <- if (length(BAR_FAMILY_IDS) > 0) BAR_FAMILY_IDS else {
      bar_key <- grep("\u67f1\u56fe", names(CHART_MENU_GROUPS), value = TRUE)[1]
      if (!is.na(bar_key)) unname(unlist(CHART_MENU_GROUPS[[bar_key]])) else character(0)
    }

    if (!isTRUE(input$chart_type_select %in% bar_ids)) return(NULL)
    build_scene_cards(BAR_SCENE_PRESETS, "bar_scene_", input$chart_type_select)
  })

  output$scatter_scene_ui <- renderUI({
    scatter_ids <- if (length(SCATTER_FAMILY_IDS) > 0) SCATTER_FAMILY_IDS else {
      scatter_key <- grep("\u6563\u70b9\u56fe", names(CHART_MENU_GROUPS), value = TRUE)[1]
      if (!is.na(scatter_key)) unname(unlist(CHART_MENU_GROUPS[[scatter_key]])) else character(0)
    }

    if (!isTRUE(input$chart_type_select %in% scatter_ids)) return(NULL)
    build_scene_cards(SCATTER_SCENE_PRESETS, "scatter_scene_", input$chart_type_select)
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

  invisible(NULL)
}