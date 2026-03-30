# =============================================================================
# File   : global.R
# Purpose: App bootstrap. Defines APP_DIR, loads packages, sources all modules,
#          and provides global utility helpers.
# =============================================================================

# Stable app root
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

# Packages
suppressPackageStartupMessages({
  library(shiny)
  library(bslib)

  library(ggplot2)
  library(dplyr)
  library(tidyr)

  library(ggridges)
  library(treemapify)
  library(ggDNAvis)
  library(circlize)

  library(shinyjs)
  library(rhandsontable)
  library(shinycssloaders)
  library(colourpicker)
  library(shinyAce)

  library(httr2)
  library(jsonlite)
})

# Core utilities
source("R/utils/logger.R")

# Config and API
source("R/config_manager.R")

# UI helpers first (needed by chart registry)
source("R/ui_helpers.R")
source("R/core/ai_rule_config.R")

# Intent engine
source("R/core/intent_engine.R")

# Chart registry (depends on CHART_MENU_GROUPS)
source("R/chart_registry.R")
sample_files_written <- ensure_chart_sample_files(overwrite = FALSE)
log_info("global", "Sample CSV files ready under data/samples (new files: %d)", sample_files_written)
source("R/core/chart_capability_registry.R")
CHART_CAP_REG <- load_chart_capability_registry(charts = CHARTS, refresh = FALSE)
log_info("global", "Chart capability registry ready: %s", chart_capability_registry_path())
source("R/core/chart_recommender.R")

# Plot core
source("R/plot_core.R")

# Code engines/helpers
source("R/core/code_engine.R")
source("R/core/ai_patch_apply.R")
source("R/core/ai_local_patch_parser.R")
source("R/core/ai_chat_flow.R")
source("R/core/ai_chat_helpers.R")
source("R/core/ai_chat_handlers.R")
source("R/core/module_shared.R")

# Scene presets
source("R/bar_scene_presets.R")
source("R/scatter_scene_presets.R")

BAR_FAMILY_IDS <- unname(unlist(
  CHART_MENU_GROUPS[[which(vapply(
    CHART_MENU_GROUPS,
    function(ids) "bar" %in% ids,
    logical(1)
  ))[1]]]
))
SCATTER_FAMILY_IDS <- unname(unlist(
  CHART_MENU_GROUPS[[which(vapply(
    CHART_MENU_GROUPS,
    function(ids) "scatter_basic" %in% ids,
    logical(1)
  ))[1]]]
))

# LLM client and preset manager
source("R/kimi_api.R")
source("R/preset_manager.R")

# UI panel constructors
source("R/ui/panel_chat.R")
source("R/ui/panel_recommend.R")
source("R/ui/chat_renderers.R")
source("R/ui/panel_overlay_toolbar.R")
source("R/ui/panel_overlay_settings.R")
source("R/ui/panel_plot.R")
source("R/ui/panel_data.R")
source("R/ui/panel_settings.R")
source("R/ui/panel_code.R")
source("R/ui/panel_gallery.R")

# Server modules
source("R/modules/mod_settings.R")
source("R/modules/mod_ai_chat.R")
source("R/modules/mod_data.R")
source("R/modules/mod_code.R")
source("R/modules/mod_plot.R")
source("R/modules/mod_overlay.R")

# Null-coalescing helper
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) return(y)
  if (is.list(x)) return(x)
  if (is.na(x[1]) || nchar(as.character(x[1])) == 0) y else x
}

# Remove fenced JSON blocks from LLM responses for display
strip_json_block <- function(text) {
  trimws(gsub("```json[\\s\\S]*?```", "", text, perl = TRUE))
}

log_info("global", "App bootstrapped. %d charts loaded. APP_DIR=%s", length(CHARTS), APP_DIR)
