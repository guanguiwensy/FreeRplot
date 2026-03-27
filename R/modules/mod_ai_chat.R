# R/modules/mod_ai_chat.R
# AI chat server logic (Kimi): messaging, suggestion card, and chat rendering.

init_mod_ai_chat <- function(input, output, session, rv) {

  summarize_data_for_ai <- function(data, max_cols = 20, max_levels = 6) {
    if (is.null(data) || ncol(data) == 0) {
      return("rows=0, cols=0")
    }

    lines <- c(sprintf("rows=%d, cols=%d", nrow(data), ncol(data)), "columns:")
    cols <- names(data)
    keep <- cols[seq_len(min(length(cols), max_cols))]

    for (nm in keep) {
      v <- data[[nm]]
      typ <- class(v)[1]
      miss <- sum(is.na(v))
      uniq <- length(unique(v))
      vals <- unique(v)
      vals <- vals[!is.na(vals)]
      vals <- head(vals, max_levels)
      sample_txt <- if (length(vals) == 0) "" else paste(as.character(vals), collapse = ", ")

      lines <- c(lines, sprintf("- %s: type=%s, missing=%d, unique=%d, sample=[%s]", nm, typ, miss, uniq, sample_txt))
    }

    if (length(cols) > length(keep)) {
      lines <- c(lines, sprintf("- ... %d more columns", length(cols) - length(keep)))
    }

    paste(lines, collapse = "\n")
  }

  build_ai_context_prompt <- function(data, chart_id) {
    paste(
      "Runtime context:",
      sprintf("current_chart_id=%s", chart_id %||% ""),
      summarize_data_for_ai(data),
      "If user asks to tune current chart (title/labels/theme/palette/range/size), keep current_chart_id and return options_patch only.",
      "When recommending column_mapping, use existing column names exactly.",
      sep = "\n"
    )
  }

  extract_expected_semantics <- function(chart) {
    cols_txt <- chart$columns %||% ""
    hits <- regmatches(cols_txt, gregexpr("[A-Za-z_]+\\s*\\(", cols_txt, perl = TRUE))[[1]]
    if (length(hits) == 0 || identical(hits, "-1")) {
      return(c("x", "y", "group", "size", "label"))
    }
    sem <- trimws(gsub("\\($", "", hits))
    unique(sem)
  }

  coerce_bool <- function(x) {
    if (is.logical(x)) return(isTRUE(x))
    if (is.numeric(x)) return(!is.na(x[1]) && x[1] != 0)
    s <- tolower(trimws(as.character(x)[1]))
    s %in% c("true", "1", "yes", "y", "t", "on", "open", "enable")
  }

  run_generate <- function() {
    shinyjs::delay(200, shinyjs::click("generate_btn"))
  }

  apply_column_mapping <- function(chart_id, mapping) {
    if (!is.list(mapping) || length(mapping) == 0) {
      return(list(changed = FALSE, applied = character(0)))
    }

    data <- rv$current_data
    if (is.null(data) || ncol(data) == 0) {
      return(list(changed = FALSE, applied = character(0)))
    }

    expected <- extract_expected_semantics(CHARTS[[chart_id]])
    mapped <- list()
    used_source <- character(0)
    applied <- character(0)

    for (key in expected) {
      raw <- mapping[[key]]
      if (is.null(raw)) next

      src <- trimws(as.character(raw)[1])
      if (!nzchar(src)) next
      if (tolower(src) %in% c("null", "na", "none")) next
      if (!(src %in% names(data))) next
      if (key %in% names(mapped)) next

      mapped[[key]] <- data[[src]]
      used_source <- c(used_source, src)
      applied <- c(applied, sprintf("%s <- %s", key, src))
    }

    if (length(applied) == 0) {
      return(list(changed = FALSE, applied = character(0)))
    }

    for (nm in names(data)) {
      if (nm %in% used_source) next
      if (nm %in% names(mapped)) next
      mapped[[nm]] <- data[[nm]]
    }

    rv$current_data <- as.data.frame(mapped, stringsAsFactors = FALSE, check.names = FALSE)
    list(changed = TRUE, applied = applied)
  }

  apply_common_patch <- function(patch) {
    if (!is.list(patch) || length(patch) == 0) return(character(0))
    applied <- character(0)

    if (!is.null(patch$plot_title)) {
      updateTextInput(session, "plot_title", value = as.character(patch$plot_title)); applied <- c(applied, "plot_title")
    }
    if (!is.null(patch$x_label)) {
      updateTextInput(session, "x_label", value = as.character(patch$x_label)); applied <- c(applied, "x_label")
    }
    if (!is.null(patch$y_label)) {
      updateTextInput(session, "y_label", value = as.character(patch$y_label)); applied <- c(applied, "y_label")
    }

    if (!is.null(patch$color_palette) && as.character(patch$color_palette) %in% names(COLOR_PALETTES)) {
      updateSelectInput(session, "color_palette", selected = as.character(patch$color_palette)); applied <- c(applied, "color_palette")
    }
    if (!is.null(patch$chart_theme) && as.character(patch$chart_theme) %in% names(CHART_THEMES)) {
      updateSelectInput(session, "chart_theme", selected = as.character(patch$chart_theme)); applied <- c(applied, "chart_theme")
    }

    if (!is.null(patch$plot_width_in)) {
      updateNumericInput(session, "plot_width_in", value = suppressWarnings(as.numeric(patch$plot_width_in))); applied <- c(applied, "plot_width_in")
    }
    if (!is.null(patch$plot_height_in)) {
      updateNumericInput(session, "plot_height_in", value = suppressWarnings(as.numeric(patch$plot_height_in))); applied <- c(applied, "plot_height_in")
    }
    if (!is.null(patch$plot_dpi)) {
      updateNumericInput(session, "plot_dpi", value = suppressWarnings(as.numeric(patch$plot_dpi))); applied <- c(applied, "plot_dpi")
    }

    if (!is.null(patch$x_range_mode) && as.character(patch$x_range_mode) %in% c("auto", "manual")) {
      updateSelectInput(session, "x_range_mode", selected = as.character(patch$x_range_mode)); applied <- c(applied, "x_range_mode")
    }
    if (!is.null(patch$y_range_mode) && as.character(patch$y_range_mode) %in% c("auto", "manual")) {
      updateSelectInput(session, "y_range_mode", selected = as.character(patch$y_range_mode)); applied <- c(applied, "y_range_mode")
    }
    if (!is.null(patch$x_min)) {
      updateNumericInput(session, "x_min", value = suppressWarnings(as.numeric(patch$x_min))); applied <- c(applied, "x_min")
    }
    if (!is.null(patch$x_max)) {
      updateNumericInput(session, "x_max", value = suppressWarnings(as.numeric(patch$x_max))); applied <- c(applied, "x_max")
    }
    if (!is.null(patch$y_min)) {
      updateNumericInput(session, "y_min", value = suppressWarnings(as.numeric(patch$y_min))); applied <- c(applied, "y_min")
    }
    if (!is.null(patch$y_max)) {
      updateNumericInput(session, "y_max", value = suppressWarnings(as.numeric(patch$y_max))); applied <- c(applied, "y_max")
    }

    unique(applied)
  }

  apply_chart_option_patch <- function(chart_id, patch) {
    if (!is.list(patch) || length(patch) == 0) return(character(0))

    chart <- CHARTS[[chart_id]]
    defs <- chart$options_def %||% list()
    if (length(defs) == 0) return(character(0))

    applied <- character(0)

    for (d in defs) {
      if (is.null(patch[[d$id]])) next
      val <- patch[[d$id]]
      iid <- paste0("opt_", d$id)

      switch(
        d$type,
        slider = updateSliderInput(session, iid, value = suppressWarnings(as.numeric(val))),
        checkbox = updateCheckboxInput(session, iid, value = coerce_bool(val)),
        select = updateSelectInput(session, iid, selected = as.character(val)),
        color = colourpicker::updateColourInput(session, iid, value = as.character(val)),
        numeric = updateNumericInput(session, iid, value = suppressWarnings(as.numeric(val))),
        text = updateTextInput(session, iid, value = as.character(val))
      )

      applied <- c(applied, d$id)
    }

    unique(applied)
  }

  format_apply_summary <- function(map_applied, common_applied, chart_applied) {
    summary_parts <- c()
    if (length(map_applied) > 0) summary_parts <- c(summary_parts, paste0("mapping: ", paste(map_applied, collapse = ", ")))
    if (length(common_applied) > 0) summary_parts <- c(summary_parts, paste0("global: ", paste(common_applied, collapse = ", ")))
    if (length(chart_applied) > 0) summary_parts <- c(summary_parts, paste0("chart options: ", paste(chart_applied, collapse = ", ")))
    if (length(summary_parts) == 0) "No patch fields were applied." else paste(summary_parts, collapse = " ; ")
  }

  apply_recommendation <- function(rec, auto = FALSE) {
    chart_id <- rec$chart_id
    if (!(chart_id %in% CHART_IDS)) {
      showNotification("Invalid chart recommendation.", type = "warning", duration = 3)
      return(invisible(FALSE))
    }

    updateSelectInput(session, "chart_type_select", selected = chart_id)

    map_res <- apply_column_mapping(chart_id, rec$column_mapping %||% list())
    common_applied <- apply_common_patch(rec$options_patch %||% list())

    shinyjs::delay(450, {
      chart_applied <- apply_chart_option_patch(chart_id, rec$options_patch %||% list())
      run_generate()

      msg <- format_apply_summary(map_res$applied, common_applied, chart_applied)
      showNotification(
        paste0(if (auto) "AI auto-applied -> " else "AI suggestion applied -> ", CHARTS[[chart_id]]$name, " | ", msg),
        type = "message", duration = 6
      )
    })

    invisible(TRUE)
  }

  extract_local_patch <- function(user_text, chart_id) {
    txt <- trimws(user_text)
    if (!nzchar(txt)) return(NULL)

    common <- list()
    opt <- list()
    hits <- character(0)

    # Title / labels
    m <- regexec("(?:标题|title)\\s*(?:改成|改为|设为|=|:)\\s*[\"“”']?([^\"“”']+)[\"“”']?", txt, perl = TRUE, ignore.case = TRUE)
    r <- regmatches(txt, m)[[1]]
    if (length(r) >= 2) {
      common$plot_title <- trimws(r[2]); hits <- c(hits, "plot_title")
    }

    m <- regexec("(?:x轴|x轴标题|x label|xlabel)\\s*(?:改成|改为|设为|=|:)\\s*[\"“”']?([^\"“”']+)[\"“”']?", txt, perl = TRUE, ignore.case = TRUE)
    r <- regmatches(txt, m)[[1]]
    if (length(r) >= 2) {
      common$x_label <- trimws(r[2]); hits <- c(hits, "x_label")
    }

    m <- regexec("(?:y轴|y轴标题|y label|ylabel)\\s*(?:改成|改为|设为|=|:)\\s*[\"“”']?([^\"“”']+)[\"“”']?", txt, perl = TRUE, ignore.case = TRUE)
    r <- regmatches(txt, m)[[1]]
    if (length(r) >= 2) {
      common$y_label <- trimws(r[2]); hits <- c(hits, "y_label")
    }

    # Width / height / dpi
    m <- regexec("(?:宽度|width)\\s*(?:改成|改为|设为|=|:)?\\s*([0-9]+(?:\\.[0-9]+)?)", txt, perl = TRUE, ignore.case = TRUE)
    r <- regmatches(txt, m)[[1]]
    if (length(r) >= 2) {
      common$plot_width_in <- as.numeric(r[2]); hits <- c(hits, "plot_width_in")
    }

    m <- regexec("(?:高度|height)\\s*(?:改成|改为|设为|=|:)?\\s*([0-9]+(?:\\.[0-9]+)?)", txt, perl = TRUE, ignore.case = TRUE)
    r <- regmatches(txt, m)[[1]]
    if (length(r) >= 2) {
      common$plot_height_in <- as.numeric(r[2]); hits <- c(hits, "plot_height_in")
    }

    m <- regexec("(?:dpi|分辨率)\\s*(?:改成|改为|设为|=|:)?\\s*([0-9]+(?:\\.[0-9]+)?)", txt, perl = TRUE, ignore.case = TRUE)
    r <- regmatches(txt, m)[[1]]
    if (length(r) >= 2) {
      common$plot_dpi <- as.numeric(r[2]); hits <- c(hits, "plot_dpi")
    }

    # Axis ranges
    m <- regexec("(?:x范围|x range)\\s*([\\-]?[0-9]+(?:\\.[0-9]+)?)\\s*(?:到|~|-)\\s*([\\-]?[0-9]+(?:\\.[0-9]+)?)", txt, perl = TRUE, ignore.case = TRUE)
    r <- regmatches(txt, m)[[1]]
    if (length(r) >= 3) {
      common$x_range_mode <- "manual"
      common$x_min <- as.numeric(r[2])
      common$x_max <- as.numeric(r[3])
      hits <- c(hits, "x_range")
    }

    m <- regexec("(?:y范围|y range)\\s*([\\-]?[0-9]+(?:\\.[0-9]+)?)\\s*(?:到|~|-)\\s*([\\-]?[0-9]+(?:\\.[0-9]+)?)", txt, perl = TRUE, ignore.case = TRUE)
    r <- regmatches(txt, m)[[1]]
    if (length(r) >= 3) {
      common$y_range_mode <- "manual"
      common$y_min <- as.numeric(r[2])
      common$y_max <- as.numeric(r[3])
      hits <- c(hits, "y_range")
    }

    if (grepl("x.*自动.*范围|x范围.*自动", txt, perl = TRUE, ignore.case = TRUE)) {
      common$x_range_mode <- "auto"; hits <- c(hits, "x_range_mode")
    }
    if (grepl("y.*自动.*范围|y范围.*自动", txt, perl = TRUE, ignore.case = TRUE)) {
      common$y_range_mode <- "auto"; hits <- c(hits, "y_range_mode")
    }

    # Theme/palette by exact names
    for (nm in names(CHART_THEMES)) {
      if (grepl(nm, txt, fixed = TRUE)) {
        common$chart_theme <- nm; hits <- c(hits, "chart_theme"); break
      }
    }
    for (nm in names(COLOR_PALETTES)) {
      if (grepl(nm, txt, fixed = TRUE)) {
        common$color_palette <- nm; hits <- c(hits, "color_palette"); break
      }
    }

    # Common chart option aliases
    defs <- CHARTS[[chart_id]]$options_def %||% list()
    has_opt <- function(opt_id) any(vapply(defs, function(d) identical(d$id, opt_id), logical(1)))

    if (has_opt("alpha")) {
      m <- regexec("(?:透明度|alpha)\\s*(?:改成|改为|设为|=|:)?\\s*([0-9]+(?:\\.[0-9]+)?)", txt, perl = TRUE, ignore.case = TRUE)
      r <- regmatches(txt, m)[[1]]
      if (length(r) >= 2) {
        opt$alpha <- as.numeric(r[2]); hits <- c(hits, "opt_alpha")
      }
    }
    if (has_opt("point_size")) {
      m <- regexec("(?:点大小|点尺寸|point ?size)\\s*(?:改成|改为|设为|=|:)?\\s*([0-9]+(?:\\.[0-9]+)?)", txt, perl = TRUE, ignore.case = TRUE)
      r <- regmatches(txt, m)[[1]]
      if (length(r) >= 2) {
        opt$point_size <- as.numeric(r[2]); hits <- c(hits, "opt_point_size")
      }
    }
    if (has_opt("show_smooth")) {
      if (grepl("趋势线|拟合线|smooth", txt, ignore.case = TRUE)) {
        if (grepl("开|显示|开启|on|true", txt, ignore.case = TRUE)) {
          opt$show_smooth <- TRUE; hits <- c(hits, "opt_show_smooth")
        } else if (grepl("关|隐藏|关闭|off|false", txt, ignore.case = TRUE)) {
          opt$show_smooth <- FALSE; hits <- c(hits, "opt_show_smooth")
        }
      }
    }
    if (has_opt("show_labels")) {
      if (grepl("标签|label", txt, ignore.case = TRUE)) {
        if (grepl("开|显示|开启|on|true", txt, ignore.case = TRUE)) {
          opt$show_labels <- TRUE; hits <- c(hits, "opt_show_labels")
        } else if (grepl("关|隐藏|关闭|off|false", txt, ignore.case = TRUE)) {
          opt$show_labels <- FALSE; hits <- c(hits, "opt_show_labels")
        }
      }
    }

    if (length(hits) == 0) return(NULL)
    list(common_patch = common, options_patch = opt, hits = unique(hits))
  }

  get_pick_rec <- function() {
    s <- rv$suggestion
    if (is.null(s) || length(s$recommendations) == 0) return(NULL)
    idx <- suppressWarnings(as.integer(input$ai_pick_idx %||% 1))
    if (is.na(idx) || idx < 1 || idx > length(s$recommendations)) idx <- 1
    s$recommendations[[idx]]
  }

  # ── Helper: apply an intent object (common + options patches) ────────────────
  apply_intent <- function(intent, chart_id) {
    common_applied <- apply_common_patch(intent$common_patch %||% list())
    shinyjs::delay(300, {
      chart_applied <- apply_chart_option_patch(chart_id, intent$options_patch %||% list())
      run_generate()
      summary_txt <- format_apply_summary(character(0), common_applied, chart_applied)
      showNotification(paste0("✅ 已应用：", summary_txt), type = "message", duration = 4)
    })
    paste0("已调整参数：", format_intent_summary(intent))
  }

  # ── Main send handler ─────────────────────────────────────────────────────────
  observeEvent(input$send_btn, {
    user_text <- trimws(input$user_input)
    req(nchar(user_text) > 0)

    rv$messages <- c(rv$messages, list(list(role = "user", content = user_text)))
    updateTextAreaInput(session, "user_input", value = "")
    rv$pending_intent <- NULL   # dismiss any pending preview on new message

    chart_id  <- isolate(input$chart_type_select)
    cfg       <- isolate(rv$api_config)
    api_key   <- cfg$api_key   %||% ""
    model     <- cfg$model     %||% "moonshot-v1-8k"
    api_url   <- get_api_url(cfg)

    # ── Step 1: intent engine (local first, then LLM) ──────────────────────
    intent <- parse_intent(user_text, chart_id, api_key, model, api_url)

    # ── Step 2: dispatch by intent type and confidence ─────────────────────
    if (!is.null(intent)) {

      # Undo
      if (identical(intent$intent_type, "undo")) {
        did_undo <- restore_last(rv, session)
        reply <- if (did_undo) {
          run_generate()
          "✅ 已撤销上一步操作，图表已还原。"
        } else "⚠️ 没有可撤销的历史操作。"
        rv$messages <- c(rv$messages, list(list(role = "assistant", content = reply)))
        session$sendCustomMessage("scrollChat", list())
        return()
      }

      # modify_current
      if (identical(intent$intent_type, "modify_current") && length(intent$hits) > 0) {

        if (identical(intent$confidence, "high")) {
          # Auto-apply: snapshot → apply → echo
          push_history(rv, snapshot_inputs(input))
          reply <- apply_intent(intent, chart_id)
          rv$messages <- c(rv$messages, list(list(role = "assistant", content = reply)))
          rv$suggestion <- NULL
          session$sendCustomMessage("scrollChat", list())
          return()
        }

        if (identical(intent$confidence, "medium")) {
          # Show preview card, wait for confirm
          rv$pending_intent <- intent
          reply <- paste0(
            "我理解你想：**", format_intent_summary(intent), "**\n\n",
            "请确认后点「应用」，或点「取消」。"
          )
          rv$messages <- c(rv$messages, list(list(role = "assistant", content = reply)))
          session$sendCustomMessage("scrollChat", list())
          return()
        }

        if (identical(intent$confidence, "low") && isTRUE(intent$needs_clarification)) {
          q <- if (nzchar(intent$clarify_question %||% ""))
            intent$clarify_question
          else "请再说详细一点，比如具体的数值或字段名。"
          rv$messages <- c(rv$messages, list(list(role = "assistant", content = q)))
          session$sendCustomMessage("scrollChat", list())
          return()
        }
      }
    }

    # ── Step 3: fall through to full AI chat path ──────────────────────────
    ctx_msg <- list(
      role    = "system",
      content = build_ai_context_prompt(rv$current_data, chart_id)
    )

    result <- withProgress(message = "AI 思考中…", value = 0.5, {
      chat_with_llm(
        messages = c(rv$messages, list(ctx_msg)),
        api_key  = api_key,
        model    = model,
        api_url  = api_url
      )
    })

    rv$messages   <- c(rv$messages, list(list(role = "assistant", content = result$content)))
    rv$suggestion <- result$suggestion

    # Auto-apply primary recommendation for tuning-like requests
    tuning_like <- grepl(
      "\u6539|\u8bbe|\u8c03\u6574|\u4fee\u6539|\u6807\u9898|\u4e3b\u9898|\u914d\u8272|\u900f\u660e|\u5927\u5c0f|\u8303\u56f4|\u8f74|label|title",
      user_text, ignore.case = TRUE
    )
    if (tuning_like && !is.null(rv$suggestion) && length(rv$suggestion$recommendations) > 0) {
      rec <- rv$suggestion$recommendations[[rv$suggestion$primary_idx %||% 1]]
      if (!is.null(rec) && !is.null(rec$chart_id) && rec$chart_id %in% CHART_IDS) {
        push_history(rv, snapshot_inputs(input))
        apply_recommendation(rec, auto = TRUE)
        rv$suggestion <- NULL
      }
    }

    session$sendCustomMessage("scrollChat", list())
  })

  # ── Confirm pending intent ────────────────────────────────────────────────
  observeEvent(input$intent_confirm_btn, {
    intent <- rv$pending_intent
    req(!is.null(intent))
    push_history(rv, snapshot_inputs(input))
    chart_id <- isolate(input$chart_type_select)
    reply <- apply_intent(intent, chart_id)
    rv$messages <- c(rv$messages, list(list(role = "assistant", content = reply)))
    rv$pending_intent <- NULL
    session$sendCustomMessage("scrollChat", list())
  })

  # ── Cancel pending intent ─────────────────────────────────────────────────
  observeEvent(input$intent_cancel_btn, {
    rv$pending_intent <- NULL
    rv$messages <- c(rv$messages, list(list(role = "assistant", content = "已取消，没有做任何修改。")))
    session$sendCustomMessage("scrollChat", list())
  })

  observeEvent(input$clear_btn, {
    rv$messages        <- list(list(role = "system", content = build_system_prompt()))
    rv$suggestion      <- NULL
    rv$pending_intent  <- NULL
    rv$patch_history   <- list()
  })

  observeEvent(input$apply_suggestion_btn, {
    rec <- get_pick_rec()
    req(!is.null(rec))
    apply_recommendation(rec, auto = FALSE)
  })

  output$chat_messages_ui <- renderUI({
    visible <- Filter(function(m) m$role != "system", rv$messages)

    if (length(visible) == 0) {
      return(div(class = "chat-placeholder text-center py-4",
                 tags$p(style = "font-size:1.1rem;", "Ask for a chart recommendation"),
                 tags$p("You can also issue direct commands, e.g. 标题改成aaa / X范围0到10 / 透明度0.5"),
                 tags$hr(),
                 tags$ul(class = "text-start", style = "font-size:0.88rem;",
                         tags$li("I have monthly sales by region and product."),
                         tags$li("标题改成：Comparison of Revenue"),
                         tags$li("X范围 0 到 100, Y范围 0 到 1")
                 )
      ))
    }

    bubbles <- lapply(visible, function(m) {
      if (m$role == "user") {
        div(class = "user-message-wrapper", div(class = "user-message", p(m$content)))
      } else {
        txt <- strip_json_block(m$content)
        div(class = "ai-message-wrapper",
            span(class = "ai-avatar", "AI"),
            div(class = "ai-message", p(txt))
        )
      }
    })

    div(class = "messages-list", bubbles)
  })

  output$suggestion_ui <- renderUI({
    s <- rv$suggestion
    if (is.null(s) || length(s$recommendations) == 0) return(NULL)

    recs <- s$recommendations
    labels <- vapply(seq_along(recs), function(i) {
      rec <- recs[[i]]
      chart <- CHARTS[[rec$chart_id]]
      paste0(i, ". ", chart$name, " [", toupper(rec$confidence), "]")
    }, character(1))

    details <- lapply(seq_along(recs), function(i) {
      rec <- recs[[i]]
      chart <- CHARTS[[rec$chart_id]]
      warn_txt <- if (length(rec$warnings %||% character(0)) > 0) paste(rec$warnings, collapse = " | ") else "None"

      tags$div(
        class = "mb-2 p-2 border rounded",
        tags$div(tags$b(paste0(i, ". ", chart$name, " (", chart$id, ")"))),
        tags$div(tags$small(class = "text-muted", paste0("Reason: ", rec$reason %||% ""))),
        tags$div(tags$small(class = "text-muted", paste0("Warnings: ", warn_txt)))
      )
    })

    div(class = "suggestion-card",
        div(class = "d-flex align-items-center gap-2 flex-wrap",
            tags$strong("AI Recommendations"),
            tags$span(class = "badge", style = "background:#0d6efd; color:#fff;", paste0(length(recs), " options"))
        ),
        tags$small(class = "text-muted d-block mt-1", "Select and apply mapping + options."),
        div(class = "mt-2",
            selectInput("ai_pick_idx", label = NULL,
                        choices = setNames(as.character(seq_along(recs)), labels),
                        selected = as.character(s$primary_idx %||% 1),
                        width = "100%")
        ),
        div(class = "mt-2 d-flex gap-2",
            actionButton("apply_suggestion_btn", "Apply Selected", class = "btn btn-primary btn-sm"),
            actionButton("dismiss_suggestion_btn", "Dismiss", class = "btn btn-outline-secondary btn-sm")
        ),
        div(class = "mt-2", details)
    )
  })

  observeEvent(input$dismiss_suggestion_btn, {
    rv$suggestion <- NULL
  })

  # ── Intent preview card ───────────────────────────────────────────────────
  output$intent_preview_ui <- renderUI({
    intent <- rv$pending_intent
    if (is.null(intent)) return(NULL)

    conf_color <- switch(intent$confidence,
      high   = "#198754",
      medium = "#fd7e14",
      low    = "#dc3545",
      "#6c757d"
    )
    conf_label <- switch(intent$confidence,
      high = "高置信度", medium = "中置信度", low = "低置信度", "未知"
    )

    # Build a table of changes
    rows <- list()
    common_labels <- list(
      plot_title    = "图表标题",  x_label   = "X轴标签",  y_label       = "Y轴标签",
      color_palette = "配色方案",  chart_theme = "图表主题",
      plot_width_in = "宽度(in)",  plot_height_in = "高度(in)", plot_dpi = "DPI",
      x_range_mode  = "X范围模式", x_min = "X最小", x_max = "X最大",
      y_range_mode  = "Y范围模式", y_min = "Y最小", y_max = "Y最大"
    )
    for (k in names(intent$common_patch %||% list())) {
      lbl <- common_labels[[k]] %||% k
      rows <- c(rows, list(tags$tr(
        tags$td(style = "color:#495057; padding:2px 8px;", lbl),
        tags$td(style = "font-weight:600; padding:2px 8px;",
                as.character(intent$common_patch[[k]]))
      )))
    }
    for (k in names(intent$options_patch %||% list())) {
      rows <- c(rows, list(tags$tr(
        tags$td(style = "color:#495057; padding:2px 8px;", k),
        tags$td(style = "font-weight:600; padding:2px 8px;",
                as.character(intent$options_patch[[k]]))
      )))
    }

    div(
      class = "intent-preview-card",
      style = paste0(
        "margin:6px 4px; padding:10px 12px; border-radius:8px; ",
        "border:1px solid ", conf_color, "33; ",
        "background:", conf_color, "0d;"
      ),
      div(
        class = "d-flex align-items-center gap-2 mb-2",
        tags$span(
          style = paste0(
            "font-size:0.72rem; font-weight:600; padding:2px 8px; border-radius:20px; ",
            "background:", conf_color, "; color:#fff;"
          ),
          conf_label
        ),
        tags$span(
          style = "font-size:0.85rem; font-weight:600;",
          "确认以下修改？"
        )
      ),
      tags$table(style = "width:100%; font-size:0.82rem;", rows),
      div(
        class = "d-flex gap-2 mt-2",
        actionButton("intent_confirm_btn", "✅ 应用",
                     class = "btn btn-sm btn-success"),
        actionButton("intent_cancel_btn",  "✖ 取消",
                     class = "btn btn-sm btn-outline-secondary")
      )
    )
  })

  invisible(NULL)
}