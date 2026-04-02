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
#   messages                     [list]   OpenAI-format message history
#   current_data                 [df|NULL] active dataset
#   current_data_source          [chr]    "none"|"sample"|"upload"|"paste"|"user_edit"
#   current_data_file            [chr|NULL] path to temp CSV for current data
#   preserve_data_on_chart_change [lgl]   if TRUE, next chart_type_select event
#                                          skips sample-swap (consumed once)
#   suggestion                   [list|NULL] most recent AI chart recommendation
#   current_plot                 [ggplot|circos|NULL] rendered plot object
#   current_plot_code            [chr|NULL] last successful R script
#   overlay_scene_json           [chr]    JSON of overlay annotation objects
#   overlay_shared_points        [list]   data points synced to overlay layer
#   last_run_error               [chr|NULL] last code-editor eval error message
#   api_config                   [list]   {provider, api_key, model, custom_url}
#   pending_intent               [list|NULL] medium-confidence intent awaiting confirm
#   patch_history                [list]   undo stack — input snapshots (max 10)
#   chart_recommendations        [list]   top-N recommendation objects (set by
#                                          ai_chat_handlers run_recommendations)
#   chart_recommend_profile      [list|NULL] data profile from recommender
#   chart_recommend_previews     [list]   chart_id → base64 PNG preview string
# =============================================================================

server <- function(input, output, session) {

  rv <- reactiveValues(
    messages        = list(list(role = "system", content = build_system_prompt())),
    current_data    = NULL,
    current_data_source = "none",
    current_data_file = NULL,
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
    chart_recommend_profile = NULL,
    chart_recommend_previews = list()
  )

  init_mod_settings(input, output, session, rv)
  init_mod_ai_chat (input, output, session, rv)
  init_mod_data    (input, output, session, rv)
  init_mod_code    (input, output, session, rv)
  init_mod_plot    (input, output, session, rv)
  init_mod_overlay (input, output, session, rv)
}
