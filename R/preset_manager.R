# R/preset_manager.R
# Preset save / load / delete — file-backed JSON storage.
#
# Layout on disk:
#   presets/{chart_id}.json
#
# Each file is a JSON object:
#   {
#     "我的预设1": { "plot_title": "...", "color_palette": "...", "point_size": 3, ... },
#     "我的预设2": { ... }
#   }
#
# Common settings (plot_title, x_label, y_label, color_palette, chart_theme) are
# stored alongside the opt_* values under the same flat keys.


# ── Paths ─────────────────────────────────────────────────────────────────────

preset_dir <- function() {
  d <- file.path(getwd(), "presets")
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  d
}

preset_file <- function(chart_id) {
  file.path(preset_dir(), paste0(chart_id, ".json"))
}


# ── load_presets() ─────────────────────────────────────────────────────────────
#
# Returns a named list of all saved presets for a chart.
# Returns an empty list if no preset file exists yet.

load_presets <- function(chart_id) {
  f <- preset_file(chart_id)
  if (!file.exists(f)) return(list())
  tryCatch(
    jsonlite::fromJSON(f, simplifyVector = FALSE),
    error = function(e) list()
  )
}


# ── list_preset_names() ────────────────────────────────────────────────────────

list_preset_names <- function(chart_id) {
  names(load_presets(chart_id))
}


# ── save_preset() ──────────────────────────────────────────────────────────────
#
# Saves (or overwrites) a named preset.
# values: named list — typically the output of c(common_opts, collect_options(input))

save_preset <- function(chart_id, name, values) {
  name <- trimws(name)
  if (!nzchar(name)) return(invisible(FALSE))
  presets         <- load_presets(chart_id)
  presets[[name]] <- values
  jsonlite::write_json(presets, preset_file(chart_id),
                       auto_unbox = TRUE, pretty = TRUE)
  invisible(TRUE)
}


# ── delete_preset() ────────────────────────────────────────────────────────────

delete_preset <- function(chart_id, name) {
  presets         <- load_presets(chart_id)
  presets[[name]] <- NULL
  if (length(presets) == 0) {
    unlink(preset_file(chart_id))
  } else {
    jsonlite::write_json(presets, preset_file(chart_id),
                         auto_unbox = TRUE, pretty = TRUE)
  }
  invisible(TRUE)
}


# ── restore_preset_inputs() ────────────────────────────────────────────────────
#
# Pushes a preset's stored values back into Shiny inputs.
#
# Args:
#   chart    one entry from CHARTS (must have $options_def)
#   values   named list from load_presets(chart_id)[[name]]
#   session  Shiny session object

restore_preset_inputs <- function(chart, values, session) {
  if (is.null(values) || length(values) == 0) return(invisible(NULL))

  # ── Common / shared inputs ───────────────────────────────────────────────────
  if (!is.null(values[["plot_title"]]))
    updateTextInput(session,   "plot_title",    value    = values[["plot_title"]])
  if (!is.null(values[["x_label"]]))
    updateTextInput(session,   "x_label",       value    = values[["x_label"]])
  if (!is.null(values[["y_label"]]))
    updateTextInput(session,   "y_label",       value    = values[["y_label"]])
  if (!is.null(values[["color_palette"]]))
    updateSelectInput(session, "color_palette", selected = values[["color_palette"]])
  if (!is.null(values[["chart_theme"]]))
    updateSelectInput(session, "chart_theme",   selected = values[["chart_theme"]])
  if (!is.null(values[["plot_width_in"]]))
    updateNumericInput(session, "plot_width_in", value = values[["plot_width_in"]])
  if (!is.null(values[["plot_height_in"]]))
    updateNumericInput(session, "plot_height_in", value = values[["plot_height_in"]])
  if (!is.null(values[["plot_dpi"]]))
    updateNumericInput(session, "plot_dpi", value = values[["plot_dpi"]])
  if (!is.null(values[["x_range_mode"]]))
    updateSelectInput(session, "x_range_mode", selected = values[["x_range_mode"]])
  if (!is.null(values[["x_min"]]))
    updateNumericInput(session, "x_min", value = values[["x_min"]])
  if (!is.null(values[["x_max"]]))
    updateNumericInput(session, "x_max", value = values[["x_max"]])
  if (!is.null(values[["y_range_mode"]]))
    updateSelectInput(session, "y_range_mode", selected = values[["y_range_mode"]])
  if (!is.null(values[["y_min"]]))
    updateNumericInput(session, "y_min", value = values[["y_min"]])
  if (!is.null(values[["y_max"]]))
    updateNumericInput(session, "y_max", value = values[["y_max"]])

  # ── Chart-specific opt_* inputs ──────────────────────────────────────────────
  defs <- chart$options_def
  if (is.null(defs)) return(invisible(NULL))

  for (d in defs) {
    val <- values[[d$id]]
    if (is.null(val)) next
    input_id <- paste0("opt_", d$id)
    switch(d$type,
      slider   = updateSliderInput(  session, input_id, value    = val),
      checkbox = updateCheckboxInput(session, input_id, value    = isTRUE(val)),
      select   = updateSelectInput(  session, input_id, selected = as.character(val)),
      color    = colourpicker::updateColourInput(session, input_id, value = val),
      numeric  = updateNumericInput( session, input_id, value    = val),
      text     = updateTextInput(    session, input_id, value    = as.character(val))
    )
  }
  invisible(NULL)
}
