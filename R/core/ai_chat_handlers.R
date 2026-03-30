# =============================================================================
# File   : R/core/ai_chat_handlers.R
# Purpose: ObserveEvent handlers for AI chat interactions.
# =============================================================================

register_ai_chat_handlers <- function(input, output, session, rv, helpers, module_name = "mod_ai_chat") {
  do_undo <- helpers$do_undo
  get_pick_rec <- helpers$get_pick_rec
  apply_intent <- helpers$apply_intent
  apply_recommendation <- helpers$apply_recommendation
  MODULE <- module_name

  refresh_recommendations <- function() {
    data <- isolate(rv$current_data)
    profile <- tryCatch(
      profile_data_for_recommend(data),
      error = function(e) {
        log_warn(MODULE, "data profile failed: %s", e$message)
        list(
          rows = 0L,
          cols = 0L,
          numeric_cols = character(0),
          datetime_cols = character(0),
          categorical_cols = character(0)
        )
      }
    )
    rv$chart_recommend_profile <- profile

    recs <- tryCatch(
      recommend_charts_for_data(
        data = data,
        registry = CHART_CAP_REG,
        charts = CHARTS,
        data_summary = profile
      ),
      error = function(e) {
        log_warn(MODULE, "recommendation refresh failed: %s", e$message)
        list()
      }
    )
    rv$chart_recommendations <- recs
    invisible(recs)
  }

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

  observeEvent(input$recommend_run_btn, {
    recs <- refresh_recommendations()
    n <- length(recs %||% list())
    showNotification(sprintf("图形推荐已更新（%d 个候选）", n), type = "message", duration = 3)
  }, ignoreInit = TRUE)

  observeEvent(rv$current_data, {
    refresh_recommendations()
  }, ignoreInit = FALSE)

  observeEvent(input$chart_type_select, {
    refresh_recommendations()
  }, ignoreInit = TRUE)

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

  lapply(CHART_IDS, function(id) {
    observeEvent(input[[paste0("rec_select_", id)]], {
      rv$preserve_data_on_chart_change <- TRUE
      updateSelectInput(session, "chart_type_select", selected = id)
      shinyjs::delay(120, shinyjs::click("generate_btn"))
      rv$messages <- c(rv$messages, list(list(
        role = "assistant",
        content = paste0("已选择图形：", CHARTS[[id]]$name %||% id, "。")
      )))
      session$sendCustomMessage("scrollChat", list())
    }, ignoreInit = TRUE)

    observeEvent(input[[paste0("rec_reason_", id)]], {
      shinyjs::toggle(id = paste0("rec_reason_box_", id), anim = TRUE, animType = "slide")
    }, ignoreInit = TRUE)
  })

  invisible(NULL)
}
