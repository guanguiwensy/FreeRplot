# =============================================================================
# File   : server.R
# Purpose: Application server entry point.  Initialises shared reactive state
#          (rv) and wires the four server modules.  All business logic lives
#          inside the init_mod_*() functions in R/modules/.
#
# Module wiring (load order matters — settings first so show_when is ready):
#   init_mod_settings  — show_when visibility, presets, API config modal
#   init_mod_ai_chat   — intent engine, LLM chat, suggestion card
#   init_mod_data      — sample loading, CSV upload, paste import, grid
#   init_mod_plot      — generate_btn, render, download, gallery, R code
#
# Shared reactive state (rv):
#   messages        [list]  OpenAI-format message history (includes system prompt)
#   current_data    [df]    active dataset (updated by mod_data, mod_ai_chat)
#   suggestion      [list]  most recent AI chart recommendation (or NULL)
#   current_plot    [ggplot|circos|NULL]  rendered plot object
#   api_config      [list]  {provider, api_key, model, custom_url}
#   pending_intent  [list|NULL]  medium-confidence intent awaiting confirmation
#   patch_history   [list]  undo stack — snapshots of input state (max 10)
# =============================================================================

server <- function(input, output, session) {

  rv <- reactiveValues(
    messages        = list(list(role = "system", content = build_system_prompt())),
    current_data    = CHARTS[["scatter_basic"]]$sample_data,
    suggestion      = NULL,
    current_plot    = NULL,
    api_config      = load_api_config(),   # read from ~/.r-plot-ai/api_config.json
    pending_intent  = NULL,
    patch_history   = list()
  )

  init_mod_settings(input, output, session, rv)
  init_mod_ai_chat (input, output, session, rv)
  init_mod_data    (input, output, session, rv)
  init_mod_plot    (input, output, session, rv)
}
