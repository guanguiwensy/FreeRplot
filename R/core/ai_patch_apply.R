# =============================================================================
# File   : R/core/ai_patch_apply.R
# Purpose: Shared patch-apply helpers for AI chart updates.
# =============================================================================

build_ai_patch_apply_helpers <- function(input, session, rv, module_name = "mod_ai_chat") {
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

    rv$preserve_data_on_chart_change <- TRUE
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

  list(
    extract_expected_semantics = extract_expected_semantics,
    coerce_bool = coerce_bool,
    run_generate = run_generate,
    apply_column_mapping = apply_column_mapping,
    apply_common_patch = apply_common_patch,
    apply_chart_option_patch = apply_chart_option_patch,
    format_apply_summary = format_apply_summary,
    apply_recommendation = apply_recommendation
  )
}
