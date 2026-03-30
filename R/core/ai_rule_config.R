# =============================================================================
# File   : R/core/ai_rule_config.R
# Purpose: Load and provide centralized access to AI matching rules from JSON.
#          This keeps regex/synonym dictionaries out of module code.
#
# Depends: jsonlite, APP_DIR, log_warn/log_info (logger)
#
# Exported symbols:
#   AI_MATCH_RULES           [list] full parsed rule tree
#   ai_match_rule_get(path, default)
#   ai_match_rule_string(path, default)
#   ai_match_rule_vector(path, default)
# =============================================================================

load_ai_match_rules <- function(path = file.path(APP_DIR, "config", "ai_match_rules.json")) {
  if (!file.exists(path)) {
    log_warn("ai_rules", "rule file not found: %s", path)
    return(list())
  }

  parsed <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) {
      log_warn("ai_rules", "failed to parse rules json: %s", e$message)
      NULL
    }
  )

  if (is.null(parsed) || !is.list(parsed)) {
    log_warn("ai_rules", "invalid rule structure, using empty rules")
    return(list())
  }

  log_info("ai_rules", "loaded AI rules from %s", path)
  parsed
}

AI_MATCH_RULES <- load_ai_match_rules()

ai_match_rule_get <- function(path, default = NULL) {
  node <- AI_MATCH_RULES
  for (key in as.character(path)) {
    if (!is.list(node) || is.null(node[[key]])) return(default)
    node <- node[[key]]
  }
  node
}

ai_match_rule_string <- function(path, default = "") {
  v <- ai_match_rule_get(path, default = default)
  if (is.null(v) || length(v) == 0) return(default)
  out <- if (is.character(v)) v[[1]] else as.character(v[[1]])
  if (length(out) == 0 || is.na(out) || !nzchar(trimws(out))) return(default)
  out
}

ai_match_rule_vector <- function(path, default = character(0)) {
  v <- ai_match_rule_get(path, default = default)
  if (is.null(v)) return(default)
  if (is.character(v)) return(v)
  if (is.list(v)) return(as.character(unlist(v, use.names = FALSE)))
  default
}
