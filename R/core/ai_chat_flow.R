# =============================================================================
# File   : R/core/ai_chat_flow.R
# Purpose: Main send-button orchestration for AI chat.
# =============================================================================

run_ai_send_flow <- function(user_text, chart_id, input, session, rv, helpers, module_name = "mod_ai_chat") {
  .safe_scalar <- function(x, default = "") {
    if (is.null(x) || length(x) == 0) return(default)
    out <- trimws(as.character(x[[1]] %||% default))
    if (!length(out) || is.na(out)) default else out
  }
  .safe_match <- function(pat, s) {
    if (!is.character(pat) || length(pat) != 1 || !nzchar(pat)) return(FALSE)
    isTRUE(tryCatch(
      grepl(pat, s, ignore.case = TRUE, perl = TRUE),
      error = function(e) FALSE
    ))
  }
  .contains_fixed <- function(s, keys) {
    any(vapply(keys, function(k) grepl(k, s, fixed = TRUE), logical(1)))
  }
  .contains_word <- function(s, keys) {
    any(vapply(keys, function(k) grepl(paste0("\\b", k, "\\b"), s, perl = TRUE), logical(1)))
  }
  .local_smalltalk_reply <- function(s) {
    if (!nzchar(s)) return(NULL)
    if (.safe_match("(are\\s+you\\s+kimi|who\\s+are\\s+you|你是\\s*kimi|你是谁)", s)) {
      return("I am the built-in plotting/code assistant in this app (not Kimi). You can tell me a concrete plotting change and I will draft code changes for your approval.")
    }
    if (.safe_match("^\\s*(hi|hello|hey|你好|您好|哈喽|在吗)\\s*[!,.?。！？]*\\s*$", s)) {
      return("Hello. I am here. You can ask normal chat questions, or directly give plotting tasks such as: set title, add regression line, map point size to Y.")
    }
    if (.safe_match("^\\s*(thanks|thank\\s+you|谢谢|感谢)\\s*[!,.?。！？]*\\s*$", s)) {
      return("You're welcome. If you want, I can continue with the next chart change.")
    }
    NULL
  }
  .is_plot_edit_request <- function(s) {
    if (!nzchar(s)) return(FALSE)
    s1 <- tolower(s)

    # Code-like text almost always means edit intent.
    if (.safe_match("ggplot|geom_|aes\\(|labs\\(|theme_|\\+\\s*geom_|\\bdf\\s*<-", s1)) return(TRUE)

    # Configurable pattern (if provided).
    tune_pat <- .safe_scalar(ai_match_rule_string(c("mod_ai_chat", "tune_like_pattern"), default = ""))
    if (.safe_match(tune_pat, s1)) return(TRUE)

    cn_action <- c(
      "改", "调整", "设置", "设为", "修改",
      "增加", "添加", "删除", "去掉", "移除",
      "显示", "隐藏", "映射", "取消"
    )
    en_action <- c("set", "change", "update", "add", "remove", "delete", "show", "hide", "map")

    cn_target <- c(
      "标题", "轴", "颜色", "透明", "大小", "形状",
      "回归", "趋势", "图例", "主题", "配色",
      "范围", "宽度", "高度", "导出", "下载",
      "散点", "柱状", "折线", "直方", "箱线",
      "热力", "饼图", "图"
    )
    en_target <- c(
      "title", "label", "axis", "color", "colour", "alpha", "opacity", "size", "shape",
      "smooth", "regression", "trend", "legend", "theme", "palette", "range",
      "width", "height", "dpi", "point", "line", "bar", "plot", "chart", "histogram", "scatter"
    )

    has_cn_action <- .contains_fixed(s1, cn_action)
    has_cn_target <- .contains_fixed(s1, cn_target)
    has_en_action <- .contains_word(s1, en_action)
    has_en_target <- .contains_word(s1, en_target)

    if ((has_cn_action && has_cn_target) || (has_en_action && has_en_target)) return(TRUE)

    # Style-only adjustments (e.g. "make it cleaner")
    style_cn <- c("清爽", "简洁", "美观", "好看", "专业")
    style_en <- c("clean", "cleaner", "minimal", "professional", "polish")
    has_style <- .contains_fixed(s1, style_cn) || .contains_word(s1, style_en)
    has_plot_ref <- .contains_fixed(s1, c("图")) || .contains_word(s1, c("plot", "chart"))
    has_style && has_plot_ref
  }
  txt <- .safe_scalar(user_text, default = "")
  if (!nzchar(txt)) return(invisible(FALSE))

  build_ai_context_prompt <- helpers$build_ai_context_prompt
  do_undo <- helpers$do_undo
  queue_code_change <- helpers$queue_code_change
  apply_recommendation <- helpers$apply_recommendation
  MODULE <- module_name

  log_debug(MODULE, "send_btn: user_text='%s'", txt)

  rv$messages <- c(rv$messages, list(list(role = "user", content = txt)))
  updateTextAreaInput(session, "user_input", value = "")
  rv$pending_intent <- NULL

  undo_cmd_pattern <- .safe_scalar(ai_match_rule_string(c("mod_ai_chat", "undo_command_pattern"), default = ""))
  if (.safe_match(undo_cmd_pattern, txt)) {
    do_undo()
    return(invisible(TRUE))
  }

  # Local smalltalk lane: do not enter code-edit flow for greetings/identity chat.
  smalltalk_reply <- .local_smalltalk_reply(txt)
  if (!is.null(smalltalk_reply)) {
    rv$messages <- c(rv$messages, list(list(role = "assistant", content = smalltalk_reply)))
    rv$suggestion <- NULL
    session$sendCustomMessage("scrollChat", list())
    return(invisible(TRUE))
  }

  cfg <- isolate(rv$api_config)
  api_key <- cfg$api_key %||% ""
  model <- cfg$model %||% "moonshot-v1-8k"
  api_url <- get_api_url(cfg)

  should_try_edit <- .is_plot_edit_request(txt)
  intent <- NULL
  if (isTRUE(should_try_edit)) {
    intent <- safe_run(MODULE, parse_intent(txt, chart_id, api_key, model, api_url))
  }
  log_debug(
    MODULE,
    "intent: edit=%s type=%s confidence=%s hits=%d",
    should_try_edit,
    intent$intent_type %||% "NULL",
    intent$confidence %||% "NULL",
    length(intent$hits %||% character(0))
  )

  if (isTRUE(should_try_edit) && !is.null(intent)) {
    compound_pat <- .safe_scalar(ai_match_rule_string(c("mod_ai_chat", "compound_request_pattern"), default = ""))
    is_compound_request <- .safe_match(compound_pat, txt)

    if (identical(intent$intent_type, "undo")) {
      do_undo()
      return(invisible(TRUE))
    }

    if (identical(intent$intent_type, "modify_current") && length(intent$hits) > 0 && !is_compound_request) {
      candidate <- helpers$propose_intent_code_change(intent, chart_id)
      if (isTRUE(candidate$ok) &&
          queue_code_change(candidate$code, candidate$summary, source = paste0("intent:", intent$source %||% "local"))) {
        rv$messages <- c(rv$messages, list(list(
          role = "assistant",
          content = paste0("Generated code-change draft: ", candidate$summary, ". Click Accept Change or Discard Change.")
        )))
        rv$suggestion <- NULL
        session$sendCustomMessage("scrollChat", list())
        return(invisible(TRUE))
      }
    }
  }

  current_code <- isolate(input$plot_code %||% "")
  prefer_code_path <- isTRUE(should_try_edit) && nzchar(current_code)

  # Extra local fallback: parse direct patch intent from configured regex rules.
  # This keeps code-updates usable even when quick regex misses or API is unavailable.
  if (prefer_code_path && nzchar(current_code)) {
    local_patch <- tryCatch(
      helpers$extract_local_patch(txt, chart_id),
      error = function(e) {
        log_warn(MODULE, "extract_local_patch failed: %s", e$message)
        NULL
      }
    )
    if (!is.null(local_patch)) {
      patch_intent <- list(
        intent_type = "modify_current",
        common_patch = local_patch$common_patch %||% list(),
        options_patch = local_patch$options_patch %||% list(),
        source = "local_patch",
        hits = local_patch$hits %||% character(0)
      )
      candidate <- helpers$propose_intent_code_change(patch_intent, chart_id)
      if (isTRUE(candidate$ok) &&
          queue_code_change(candidate$code, candidate$summary, source = "local_patch")) {
        rv$messages <- c(rv$messages, list(list(
          role = "assistant",
          content = "Generated code-change draft from local rules. Click Accept Change or Discard Change."
        )))
        session$sendCustomMessage("scrollChat", list())
        return(invisible(TRUE))
      }
    }
  }

  if (prefer_code_path && nzchar(current_code)) {
    patched <- quick_code_patch(txt, current_code)
    if (!is.null(patched)) {
      if (queue_code_change(patched, "Local quick-rule patch matched", source = "quick")) {
        reply <- "Code-change draft generated (local quick mode). Click Accept Change or Discard Change."
        rv$messages <- c(rv$messages, list(list(role = "assistant", content = reply)))
        session$sendCustomMessage("scrollChat", list())
        return(invisible(TRUE))
      }
    }
  }

  if (prefer_code_path && nzchar(current_code)) {
    data_cols <- names(rv$current_data %||% data.frame())
    patch_prompt <- build_patch_prompt(txt, current_code, data_cols)

    patch_result <- withProgress(message = "AI is preparing a code patch...", value = 0.5, {
      safe_run(MODULE, chat_with_llm(
        messages  = list(list(role = "user", content = patch_prompt)),
        api_key   = api_key,
        model     = model,
        api_url   = api_url,
        json_mode = TRUE
      ))
    })

    if (!is.null(patch_result) && nzchar(patch_result$content %||% "")) {
      parsed <- parse_patch_response(patch_result$content)
      if (parsed$ok) {
        applied <- apply_code_patches(current_code, parsed$patches)
        if (applied$ok) {
          if (queue_code_change(
            applied$code,
            paste0("AI generated ", length(parsed$patches), " code patch(es)"),
            source = "llm_patch"
          )) {
            reply <- paste0(
              "Code-change draft generated (",
              length(parsed$patches),
              " patch(es)). Click Accept Change or Discard Change."
            )
            rv$messages <- c(rv$messages, list(list(role = "assistant", content = reply)))
            session$sendCustomMessage("scrollChat", list())
            return(invisible(TRUE))
          }
        } else {
          log_debug(MODULE, "Layer 2 patch apply failed: %s", applied$failed)
        }
      }
    }
  }

  if (prefer_code_path) {
    rv$messages <- c(rv$messages, list(list(
      role = "assistant",
      content = "Unable to generate an executable code-change draft. Please restate with a concrete goal, e.g. change title, add regression line, or set point shape to 17."
    )))
    session$sendCustomMessage("scrollChat", list())
    return(invisible(TRUE))
  }

  ctx_msg <- list(
    role = "system",
    content = build_ai_context_prompt(rv$current_data, chart_id)
  )

  result <- withProgress(message = "AI is thinking...", value = 0.5, {
    safe_run(MODULE, chat_with_llm(
      messages = c(rv$messages, list(ctx_msg)),
      api_key = api_key,
      model = model,
      api_url = api_url
    ))
  })

  if (is.null(result) || !isTRUE(result$success) || !nzchar(result$content %||% "")) {
    rv$messages <- c(rv$messages, list(list(
      role = "assistant",
      content = "I could not get a valid AI response this time. Please retry, or directly give a concrete plotting instruction."
    )))
    session$sendCustomMessage("scrollChat", list())
    return(invisible(TRUE))
  }

  rv$messages <- c(rv$messages, list(list(role = "assistant", content = result$content)))
  rv$suggestion <- result$suggestion

  if (!is.null(rv$suggestion) && length(rv$suggestion$recommendations) > 0) {
    rec <- rv$suggestion$recommendations[[rv$suggestion$primary_idx %||% 1]]
    if (!is.null(rec) && !is.null(rec$chart_id) && rec$chart_id %in% CHART_IDS) {
      push_history(rv, snapshot_inputs(input))
      apply_recommendation(rec, auto = TRUE)
      rv$suggestion <- NULL
    }
  }

  session$sendCustomMessage("scrollChat", list())
  invisible(TRUE)
}
