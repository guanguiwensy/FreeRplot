# =============================================================================
# File   : global.R
# Purpose: Application bootstrap — loaded once before the Shiny server starts.
#          Pins APP_DIR, loads all packages, sources every module in dependency
#          order, and defines the two global utility helpers (%||%, strip_json_block).
#
# Load order (must not be changed):
#   1. R/utils/logger.R          — log_* helpers used everywhere below
#   2. R/config_manager.R        — LLM_PROVIDERS, load/save_api_config
#   3. R/ui_helpers.R            — CHART_MENU_GROUPS, build_* helpers
#   4. R/core/intent_engine.R    — parse_intent, snapshot/push/restore history
#   5. R/chart_registry.R        — CHARTS, CHART_IDS  (depends on ui_helpers)
#   6. R/plot_core.R             — COLOR_PALETTES, CHART_THEMES, generate_plot
#   7. R/bar_scene_presets.R     — BAR_SCENE_PRESETS
#   8. R/scatter_scene_presets.R — SCATTER_SCENE_PRESETS
#   9. R/kimi_api.R              — chat_with_llm, parse_chart_suggestion
#  10. R/preset_manager.R        — save/load/delete presets
#  11. R/ui/*.R                  — panel UI constructor functions (used by ui.R)
#  12. R/modules/*.R             — server module init functions (used by server.R)
#
# Packages:
#   CORE (always global)  : shiny, bslib, ggplot2, dplyr, tidyr
#   CHART EXTENSIONS      : ggridges, treemapify, ggDNAvis, circlize
#   UI / INTERACTION      : shinyjs, rhandsontable, shinycssloaders, colourpicker
#   NETWORKING / PARSING  : httr2, jsonlite
# =============================================================================

# ── Stable app root (path-independent) ────────────────────────────────────────
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

# ── Packages ───────────────────────────────────────────────────────────────────
suppressPackageStartupMessages({
  # Core Shiny framework
  library(shiny)
  library(bslib)

  # Data wrangling (used by chart plot_fn implementations)
  library(ggplot2)
  library(dplyr)
  library(tidyr)

  # Chart extension packages
  library(ggridges)        # ridgeline / joy plots
  library(treemapify)      # treemap geom
  library(ggDNAvis)        # DNA sequence visualisation
  library(circlize)        # circular / chord diagrams

  # UI and interaction packages
  library(shinyjs)         # useShinyjs(), hidden(), delay(), click()
  library(rhandsontable)   # editable data grid
  library(shinycssloaders) # withSpinner()
  library(colourpicker)    # colour picker input + updateColourInput()

  # Networking / JSON (used by API client and config manager)
  library(httr2)
  library(jsonlite)
})

# ── Core utilities ─────────────────────────────────────────────────────────────
source("R/utils/logger.R")           # log_debug/info/warn/error, safe_run

# ── Configuration & API ────────────────────────────────────────────────────────
source("R/config_manager.R")         # LLM_PROVIDERS, load_api_config, save_api_config, get_api_url

# ── UI helpers (must come before chart_registry loads CHART_MENU_GROUPS) ───────
source("R/ui_helpers.R")             # CHART_MENU_GROUPS, build_grouped_choices, build_controls, ...

# ── Intent engine ─────────────────────────────────────────────────────────────
source("R/core/intent_engine.R")     # parse_intent, snapshot_inputs, push_history, restore_last

# ── Chart registry (depends on CHART_MENU_GROUPS from ui_helpers.R) ───────────
source("R/chart_registry.R")         # CHARTS, CHART_IDS

# ── Plotting core ──────────────────────────────────────────────────────────────
source("R/plot_core.R")              # COLOR_PALETTES, CHART_THEMES, generate_plot

# ── Scene presets (resolve family IDs after CHART_MENU_GROUPS is available) ───
source("R/bar_scene_presets.R")      # BAR_SCENE_PRESETS
source("R/scatter_scene_presets.R")  # SCATTER_SCENE_PRESETS

BAR_FAMILY_IDS <- unname(unlist(
  CHART_MENU_GROUPS[[grep("\u67f1\u56fe", names(CHART_MENU_GROUPS), value = TRUE)[1]]]
))
SCATTER_FAMILY_IDS <- unname(unlist(
  CHART_MENU_GROUPS[[grep("\u6563\u70b9\u56fe", names(CHART_MENU_GROUPS), value = TRUE)[1]]]
))

# ── LLM API client & preset manager ───────────────────────────────────────────
source("R/kimi_api.R")               # chat_with_llm, chat_with_kimi, parse_chart_suggestion
source("R/preset_manager.R")         # save_preset, load_presets, delete_preset, restore_preset_inputs

# ── UI panel constructors (loaded before ui.R is evaluated) ───────────────────
source("R/ui/panel_chat.R")          # chat_panel_ui()
source("R/ui/panel_plot.R")          # plot_preview_card_ui()
source("R/ui/panel_data.R")          # tab_data_ui()
source("R/ui/panel_settings.R")      # tab_settings_ui()
source("R/ui/panel_code.R")          # tab_code_ui()
source("R/ui/panel_gallery.R")       # tab_gallery_ui()

# ── Server modules (loaded before server.R is evaluated) ──────────────────────
source("R/modules/mod_settings.R")   # init_mod_settings()
source("R/modules/mod_ai_chat.R")    # init_mod_ai_chat()
source("R/modules/mod_data.R")       # init_mod_data()
source("R/modules/mod_plot.R")       # init_mod_plot()

# ── Global utility helpers ─────────────────────────────────────────────────────

# Null-coalescing operator: returns x if non-null/non-empty, else y.
# Safe for lists (non-null list always wins), vectors, and scalars.
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) return(y)
  if (is.list(x)) return(x)
  if (is.na(x[1]) || nchar(as.character(x[1])) == 0) y else x
}

# Remove ```json ... ``` fenced blocks from LLM response text for display.
strip_json_block <- function(text) {
  trimws(gsub("```json[\\s\\S]*?```", "", text, perl = TRUE))
}

log_info("global", "App bootstrapped. %d charts loaded. APP_DIR=%s", length(CHARTS), APP_DIR)
