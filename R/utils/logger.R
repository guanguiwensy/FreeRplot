# =============================================================================
# File   : R/utils/logger.R
# Purpose: Centralised debug/info/warning/error logging for every module.
#          Controlled by the RPLOT_LOG environment variable so verbose output
#          is only visible during development without touching source code.
#
# Usage  :
#   Normal run  (only WARN + ERROR visible):  shiny::runApp()
#   Debug run   (all levels visible):         Sys.setenv(RPLOT_LOG="DEBUG"); shiny::runApp()
#
# Functions:
#   log_debug(module, fmt, ...)  - verbose trace, visible only at DEBUG level
#   log_info (module, fmt, ...)  - general informational messages
#   log_warn (module, fmt, ...)  - unexpected but recoverable conditions
#   log_error(module, fmt, ...)  - failures; always printed regardless of level
#   safe_run (module, expr)      - wraps expr in tryCatch; logs + returns NULL on error
#
# Parameters (all functions):
#   module [chr]  short tag identifying the calling file, e.g. "mod_ai_chat"
#   fmt    [chr]  sprintf-style format string
#   ...           additional args forwarded to sprintf
# =============================================================================

# ---------------------------------------------------------------------------
# Level ordering: DEBUG=1  INFO=2  WARN=3  ERROR=4
# ---------------------------------------------------------------------------
.LOG_LEVELS <- c(DEBUG = 1L, INFO = 2L, WARN = 3L, ERROR = 4L)

.current_log_level <- function() {
  env <- toupper(trimws(Sys.getenv("RPLOT_LOG", unset = "WARN")))
  .LOG_LEVELS[[env]] %||% .LOG_LEVELS[["WARN"]]
}

.should_log <- function(level_name) {
  .LOG_LEVELS[[level_name]] >= .current_log_level()
}

# Emit a formatted log line to stdout (captured by Shiny's process console)
.emit <- function(level_name, module, fmt, ...) {
  if (!.should_log(level_name)) return(invisible(NULL))
  ts  <- format(Sys.time(), "%H:%M:%S")
  msg <- tryCatch(sprintf(fmt, ...), error = function(e) fmt)
  cat(sprintf("[%s][%-5s][%s] %s\n", ts, level_name, module, msg))
  invisible(NULL)
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

#' Log a DEBUG-level message (development traces)
log_debug <- function(module, fmt, ...) .emit("DEBUG", module, fmt, ...)

#' Log an INFO-level message (normal milestones)
log_info  <- function(module, fmt, ...) .emit("INFO",  module, fmt, ...)

#' Log a WARN-level message (unexpected but app continues)
log_warn  <- function(module, fmt, ...) .emit("WARN",  module, fmt, ...)

#' Log an ERROR-level message (always visible)
log_error <- function(module, fmt, ...) .emit("ERROR", module, fmt, ...)

# ---------------------------------------------------------------------------
# safe_run — execute an expression, catch errors, return NULL on failure
# ---------------------------------------------------------------------------
#
# Usage:
#   result <- safe_run("mod_plot", {
#     generate_plot(chart_id, data, options)
#   })
#   if (is.null(result)) { ... handle gracefully ... }

safe_run <- function(module, expr) {
  tryCatch(
    expr,
    error = function(e) {
      log_error(module, "ERROR: %s", conditionMessage(e))
      NULL
    },
    warning = function(w) {
      log_warn(module, "WARNING: %s", conditionMessage(w))
      # Re-evaluate to get the actual result (warnings don't abort)
      withCallingHandlers(expr, warning = function(w) invokeRestart("muffleWarning"))
    }
  )
}
