# global.R — loaded once before app starts
# APP_DIR is pinned here so all modules use a stable root regardless of CWD.
APP_DIR <- normalizePath(
  if (nzchar(Sys.getenv("SHINY_APP_DIR"))) {
    Sys.getenv("SHINY_APP_DIR")
  } else if (file.exists("global.R")) {
    getwd()
  } else {
    tryCatch(dirname(sys.frame(1)$ofile), error = function(e) getwd())
  },
  mustWork = FALSE
)

# ── Packages ─────────────────────────────────────────────────────────────────
suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(ggplot2)
  library(httr2)
  library(jsonlite)
  library(dplyr)
  library(tidyr)
  library(rhandsontable)
  library(shinycssloaders)
  library(ggridges)
  library(treemapify)
  library(ggDNAvis)
  library(circlize)
  library(colourpicker)
  library(shinyjs)
})

# ── Source modules ────────────────────────────────────────────────────────────
source("R/config_manager.R")      # LLM_PROVIDERS, load_api_config(), save_api_config(), get_api_url()
source("R/ui_helpers.R")          # build_controls(), collect_options(), get_default_options()
source("R/core/intent_engine.R") # parse_intent(), snapshot_inputs(), push_history(), restore_last()
source("R/chart_registry.R")      # CHARTS list (plot_fn stored as closures, order-safe)
source("R/plot_core.R")           # palettes/themes + generate_plot() dispatcher helpers
source("R/bar_scene_presets.R")   # BAR_SCENE_PRESETS (BAR_FAMILY_IDS filled below)
source("R/scatter_scene_presets.R") # SCATTER_SCENE_PRESETS (SCATTER_FAMILY_IDS filled below)
# Resolve BAR_FAMILY_IDS after ui_helpers.R has defined CHART_MENU_GROUPS
BAR_FAMILY_IDS <- unname(unlist(
  CHART_MENU_GROUPS[[grep("\u67f1\u56fe", names(CHART_MENU_GROUPS), value = TRUE)[1]]]
))
SCATTER_FAMILY_IDS <- unname(unlist(
  CHART_MENU_GROUPS[[grep("\u6563\u70b9\u56fe", names(CHART_MENU_GROUPS), value = TRUE)[1]]]
))
source("R/kimi_api.R")            # chat_with_kimi(), parse_chart_suggestion()
source("R/preset_manager.R")      # save_preset(), load_presets(), delete_preset(), restore_preset_inputs()

# ── Global helpers ────────────────────────────────────────────────────────────

# Null-coalescing: use x if non-null/non-empty, else y. Safe for lists & vectors.
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) return(y)
  if (is.list(x)) return(x)                          # non-null list → always x
  if (is.na(x[1]) || nchar(as.character(x[1])) == 0) y else x
}

# Strip the JSON block from AI text for display
strip_json_block <- function(text) {
  trimws(gsub("```json[\\s\\S]*?```", "", text, perl = TRUE))
}
