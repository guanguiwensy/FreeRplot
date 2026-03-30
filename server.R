# =============================================================================
# File   : server.R
# Purpose: Application server entry point.  Initialises shared reactive state
#          (rv) and wires the server modules.  All business logic lives
#          inside the init_mod_*() functions in R/modules/.
#
# Module wiring (load order matters — settings first so show_when is ready):
#   init_mod_settings  — show_when visibility, presets, API config modal
#   init_mod_ai_chat   — intent engine, LLM chat, suggestion card
#   init_mod_data      — sample loading, file import, paste import, grid
#   init_mod_code      — code editor execution, run status, code export
#   init_mod_plot      — render, download, gallery
#   init_mod_overlay   — overlay sync and combined SVG/PDF export
#
# Shared reactive state (rv):
#   messages        [list]  OpenAI-format message history (includes system prompt)
#   current_data    [df]    active dataset (updated by mod_data, mod_ai_chat)
#   current_data_source [chr]  current data origin: sample | upload | paste | user_edit
#   suggestion      [list]  most recent AI chart recommendation (or NULL)
#   current_plot    [ggplot|circos|NULL]  rendered plot object
#   current_plot_code [chr|NULL]  last successful 1:1 synchronized R script
#   api_config      [list]  {provider, api_key, model, custom_url}
#   pending_intent  [list|NULL]  medium-confidence intent awaiting confirmation
#   patch_history   [list]  undo stack — snapshots of input state (max 10)
# =============================================================================

server <- function(input, output, session) {

  rv <- reactiveValues(
    messages        = list(list(role = "system", content = build_system_prompt())),
    current_data    = CHARTS[["scatter_basic"]]$sample_data,
    current_data_source = "sample",
    current_data_file = file.path(APP_DIR, "data", "samples", "scatter_basic.csv"),
    preserve_data_on_chart_change = FALSE,
    suggestion      = NULL,
    current_plot    = NULL,
    current_plot_code = NULL,
    overlay_scene_json = "[]",
    overlay_shared_points = list(),
    last_run_error    = NULL,      # last code eval error message (NULL = none)
    api_config      = load_api_config(),   # read from ~/.r-plot-ai/api_config.json
    pending_intent  = NULL,
    patch_history   = list(),
    chart_recommendations = list(),
    chart_recommend_profile = NULL
  )

  init_mod_settings(input, output, session, rv)
  init_mod_ai_chat (input, output, session, rv)
  init_mod_data    (input, output, session, rv)
  init_mod_code    (input, output, session, rv)
  init_mod_plot    (input, output, session, rv)
  init_mod_overlay (input, output, session, rv)
}
