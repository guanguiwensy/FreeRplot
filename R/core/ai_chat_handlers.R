# =============================================================================
# File   : R/core/ai_chat_handlers.R
# Purpose: ObserveEvent handlers for AI chat and chart-recommendation
#          interactions.  Owns the full recommendation flow:
#            1. recommend_run_btn  → show settings modal (column selection,
#                                    number of recommendations)
#            2. rec_run_confirm_btn → run recommendation engine, generate
#                                    PNG thumbnail previews from user data,
#                                    write rv$chart_recommendations /
#                                    rv$chart_recommend_previews
#            3. rec_select_{id}    → switch chart type + trigger mapping modal
#          Also owns: AI send, intent confirm/cancel, undo, suggestion apply.
#
# Depends:
#   R/core/chart_recommender.R   (profile_data_for_recommend,
#                                  recommend_charts_for_data)
#   R/core/code_engine.R         (get_editor_code)
#   R/core/module_shared.R       (shared_prepare_code_context)
#   R/ui_helpers.R               (get_default_options)
#   R/utils/logger.R             (log_info, log_warn)
#   R/core/ai_chat_flow.R        (run_ai_send_flow)
#   ggplot2, grDevices            — preview rendering
#   jsonlite                      — base64 encoding
#
# Exported functions:
#   register_ai_chat_handlers(input, output, session, rv, helpers,
#                              module_name = "mod_ai_chat")
#     Registers all observers.  helpers is a list produced by
#     R/core/ai_chat_helpers.R (do_undo, get_pick_rec, apply_intent,
#     apply_recommendation).
#
# Key rv fields written:
#   rv$chart_recommendations     [list]  top-N recommendation objects
#   rv$chart_recommend_profile   [list]  data profile from recommender
#   rv$chart_recommend_previews  [list]  chart_id → base64 PNG string
# =============================================================================

register_ai_chat_handlers <- function(input, output, session, rv, helpers, module_name = "mod_ai_chat") {
  do_undo <- helpers$do_undo
  get_pick_rec <- helpers$get_pick_rec
  apply_intent <- helpers$apply_intent
  apply_recommendation <- helpers$apply_recommendation
  MODULE <- module_name

  # ── Helper: auto-rename user columns to match chart's spec column names ───────
  # Uses the chart's `columns` field (e.g. "x(数值), group(分组), value(数值)")
  # to positionally map user columns: exact match → case-insensitive → positional.
  .map_user_data_for_chart <- function(data, chart_id) {
    if (!is.data.frame(data) || nrow(data) == 0) return(data)
    chart <- CHARTS[[chart_id]]
    if (is.null(chart)) return(data)
    columns_txt <- trimws(as.character(chart$columns %||% ""))
    if (!nzchar(columns_txt)) return(data)

    # Parse spec column names from "x(desc), group(desc), value(desc)"
    parts      <- strsplit(columns_txt, ",\\s*")[[1]]
    spec_names <- trimws(sub("\\s*\\(.*$", "", parts))
    spec_names <- spec_names[nzchar(spec_names)]
    if (length(spec_names) == 0) return(data)

    df         <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
    user_cols  <- names(df)
    new_names  <- user_cols
    used_src   <- integer(0)   # indices of user cols already assigned

    for (tgt in spec_names) {
      if (tgt %in% new_names) next  # already has correct name → skip

      # 1. Case-insensitive match among unassigned user cols
      avail_idx <- setdiff(seq_along(user_cols), used_src)
      ci <- avail_idx[tolower(user_cols[avail_idx]) == tolower(tgt)]
      if (length(ci) > 0) {
        new_names[ci[1]] <- tgt
        used_src <- c(used_src, ci[1])
        next
      }
      # 2. Positional: first unassigned col whose current name is NOT a spec name
      pos_pool <- avail_idx[!(user_cols[avail_idx] %in% spec_names)]
      if (length(pos_pool) > 0) {
        new_names[pos_pool[1]] <- tgt
        used_src <- c(used_src, pos_pool[1])
      }
    }

    if (!anyDuplicated(new_names)) names(df) <- new_names
    df
  }

  # ── Helper: render one chart with user data → base64 PNG ─────────────────────
  .generate_preview_b64 <- function(chart_id, data) {
    if (!is.data.frame(data) || nrow(data) == 0) return(NULL)
    chart <- CHARTS[[chart_id]]
    if (is.null(chart)) return(NULL)

    # Remap user columns to chart's expected names
    mapped <- tryCatch(
      .map_user_data_for_chart(data, chart_id),
      error = function(e) data
    )

    opts <- tryCatch(get_default_options(chart_id), error = function(e) list())

    # Try plot_fn with mapped user data
    p <- NULL
    if (is.function(chart$plot_fn)) {
      p <- tryCatch(
        withCallingHandlers(
          chart$plot_fn(mapped, opts),
          warning = function(w) invokeRestart("muffleWarning")
        ),
        error = function(e) {
          log_warn(MODULE, "plot_fn(%s) error: %s", chart_id, e$message)
          NULL
        }
      )
    }

    # Fallback: eval code_template with mapped data
    if (is.null(p) || !inherits(p, "ggplot")) {
      if (is.function(chart$code_template)) {
        raw_code <- tryCatch({
          argn <- length(formals(chart$code_template))
          if (argn >= 2L) chart$code_template(opts, mapped)
          else            chart$code_template(opts)
        }, error = function(e) NULL)

        if (!is.null(raw_code) && nzchar(trimws(raw_code))) {
          env <- new.env(parent = globalenv())
          env$data <- mapped
          env$df   <- mapped
          p <- tryCatch(
            withCallingHandlers(
              eval(parse(text = raw_code), envir = env),
              warning = function(w) invokeRestart("muffleWarning")
            ),
            error = function(e) {
              log_warn(MODULE, "code_template eval(%s) error: %s",
                       chart_id, e$message)
              NULL
            }
          )
          if (!inherits(p, "ggplot"))
            p <- tryCatch(ggplot2::last_plot(), error = function(e) NULL)
        }
      }
    }

    if (is.null(p) || !inherits(p, "ggplot")) return(NULL)

    # Save to temp PNG and base64-encode
    f <- tempfile(fileext = ".png")
    saved <- tryCatch({
      grDevices::png(f, width = 320, height = 240, res = 72, type = "cairo")
      print(p)
      grDevices::dev.off()
      TRUE
    }, error = function(e) {
      try(grDevices::dev.off(), silent = TRUE)
      tryCatch({
        ggplot2::ggsave(f, plot = p, width = 3.2, height = 2.4,
                        dpi = 72, bg = "white")
        TRUE
      }, error = function(e2) FALSE)
    })

    if (!saved || !file.exists(f) || file.size(f) == 0) return(NULL)
    raw_bytes <- readBin(f, "raw", file.size(f))
    unlink(f)
    jsonlite::base64_enc(raw_bytes)
  }

  # ── Core recommendation engine ───────────────────────────────────────────────
  # selected_cols: character vector of column names to use (NULL = all)
  # n_recs:        how many top recommendations to keep
  run_recommendations <- function(selected_cols = NULL, n_recs = 3L) {
    data <- isolate(rv$current_data)

    # Subset to user-selected columns
    if (!is.null(selected_cols) && length(selected_cols) > 0 &&
        is.data.frame(data)) {
      valid_cols <- intersect(selected_cols, names(data))
      if (length(valid_cols) > 0)
        data <- data[, valid_cols, drop = FALSE]
    }

    profile <- tryCatch(
      profile_data_for_recommend(data),
      error = function(e) {
        log_warn(MODULE, "data profile failed: %s", e$message)
        list(rows = 0L, cols = 0L,
             numeric_cols = character(0),
             datetime_cols = character(0),
             categorical_cols = character(0))
      }
    )
    rv$chart_recommend_profile <- profile

    recs_all <- tryCatch(
      recommend_charts_for_data(
        data = data, registry = CHART_CAP_REG,
        charts = CHARTS, data_summary = profile
      ),
      error = function(e) {
        log_warn(MODULE, "recommendation failed: %s", e$message)
        list()
      }
    )
    top_recs <- head(recs_all, max(1L, as.integer(n_recs)))
    rv$chart_recommendations <- top_recs

    # Generate thumbnail previews
    previews <- list()
    for (rec in top_recs) {
      cid <- rec$chart_id %||% ""
      if (!nzchar(cid)) next
      b64 <- tryCatch(.generate_preview_b64(cid, data), error = function(e) NULL)
      if (!is.null(b64)) previews[[cid]] <- b64
    }
    rv$chart_recommend_previews <- previews

    log_info(MODULE, "recommendations done: %d results, %d previews",
             length(top_recs), length(previews))
    invisible(top_recs)
  }

  # ── Button: open settings modal ──────────────────────────────────────────────
  observeEvent(input$recommend_run_btn, {
    data     <- isolate(rv$current_data)
    col_names <- if (is.data.frame(data) && ncol(data) > 0) names(data) else character(0)

    if (length(col_names) == 0) {
      showNotification(
        "\u8bf7\u5148\u5bfc\u5165\u6570\u636e\uff0c\u518d\u8fdb\u884c\u56fe\u5f62\u63a8\u8350\u3002",
        type = "warning", duration = 4
      )
      return()
    }

    showModal(modalDialog(
      title = "\u56fe\u5f62\u63a8\u8350\u8bbe\u7f6e",
      tags$p(
        class = "text-muted mb-3",
        "\u9009\u62e9\u5206\u6790\u6240\u7528\u7684\u5217\uff0c\u8f6f\u4ef6\u5c06\u6839\u636e\u6570\u636e\u7279\u5f81\u81ea\u52a8\u63a8\u8350\u6700\u9002\u5408\u7684\u56fe\u8868\u7c7b\u578b\u5e76\u751f\u6210\u9884\u89c8\u56fe\u3002"
      ),
      selectInput(
        "rec_col_select",
        "\u8981\u5206\u6790\u7684\u5217\uff08\u53ef\u591a\u9009\uff09",
        choices  = col_names,
        selected = col_names,
        multiple = TRUE,
        width    = "100%",
        selectize = FALSE
      ),
      numericInput(
        "rec_count",
        "\u63a8\u8350\u56fe\u8868\u6570\u91cf\uff08\u9ed8\u8ba43\uff09",
        value = 3L, min = 1L, max = 10L, step = 1L,
        width = "160px"
      ),
      footer = tagList(
        modalButton("\u53d6\u6d88"),
        actionButton(
          "rec_run_confirm_btn",
          "\u5f00\u59cb\u5206\u6790",
          class = "btn btn-primary",
          icon  = icon("chart-bar")
        )
      ),
      easyClose = TRUE,
      size = "m"
    ))
  }, ignoreInit = TRUE)

  # ── Button: confirm → run analysis ───────────────────────────────────────────
  observeEvent(input$rec_run_confirm_btn, {
    cols  <- input$rec_col_select
    n_raw <- input$rec_count
    n     <- tryCatch(as.integer(n_raw), warning = function(e) 3L)
    if (is.na(n) || n < 1L) n <- 3L
    removeModal()
    showNotification(
      "\u6b63\u5728\u5206\u6790\u6570\u636e\u5e76\u751f\u6210\u9884\u89c8\u56fe\uff0c\u8bf7\u7a0d\u5019\u2026",
      duration = 3
    )
    recs <- run_recommendations(selected_cols = cols, n_recs = n)
    n_found <- length(recs %||% list())
    showNotification(
      sprintf("\u5df2\u751f\u6210 %d \u4e2a\u63a8\u8350\u56fe\u8868\u3002", n_found),
      type = "message", duration = 4
    )
  }, ignoreInit = TRUE)

  # ── AI chat send ─────────────────────────────────────────────────────────────
  observeEvent(input$send_btn, {
    tryCatch(
      run_ai_send_flow(
        user_text = input$user_input %||% "",
        chart_id = isolate(input$chart_type_select),
        input = input,
        session = session,
        rv = rv,
        helpers = helpers,
        module_name = MODULE
      ),
      error = function(e) {
        log_warn(MODULE, "send_btn flow failed: %s", e$message)
        rv$messages <- c(rv$messages, list(list(
          role = "assistant",
          content = "AI processing failed this time, but the session is still active. Please retry with a shorter command."
        )))
        session$sendCustomMessage("scrollChat", list())
      }
    )
  })

  observeEvent(input$intent_confirm_btn, {
    intent <- rv$pending_intent
    req(!is.null(intent))

    if (identical(intent$mode %||% "", "code_change")) {
      push_history(rv, snapshot_inputs(input))
      shinyAce::updateAceEditor(session, "plot_code", value = intent$patched_code %||% "")
      shinyjs::delay(200, shinyjs::click("run_code_btn"))
      rv$messages <- c(rv$messages, list(list(role = "assistant", content = "Applied code changes and re-rendered the plot.")))
      rv$pending_intent <- NULL
      session$sendCustomMessage("scrollChat", list())
      return()
    }

    push_history(rv, snapshot_inputs(input))
    chart_id <- isolate(input$chart_type_select)
    reply <- apply_intent(intent, chart_id)
    rv$messages <- c(rv$messages, list(list(role = "assistant", content = reply)))
    rv$pending_intent <- NULL
    session$sendCustomMessage("scrollChat", list())
  })

  observeEvent(input$intent_cancel_btn, {
    if (identical((rv$pending_intent$mode %||% ""), "code_change")) {
      rv$pending_intent <- NULL
      rv$messages <- c(rv$messages, list(list(role = "assistant", content = "Code-change draft discarded.")))
      session$sendCustomMessage("scrollChat", list())
      return()
    }
    rv$pending_intent <- NULL
    rv$messages <- c(rv$messages, list(list(role = "assistant", content = "Canceled. No changes were applied.")))
    session$sendCustomMessage("scrollChat", list())
  })

  observeEvent(input$clear_btn, {
    rv$messages <- list(list(role = "system", content = build_system_prompt()))
    rv$suggestion <- NULL
    rv$pending_intent <- NULL
    rv$patch_history <- list()
  })

  observeEvent(input$undo_btn, {
    do_undo()
  })

  observeEvent(input$apply_suggestion_btn, {
    rec <- get_pick_rec()
    req(!is.null(rec))
    apply_recommendation(rec, auto = FALSE)
  })

  observeEvent(input$dismiss_suggestion_btn, {
    rv$suggestion <- NULL
  })

  # ── "使用" buttons in recommendation cards ────────────────────────────────────
  # Do NOT set preserve_data_on_chart_change — let the column-mapping modal
  # appear so the user can align their columns before generating the plot.
  lapply(CHART_IDS, function(id) {
    observeEvent(input[[paste0("rec_select_", id)]], {
      updateSelectInput(session, "chart_type_select", selected = id)
      # chart_type_select observer in mod_data.R will show mapping modal
      # when user data is present; after mapping the user clicks generate.
    }, ignoreInit = TRUE)
  })

  invisible(NULL)
}
