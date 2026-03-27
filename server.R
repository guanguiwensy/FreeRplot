# server.R
# Compose the app server from split modules.

source("R/modules/mod_settings.R")
source("R/modules/mod_ai_chat.R")
source("R/modules/mod_data.R")
source("R/modules/mod_plot.R")

server <- function(input, output, session) {

  rv <- reactiveValues(
    messages        = list(list(role = "system", content = build_system_prompt())),
    current_data    = CHARTS[["scatter_basic"]]$sample_data,
    suggestion      = NULL,
    current_plot    = NULL,
    # Intent engine state
    pending_intent  = NULL,   # medium-confidence intent awaiting user confirmation
    patch_history   = list()  # stack of input snapshots for undo (max 10)
  )

  init_mod_settings(input, output, session, rv)
  init_mod_ai_chat(input, output, session, rv)
  init_mod_data(input, output, session, rv)
  init_mod_plot(input, output, session, rv)
}
