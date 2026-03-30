# =============================================================================
# File   : R/core/ai_chat_renderers.R
# Purpose: Backward-compat shim. Canonical renderer implementation moved to
#          R/ui/chat_renderers.R.
# =============================================================================

if (!exists("register_ai_chat_renderers", mode = "function")) {
  source("R/ui/chat_renderers.R")
}
