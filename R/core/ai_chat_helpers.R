# =============================================================================
# File   : R/core/ai_chat_helpers.R
# Purpose: Shared helper bundle for mod_ai_chat.
# =============================================================================

build_ai_chat_helpers <- function(input, session, rv, module_name = "mod_ai_chat") {
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

  do_undo <- function() {
    did_undo <- restore_last(rv, session)
    reply <- if (did_undo) {
      "Undo completed. Previous state restored."
    } else {
      "No undo history available yet."
    }
    rv$messages <- c(rv$messages, list(list(role = "assistant", content = reply)))
    session$sendCustomMessage("scrollChat", list())
    invisible(did_undo)
  }

  queue_code_change <- function(new_code, summary, source = "local") {
    current_code <- isolate(input$plot_code %||% "")
    if (!nzchar(new_code) || identical(trimws(new_code), trimws(current_code))) {
      return(FALSE)
    }

    rv$pending_intent <- list(
      mode = "code_change",
      patched_code = new_code,
      summary = summary %||% "Prepared code update",
      source = source
    )
    TRUE
  }

  patch_apply <- build_ai_patch_apply_helpers(input, session, rv, module_name = module_name)
  local_parser <- build_ai_local_patch_parser(input, session, rv, module_name = module_name)

  apply_common_patch <- patch_apply$apply_common_patch
  apply_chart_option_patch <- patch_apply$apply_chart_option_patch
  apply_recommendation <- patch_apply$apply_recommendation
  apply_column_mapping <- patch_apply$apply_column_mapping
  format_apply_summary <- patch_apply$format_apply_summary
  run_generate <- patch_apply$run_generate
  extract_local_patch <- local_parser$extract_local_patch

  get_pick_rec <- function() {
    s <- rv$suggestion
    if (is.null(s) || length(s$recommendations) == 0) return(NULL)
    idx <- suppressWarnings(as.integer(input$ai_pick_idx %||% 1))
    if (is.na(idx) || idx < 1 || idx > length(s$recommendations)) idx <- 1
    s$recommendations[[idx]]
  }

  propose_intent_code_change <- function(intent, chart_id) {
    current_code <- isolate(input$plot_code %||% "")
    if (!nzchar(current_code)) {
      return(list(ok = FALSE, code = current_code, summary = "", reason = "empty_code"))
    }

    patches <- .intent_to_code_patches(intent, current_code)
    if (length(patches) == 0) {
      return(list(ok = FALSE, code = current_code, summary = "", reason = "no_patch"))
    }

    result <- apply_code_patches(current_code, patches)
    if (!isTRUE(result$ok)) {
      return(list(ok = FALSE, code = current_code, summary = "", reason = result$failed %||% "apply_failed"))
    }

    list(
      ok = TRUE,
      code = result$code,
      summary = format_intent_summary(intent),
      reason = "ok"
    )
  }

  apply_intent <- function(intent, chart_id) {
    current_code <- isolate(input$plot_code %||% "")
    patches <- .intent_to_code_patches(intent, current_code)

    if (length(patches) > 0) {
      result <- apply_code_patches(current_code, patches)
      if (result$ok) {
        shinyAce::updateAceEditor(session, "plot_code", value = result$code)
        shinyjs::delay(200, shinyjs::click("run_code_btn"))
        log_info(module_name, "apply_intent via code patches: %d patches applied", length(patches))
        return(paste0("Updated code: ", format_intent_summary(intent)))
      }
      log_debug(module_name, "code patch failed: %s ; falling back to widget patch", result$failed)
    }

    common_applied <- apply_common_patch(intent$common_patch %||% list())
    shinyjs::delay(300, {
      chart_applied <- apply_chart_option_patch(chart_id, intent$options_patch %||% list())
      run_generate()
      summary_txt <- format_apply_summary(character(0), common_applied, chart_applied)
      showNotification(paste0("Applied (widget mode): ", summary_txt), type = "message", duration = 4)
    })

    paste0("Adjusted params: ", format_intent_summary(intent))
  }

  .intent_to_code_patches <- function(intent, code) {
    patches <- list()

    cp <- intent$common_patch %||% list()
    op <- intent$options_patch %||% list()

    if (!is.null(cp$plot_title) && grepl('title\\s*=\\s*"', code, perl = TRUE)) {
      patches <- c(patches, list(list(
        search = regmatches(code, regexpr('title\\s*=\\s*"[^"]*"', code, perl = TRUE)),
        replace = paste0('title = "', cp$plot_title, '"')
      )))
    }
    if (!is.null(cp$x_label) && grepl('(?<=[\\s,])x\\s*=\\s*"[^"]*"', code, perl = TRUE)) {
      patches <- c(patches, list(list(
        search = regmatches(code, regexpr('(?<=[\\s,])x\\s*=\\s*"[^"]*"', code, perl = TRUE)),
        replace = paste0('x = "', cp$x_label, '"')
      )))
    }
    if (!is.null(cp$y_label) && grepl('(?<=[\\s,])y\\s*=\\s*"[^"]*"', code, perl = TRUE)) {
      patches <- c(patches, list(list(
        search = regmatches(code, regexpr('(?<=[\\s,])y\\s*=\\s*"[^"]*"', code, perl = TRUE)),
        replace = paste0('y = "', cp$y_label, '"')
      )))
    }
    if (!is.null(cp$chart_theme) && grepl("theme_\\w+\\(\\)", code, perl = TRUE)) {
      patches <- c(patches, list(list(
        search = regmatches(code, regexpr("theme_\\w+\\(\\)", code, perl = TRUE)),
        replace = paste0("theme_", cp$chart_theme, "()")
      )))
    }
    if (!is.null(cp$color_palette) && grepl('palette\\s*=\\s*"[^"]*"', code, perl = TRUE)) {
      patches <- c(patches, list(list(
        search = regmatches(code, regexpr('palette\\s*=\\s*"[^"]*"', code, perl = TRUE)),
        replace = paste0('palette = "', cp$color_palette, '"')
      )))
    }

    if (!is.null(op$alpha) && grepl("\\balpha\\s*=\\s*[0-9.]+", code, perl = TRUE)) {
      patches <- c(patches, list(list(
        search = regmatches(code, regexpr("\\balpha\\s*=\\s*[0-9.]+", code, perl = TRUE)),
        replace = paste0("alpha = ", op$alpha)
      )))
    }
    if (!is.null(op$point_size)) {
      point_size_raw <- trimws(as.character(op$point_size)[1] %||% "")

      if (nzchar(point_size_raw) && grepl("^[0-9]+(?:\\.[0-9]+)?$", point_size_raw) &&
          grepl("\\bsize\\s*=\\s*[0-9.]+", code, perl = TRUE)) {
        patches <- c(patches, list(list(
          search = regmatches(code, regexpr("\\bsize\\s*=\\s*[0-9.]+", code, perl = TRUE)),
          replace = paste0("size = ", point_size_raw)
        )))
      } else {
        mapped_var <- tolower(point_size_raw)
        if (mapped_var %in% c("x", "y")) {
          aes_hit <- regmatches(code, regexpr("aes\\([^\\)]*\\)", code, perl = TRUE))
          if (length(aes_hit) > 0 && nzchar(aes_hit) && !grepl("\\bsize\\s*=", aes_hit, perl = TRUE)) {
            aes_new <- sub("\\)$", paste0(", size = ", mapped_var, ")"), aes_hit, perl = TRUE)
            patches <- c(patches, list(list(search = aes_hit, replace = aes_new)))
          }
          size_hit <- regmatches(code, regexpr("\\bsize\\s*=\\s*[0-9.]+\\s*,?\\s*", code, perl = TRUE))
          if (length(size_hit) > 0 && nzchar(size_hit)) {
            patches <- c(patches, list(list(search = size_hit, replace = "")))
          }
        }
      }
    }
    if (!is.null(op$point_shape) && grepl("\\bshape\\s*=\\s*(\"[^\"]+\"|'[^']+'|[0-9]+)", code, perl = TRUE)) {
      patches <- c(patches, list(list(
        search = regmatches(code, regexpr("\\bshape\\s*=\\s*(\"[^\"]+\"|'[^']+'|[0-9]+)", code, perl = TRUE)),
        replace = paste0("shape = ", as.character(op$point_shape))
      )))
    }
    if (!is.null(op$show_smooth)) {
      if (isTRUE(op$show_smooth) && !grepl("geom_smooth", code, fixed = TRUE)) {
        anchor <- regmatches(code, regexpr("geom_\\w+[^+]*\\+", code, perl = TRUE))
        if (length(anchor) > 0 && nzchar(anchor)) {
          patches <- c(patches, list(list(
            search = anchor,
            replace = paste0(anchor, "\n  geom_smooth(method = \"loess\", se = TRUE) +")
          )))
        }
      }
      if (!isTRUE(op$show_smooth) && grepl("geom_smooth", code, fixed = TRUE)) {
        sm <- regmatches(code, regexpr("\\s*\\+?\\s*geom_smooth\\([^)]*\\)", code, perl = TRUE))
        if (length(sm) > 0 && nzchar(sm)) {
          patches <- c(patches, list(list(search = sm, replace = "")))
        }
      }
    }

    Filter(function(p) !is.null(p$search) && length(p$search) > 0 && nzchar(p$search), patches)
  }

  list(
    summarize_data_for_ai = summarize_data_for_ai,
    build_ai_context_prompt = build_ai_context_prompt,
    do_undo = do_undo,
    queue_code_change = queue_code_change,
    apply_column_mapping = apply_column_mapping,
    apply_common_patch = apply_common_patch,
    apply_chart_option_patch = apply_chart_option_patch,
    format_apply_summary = format_apply_summary,
    apply_recommendation = apply_recommendation,
    extract_local_patch = extract_local_patch,
    get_pick_rec = get_pick_rec,
    propose_intent_code_change = propose_intent_code_change,
    apply_intent = apply_intent,
    intent_to_code_patches = .intent_to_code_patches
  )
}
