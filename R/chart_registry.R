# =============================================================================
# File   : R/chart_registry.R
# Purpose: Auto-discovers and registers all chart definition files found under
#          R/charts/**/*.R.  Each file must assign a `chart_def` list with the
#          required fields; this loader validates and indexes them into CHARTS.
#
# Globals exported:
#   CHARTS    named list — chart_id → chart_def object.
#             Available after source("R/chart_registry.R") in global.R.
#   CHART_IDS chr vector — names(CHARTS) in menu order.
#
# Required fields in each chart_def:
#   id            [chr]  unique snake_case identifier (must match filename key)
#   name          [chr]  display name (Chinese)
#   name_en       [chr]  display name (English)
#   category      [chr]  group label
#   plot_fn       [function(data, options)]  draws and returns a ggplot/circos object
#   sample_data   [data.frame]              default demo data
#   options_def   [list]  option descriptor objects (see ui_helpers.R)
#   code_template [function(options) | function(options, data)]  generates R code string
#
# Internal functions:
#   .load_charts_from_files(charts_dir)
#     Recursively sources *.R files in charts_dir, collects chart_def objects.
#     Parameters: charts_dir [chr] path relative to APP_DIR.
#     Returns: named list of validated chart_def objects.
# =============================================================================

.load_charts_from_files <- function(charts_dir = file.path("R", "charts")) {
  files <- list.files(
    path = charts_dir,
    pattern = "\\.R$",
    full.names = TRUE,
    recursive = TRUE
  )

  if (length(files) == 0) {
    stop("No chart definition files found under: ", charts_dir)
  }

  charts <- list()

  for (f in sort(files)) {
    env <- new.env(parent = globalenv())
    sys.source(f, envir = env, keep.source = FALSE)

    if (!exists("chart_def", envir = env, inherits = FALSE)) {
      stop("Chart file missing `chart_def`: ", f)
    }

    def <- get("chart_def", envir = env, inherits = FALSE)
    if (!is.list(def)) {
      stop("`chart_def` must be a list in file: ", f)
    }

    id <- as.character(def$id)
    if (!nzchar(id)) {
      stop("Chart definition has empty `id` in file: ", f)
    }

    if (!is.null(charts[[id]])) {
      stop("Duplicate chart id detected: ", id, " (file: ", f, ")")
    }

    charts[[id]] <- def
  }

  charts
}

.order_charts_by_menu <- function(charts, menu_groups = CHART_MENU_GROUPS) {
  menu_ids <- unique(unname(unlist(menu_groups, use.names = FALSE)))
  ordered <- menu_ids[menu_ids %in% names(charts)]
  extra <- setdiff(names(charts), ordered)
  charts[c(ordered, extra)]
}

CHARTS <- .order_charts_by_menu(.load_charts_from_files())
CHART_IDS <- names(CHARTS)

ensure_chart_sample_files <- function(charts = CHARTS,
                                      out_dir = file.path(APP_DIR, "data", "samples"),
                                      overwrite = FALSE) {
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  }

  written <- 0L

  for (id in names(charts)) {
    chart <- charts[[id]]
    sample_df <- chart$sample_data
    if (!is.data.frame(sample_df) || nrow(sample_df) == 0 || ncol(sample_df) == 0) next

    target <- file.path(out_dir, paste0(id, ".csv"))
    if (!isTRUE(overwrite) && file.exists(target)) next

    utils::write.csv(sample_df, target, row.names = FALSE, fileEncoding = "UTF-8")
    written <- written + 1L
  }

  written
}

build_system_prompt <- function() {
  chart_lines <- paste(vapply(CHARTS, function(c) {
    sprintf(
      "  - %s (%s, id=\"%s\"): %s. Best for: %s. Required columns: %s",
      c$name,
      c$name_en,
      c$id,
      c$description,
      c$best_for,
      c$columns
    )
  }, character(1)), collapse = "\n")

  paste0(
    "You are an expert data-visualization assistant for this Shiny app.\n",
    "You must recommend charts only from this catalog:\n",
    chart_lines, "\n\n",
    "Output rules:\n",
    "1) First write a short explanation (2-5 sentences).\n",
    "2) Then output ONE JSON code block with this schema:\n",
    "```json\n",
    "{\n",
    "  \"primary\": \"chart_id\",\n",
    "  \"recommendations\": [\n",
    "    {\n",
    "      \"chart_id\": \"chart_id\",\n",
    "      \"confidence\": \"high|medium|low\",\n",
    "      \"reason\": \"why this chart\",\n",
    "      \"column_mapping\": {\n",
    "        \"x\": \"column_name_or_null\",\n",
    "        \"y\": \"column_name_or_null\",\n",
    "        \"group\": \"column_name_or_null\",\n",
    "        \"size\": \"column_name_or_null\",\n",
    "        \"label\": \"column_name_or_null\"\n",
    "      },\n",
    "      \"options_patch\": {\n",
    "        \"show_smooth\": true,\n",
    "        \"alpha\": 0.7\n",
    "      },\n",
    "      \"warnings\": [\"optional warning\"]\n",
    "    }\n",
    "  ]\n",
    "}\n",
    "```\n",
    "3) Return up to 3 recommendations ordered by suitability.\n",
    "4) chart_id must be from the catalog."
  )
}
