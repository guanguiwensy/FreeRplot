# =============================================================================
# File   : R/ui/chat_renderers.R
# Purpose: UI renderers for AI chat messages, suggestions, intent preview,
#          and chart recommendation panel.
# =============================================================================

register_ai_chat_renderers <- function(input, output, session, rv) {
  output$chat_messages_ui <- renderUI({
    visible <- Filter(function(m) m$role != "system", rv$messages)

    if (length(visible) == 0) {
      return(div(
        class = "chat-placeholder text-center py-4",
        tags$p(style = "font-size:1.1rem;", "Ask for a chart recommendation"),
        tags$p("You can also issue direct commands, e.g. set title, set axis ranges, set alpha."),
        tags$hr(),
        tags$ul(
          class = "text-start",
          style = "font-size:0.88rem;",
          tags$li("I have monthly sales by region and product."),
          tags$li("Set title to: Comparison of Revenue"),
          tags$li("Set X range to 0..100 and Y range to 0..1")
        )
      ))
    }

    bubbles <- lapply(visible, function(m) {
      if (m$role == "user") {
        div(class = "user-message-wrapper", div(class = "user-message", p(m$content)))
      } else {
        txt <- strip_json_block(m$content)
        div(
          class = "ai-message-wrapper",
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

    div(
      class = "suggestion-card",
      div(
        class = "d-flex align-items-center gap-2 flex-wrap",
        tags$strong("AI Recommendations"),
        tags$span(class = "badge", style = "background:#0d6efd; color:#fff;", paste0(length(recs), " options"))
      ),
      tags$small(class = "text-muted d-block mt-1", "Select and apply mapping + options."),
      div(
        class = "mt-2",
        selectInput(
          "ai_pick_idx",
          label = NULL,
          choices = setNames(as.character(seq_along(recs)), labels),
          selected = as.character(s$primary_idx %||% 1),
          width = "100%"
        )
      ),
      div(
        class = "mt-2 d-flex gap-2",
        actionButton("apply_suggestion_btn", "Apply Selected", class = "btn btn-primary btn-sm"),
        actionButton("dismiss_suggestion_btn", "Dismiss", class = "btn btn-outline-secondary btn-sm")
      ),
      div(class = "mt-2", details)
    )
  })

  output$intent_preview_ui <- renderUI({
    intent <- rv$pending_intent
    if (is.null(intent)) return(NULL)

    if (identical(intent$mode %||% "", "code_change")) {
      return(
        div(
          class = "intent-preview-card",
          style = paste0(
            "margin:6px 4px; padding:10px 12px; border-radius:8px; ",
            "border:1px solid #0d6efd33; background:#0d6efd0d;"
          ),
          div(
            class = "d-flex align-items-center gap-2 mb-2",
            tags$span(
              style = "font-size:0.72rem; font-weight:600; padding:2px 8px; border-radius:20px; background:#0d6efd; color:#fff;",
              "Code Draft"
            ),
            tags$span(
              style = "font-size:0.85rem; font-weight:600;",
              "AI prepared code changes. Confirm whether to apply."
            )
          ),
          tags$div(
            style = "font-size:0.82rem; color:#2b3a4a; margin-bottom:8px;",
            paste0("Summary: ", intent$summary %||% "Update plot code")
          ),
          div(
            class = "d-flex gap-2 mt-2",
            actionButton("intent_confirm_btn", "Accept Change", class = "btn btn-sm btn-success"),
            actionButton("intent_cancel_btn", "Discard Change", class = "btn btn-sm btn-outline-secondary")
          )
        )
      )
    }

    conf_color <- switch(
      intent$confidence,
      high = "#198754",
      medium = "#fd7e14",
      low = "#dc3545",
      "#6c757d"
    )
    conf_label <- switch(
      intent$confidence,
      high = "High Confidence",
      medium = "Medium Confidence",
      low = "Low Confidence",
      "Unknown"
    )

    rows <- list()
    common_labels <- list(
      plot_title = "Plot Title",
      x_label = "X Label",
      y_label = "Y Label",
      color_palette = "Color Palette",
      chart_theme = "Chart Theme",
      plot_width_in = "Width (in)",
      plot_height_in = "Height (in)",
      plot_dpi = "DPI",
      x_range_mode = "X Range Mode",
      x_min = "X Min",
      x_max = "X Max",
      y_range_mode = "Y Range Mode",
      y_min = "Y Min",
      y_max = "Y Max"
    )

    for (k in names(intent$common_patch %||% list())) {
      lbl <- common_labels[[k]] %||% k
      rows <- c(rows, list(tags$tr(
        tags$td(style = "color:#495057; padding:2px 8px;", lbl),
        tags$td(style = "font-weight:600; padding:2px 8px;", as.character(intent$common_patch[[k]]))
      )))
    }
    for (k in names(intent$options_patch %||% list())) {
      rows <- c(rows, list(tags$tr(
        tags$td(style = "color:#495057; padding:2px 8px;", k),
        tags$td(style = "font-weight:600; padding:2px 8px;", as.character(intent$options_patch[[k]]))
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
          "Confirm the changes below"
        )
      ),
      tags$table(style = "width:100%; font-size:0.82rem;", rows),
      div(
        class = "d-flex gap-2 mt-2",
        actionButton("intent_confirm_btn", "Apply", class = "btn btn-sm btn-success"),
        actionButton("intent_cancel_btn", "Cancel", class = "btn btn-sm btn-outline-secondary")
      )
    )
  })

  output$chart_recommend_ui <- renderUI({
    recs <- rv$chart_recommendations
    profile <- rv$chart_recommend_profile %||% list()

    profile_block <- div(
      class = "recommend-summary mb-2",
      tags$small(
        class = "text-muted",
        sprintf(
          "Data summary: rows=%d, cols=%d, numeric=%d, datetime=%d, categorical/text=%d",
          as.integer(profile$rows %||% 0L),
          as.integer(profile$cols %||% 0L),
          length(profile$numeric_cols %||% character(0)),
          length(profile$datetime_cols %||% character(0)),
          length(profile$categorical_cols %||% character(0))
        )
      )
    )

    if (is.null(recs) || length(recs) == 0) {
      return(
        div(
          class = "recommend-placeholder",
          profile_block,
          tags$small(class = "text-muted", "Click `图形推荐` to compute chart candidates from registry rules.")
        )
      )
    }

    status_label <- function(s) {
      switch(
        s,
        recommended = "Recommended",
        available = "Available",
        not_recommended = "Not Recommended",
        "Unknown"
      )
    }

    status_class <- function(s) {
      switch(
        s,
        recommended = "badge bg-success",
        available = "badge bg-primary",
        not_recommended = "badge bg-secondary",
        "badge bg-light text-dark"
      )
    }

    build_item <- function(rec) {
      id <- rec$chart_id %||% ""
      nm <- rec$chart_name %||% id
      rs <- rec$reason %||% character(0)
      score <- as.integer(rec$score %||% 0)
      status <- rec$status %||% "available"
      reason_id <- paste0("rec_reason_box_", id)

      div(
        class = "recommend-item",
        div(
          class = "d-flex align-items-center justify-content-between gap-2 flex-wrap",
          div(
            class = "d-flex align-items-center gap-2 flex-wrap",
            tags$strong(nm),
            tags$span(class = status_class(status), status_label(status)),
            tags$span(class = "text-muted", sprintf("Score %d", score))
          ),
          div(
            class = "d-flex align-items-center gap-2",
            actionButton(
              paste0("rec_select_", id),
              "选择",
              class = "btn btn-sm btn-outline-primary"
            ),
            actionButton(
              paste0("rec_reason_", id),
              "推荐理由",
              class = "btn btn-sm btn-outline-secondary"
            )
          )
        ),
        div(
          id = reason_id,
          style = "display:none; margin-top:8px;",
          tags$div(
            class = "recommend-reason",
            if (length(rs) == 0) {
              tags$small("This chart fits the current data shape.")
            } else {
              tags$ul(
                class = "mb-0",
                lapply(rs, function(x) tags$li(tags$small(x)))
              )
            }
          )
        )
      )
    }

    top <- head(recs, 16)
    div(
      class = "recommend-list",
      profile_block,
      lapply(top, build_item)
    )
  })

  invisible(NULL)
}
