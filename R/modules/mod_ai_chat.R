# =============================================================================
# File   : R/modules/mod_ai_chat.R
# Purpose: AI chat server module - handles user messages, routes through the
#          intent engine (local then LLM), manages the suggestion card,
#          renders chat bubbles, and owns the undo stack interaction.
#          All AI API calls go through chat_with_llm() in R/kimi_api.R.
#
# Depends: R/core/intent_engine.R  (parse_intent, snapshot_inputs, push_history,
#                                    restore_last, format_intent_summary)
#          R/kimi_api.R             (chat_with_llm)
#          R/utils/logger.R         (log_debug, log_info, log_error, safe_run)
#
# Exported functions:
#   init_mod_ai_chat(input, output, session, rv)
#     Registers all observers and output renderers for the chat panel.
#     Parameters:
#       input   [Shiny input]          reactive input bindings
#       output  [Shiny output]         output binding list
#       session [Shiny session]        current session object
#       rv      [reactiveValues]       shared app state (messages, suggestion,
#                                      pending_intent, patch_history, api_config)
#
# Delegates:
#   build_ai_chat_helpers()        in R/core/ai_chat_helpers.R
#   register_ai_chat_handlers()    in R/core/ai_chat_handlers.R
#   register_ai_chat_renderers()   in R/ui/chat_renderers.R
# =============================================================================

MODULE <- "mod_ai_chat"

init_mod_ai_chat <- function(input, output, session, rv) {
  helpers <- build_ai_chat_helpers(input, session, rv, module_name = MODULE)

  register_ai_chat_handlers(
    input = input,
    output = output,
    session = session,
    rv = rv,
    helpers = helpers,
    module_name = MODULE
  )

  register_ai_chat_renderers(
    input = input,
    output = output,
    session = session,
    rv = rv
  )

  invisible(NULL)
}
