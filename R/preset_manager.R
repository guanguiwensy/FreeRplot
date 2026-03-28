# =============================================================================
# File   : R/preset_manager.R
# Purpose: Settings recipe persistence and legacy preset compatibility.
#          New recipe files are stored under `presets/recipes/` as one JSON file
#          per recipe.  Older per-chart preset JSON files under `presets/`
#          remain readable so users can continue loading or re-saving them.
#
# Exports:
#   list_recipe_records(include_legacy = FALSE)
#     Returns metadata records for saved recipes, optionally including legacy
#     preset entries converted to recipe-like records.
#
#   load_recipe(name, include_legacy = TRUE)
#     Loads one recipe by display name.  Falls back to legacy preset files when
#     requested.
#
#   save_recipe(name, recipe)
#     Saves or overwrites one recipe by display name.
#
#   delete_recipe(name)
#     Deletes a saved recipe by display name.  Legacy preset entries are
#     read-only and are not deleted by this function.
#
#   restore_recipe_inputs(recipe, chart, session)
#     Pushes one recipe's saved values back into Shiny inputs.
#
# Compatibility:
#   load_presets(chart_id)
#   list_preset_names(chart_id)
#   save_preset(chart_id, name, values)
#   delete_preset(chart_id, name)
#   restore_preset_inputs(chart, values, session)
# =============================================================================

.app_root_dir <- function() {
  if (exists("APP_DIR", envir = .GlobalEnv, inherits = FALSE)) {
    get("APP_DIR", envir = .GlobalEnv, inherits = FALSE)
  } else {
    getwd()
  }
}

.legacy_settings_dir <- function() {
  root <- .app_root_dir()
  d <- file.path(root, "presets")
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

.recipe_storage_root <- function() {
  preferred <- .legacy_settings_dir()
  if (dir.exists(preferred) && file.access(preferred, 2) == 0) {
    return(preferred)
  }

  fallback <- file.path(.app_root_dir(), "recipes")
  if (!dir.exists(fallback)) dir.create(fallback, recursive = TRUE, showWarnings = FALSE)
  fallback
}

.recipe_dir <- function() {
  root <- .recipe_storage_root()
  d <- if (basename(root) == "presets") file.path(root, "recipes") else root
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

.legacy_preset_file <- function(chart_id) {
  file.path(.legacy_settings_dir(), paste0(chart_id, ".json"))
}

.recipe_slug <- function(name) {
  slug <- tolower(trimws(enc2utf8(name %||% "")))
  slug <- gsub("\\s+", "-", slug)
  slug <- gsub("[^[:alnum:]-]+", "-", slug)
  slug <- gsub("-{2,}", "-", slug)
  slug <- gsub("^-|-$", "", slug)
  if (!nzchar(slug)) slug <- "recipe"
  slug
}

.recipe_file <- function(name) {
  file.path(.recipe_dir(), paste0(.recipe_slug(name), ".json"))
}

.read_json_safe <- function(path) {
  if (!file.exists(path)) return(NULL)
  tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) NULL
  )
}

.recipe_common_keys <- function() {
  c(
    "plot_title", "x_label", "y_label",
    "color_palette", "chart_theme",
    "plot_width_in", "plot_height_in", "plot_dpi",
    "x_range_mode", "x_min", "x_max",
    "y_range_mode", "y_min", "y_max"
  )
}

.split_legacy_values <- function(values) {
  common_keys <- .recipe_common_keys()
  list(
    global_settings = values[intersect(common_keys, names(values))],
    chart_options = values[setdiff(names(values), common_keys)]
  )
}

.normalize_overrides <- function(overrides) {
  if (is.null(overrides)) return(list())
  if (is.list(overrides) && length(overrides) == 0) return(list())
  if (is.atomic(overrides) && !is.null(names(overrides))) return(as.list(overrides))
  if (is.list(overrides)) return(overrides)
  list()
}

.normalize_recipe <- function(recipe, fallback_name = NULL, source = "recipe", file_path = NULL) {
  recipe <- recipe %||% list()

  if (!is.null(recipe$global_settings) || !is.null(recipe$chart_options)) {
    global_settings <- recipe$global_settings %||% list()
    chart_options <- recipe$chart_options %||% list()
  } else {
    split <- .split_legacy_values(recipe)
    global_settings <- split$global_settings
    chart_options <- split$chart_options
  }

  base_palette <- recipe$color_settings$base_palette %||%
    global_settings$color_palette %||%
    names(COLOR_PALETTES)[1]

  list(
    version = as.integer(recipe$version %||% 1L),
    name = fallback_name %||% recipe$name %||% "",
    chart_id = as.character(recipe$chart_id %||% "")[1],
    global_settings = global_settings,
    chart_options = chart_options,
    color_settings = list(
      base_palette = base_palette,
      target_column = recipe$color_settings$target_column %||% NULL,
      overrides = .normalize_overrides(recipe$color_settings$overrides)
    ),
    source = source,
    file_path = file_path
  )
}

.list_current_recipe_files <- function() {
  list.files(.recipe_dir(), pattern = "\\.json$", full.names = TRUE, recursive = FALSE)
}

.load_current_recipe_records <- function() {
  files <- .list_current_recipe_files()
  if (length(files) == 0) return(list())

  records <- lapply(files, function(path) {
    raw <- .read_json_safe(path)
    if (is.null(raw)) return(NULL)
    .normalize_recipe(raw, fallback_name = raw$name %||% tools::file_path_sans_ext(basename(path)),
                      source = "recipe", file_path = path)
  })

  Filter(Negate(is.null), records)
}

.load_legacy_recipe_records <- function() {
  files <- list.files(.legacy_settings_dir(), pattern = "\\.json$", full.names = TRUE, recursive = FALSE)
  if (length(files) == 0) return(list())

  records <- list()

  for (path in files) {
    chart_id <- tools::file_path_sans_ext(basename(path))
    payload <- .read_json_safe(path)
    if (!is.list(payload) || length(payload) == 0) next

    for (nm in names(payload)) {
      values <- payload[[nm]]
      if (!is.list(values)) next

      records[[length(records) + 1L]] <- .normalize_recipe(
        c(list(chart_id = chart_id), values),
        fallback_name = nm,
        source = "legacy",
        file_path = path
      )
    }
  }

  records
}

list_recipe_records <- function(include_legacy = FALSE) {
  records <- .load_current_recipe_records()
  if (isTRUE(include_legacy)) {
    records <- c(records, .load_legacy_recipe_records())
  }

  if (length(records) == 0) return(list())

  records[order(vapply(records, function(x) paste0(x$name, "\r", x$chart_id), character(1)))]
}

.find_recipe_record <- function(name, include_legacy = TRUE) {
  name <- trimws(name %||% "")
  if (!nzchar(name)) return(NULL)

  records <- list_recipe_records(include_legacy = include_legacy)
  if (length(records) == 0) return(NULL)

  idx <- which(vapply(records, function(x) identical(x$name, name), logical(1)))[1]
  if (is.na(idx)) return(NULL)
  records[[idx]]
}

load_recipe <- function(name, include_legacy = TRUE) {
  record <- .find_recipe_record(name, include_legacy = include_legacy)
  if (is.null(record)) return(NULL)

  if (identical(record$source, "recipe")) {
    raw <- .read_json_safe(record$file_path)
    return(.normalize_recipe(raw, fallback_name = record$name, source = "recipe", file_path = record$file_path))
  }

  record
}

save_recipe <- function(name, recipe) {
  name <- trimws(name %||% "")
  if (!nzchar(name)) return(invisible(FALSE))

  recipe <- .normalize_recipe(recipe, fallback_name = name, source = "recipe")
  recipe$file_path <- NULL
  recipe$source <- NULL

  existing <- .find_recipe_record(name, include_legacy = FALSE)
  path <- existing$file_path %||% .recipe_file(name)

  jsonlite::write_json(recipe, path, auto_unbox = TRUE, pretty = TRUE)
  invisible(TRUE)
}

delete_recipe <- function(name) {
  record <- .find_recipe_record(name, include_legacy = FALSE)
  if (is.null(record) || !file.exists(record$file_path)) return(invisible(FALSE))
  unlink(record$file_path)
  invisible(TRUE)
}

restore_recipe_inputs <- function(recipe, chart, session) {
  recipe <- .normalize_recipe(recipe, fallback_name = recipe$name %||% "")
  values <- recipe$global_settings %||% list()

  if (!is.null(values[["plot_title"]]))
    updateTextInput(session, "plot_title", value = values[["plot_title"]])
  if (!is.null(values[["x_label"]]))
    updateTextInput(session, "x_label", value = values[["x_label"]])
  if (!is.null(values[["y_label"]]))
    updateTextInput(session, "y_label", value = values[["y_label"]])

  base_palette <- recipe$color_settings$base_palette %||% values[["color_palette"]]
  if (!is.null(base_palette))
    updateSelectInput(session, "color_palette", selected = base_palette)

  if (!is.null(values[["chart_theme"]]))
    updateSelectInput(session, "chart_theme", selected = values[["chart_theme"]])
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

  defs <- chart$options_def %||% list()
  for (d in defs) {
    if (identical(d$id, "color_palette")) next
    val <- recipe$chart_options[[d$id]]
    if (is.null(val)) next
    input_id <- paste0("opt_", d$id)

    switch(
      d$type,
      slider = updateSliderInput(session, input_id, value = val),
      checkbox = updateCheckboxInput(session, input_id, value = isTRUE(val)),
      select = updateSelectInput(session, input_id, selected = as.character(val)),
      color = colourpicker::updateColourInput(session, input_id, value = val),
      numeric = updateNumericInput(session, input_id, value = val),
      text = updateTextInput(session, input_id, value = as.character(val))
    )
  }

  invisible(NULL)
}

# -----------------------------------------------------------------------------
# Legacy compatibility helpers
# -----------------------------------------------------------------------------

load_presets <- function(chart_id) {
  f <- .legacy_preset_file(chart_id)
  payload <- .read_json_safe(f)
  if (!is.list(payload)) return(list())
  payload
}

list_preset_names <- function(chart_id) {
  names(load_presets(chart_id))
}

save_preset <- function(chart_id, name, values) {
  name <- trimws(name)
  if (!nzchar(name)) return(invisible(FALSE))

  presets <- load_presets(chart_id)
  presets[[name]] <- values
  jsonlite::write_json(presets, .legacy_preset_file(chart_id), auto_unbox = TRUE, pretty = TRUE)
  invisible(TRUE)
}

delete_preset <- function(chart_id, name) {
  presets <- load_presets(chart_id)
  presets[[name]] <- NULL

  target <- .legacy_preset_file(chart_id)
  if (length(presets) == 0) {
    if (file.exists(target)) unlink(target)
  } else {
    jsonlite::write_json(presets, target, auto_unbox = TRUE, pretty = TRUE)
  }

  invisible(TRUE)
}

restore_preset_inputs <- function(chart, values, session) {
  chart_id <- chart$id %||% ""
  recipe <- .normalize_recipe(
    c(list(chart_id = chart_id), values),
    fallback_name = "",
    source = "legacy"
  )
  restore_recipe_inputs(recipe, chart, session)
}
