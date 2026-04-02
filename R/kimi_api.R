# =============================================================================
# File   : R/kimi_api.R
# Purpose: LLM API client (OpenAI-compatible format).  Supports all providers
#          registered in LLM_PROVIDERS (Kimi, DeepSeek, Qwen, Zhipu, OpenAI,
#          and any custom OpenAI-compatible endpoint).
#          Also owns chart-recommendation JSON parsing.
#
# Depends: R/config_manager.R (KIMI_API_URL fallback, LLM_PROVIDERS)
#          httr2, jsonlite     (loaded globally)
#
# Functions:
#   chat_with_llm(messages, api_key, model, api_url)
#     Sends a chat/completions request and returns a normalised result list.
#     Parameters:
#       messages [list]  OpenAI message objects {role, content}
#       api_key  [chr]   bearer token
#       model    [chr]   model identifier
#       api_url  [chr]   full chat completions URL (default: KIMI_API_URL)
#     Returns: list(success [lgl], content [chr], suggestion [list|NULL])
#
#   chat_with_kimi(messages, api_key, model)
#     Backward-compatible wrapper that calls chat_with_llm with the Kimi URL.
#
#   parse_chart_suggestion(text)
#     Extracts the ```json ... ``` block from an LLM response and normalises
#     it into a suggestion payload.
#     Returns: list | NULL
#
#   normalize_suggestion_payload(parsed)
#     Normalises a raw parsed list into {primary, primary_idx, recommendations}.
#
#   normalize_recommendation_item(item)
#     Normalises a single recommendation object; returns NULL if invalid.
# =============================================================================

# ---------------------------------------------------------------------------
# Environment isolation via local():
#   KIMI_API_URL and the two normalize_* helpers are private.
#   Only chat_with_llm, chat_with_kimi, parse_chart_suggestion are exported.
# ---------------------------------------------------------------------------
local({

.KIMI_API_URL <- "https://api.moonshot.cn/v1/chat/completions"

# Make the URL accessible to intent_engine.R (backward compat) via a
# read-only global alias — but the internal constant stays private.
KIMI_API_URL <<- .KIMI_API_URL

.normalize_recommendation_item <- function(item) {
  chart_id <- item$chart_id %||% item$recommended_chart
  if (is.null(chart_id)) return(NULL)

  chart_id <- as.character(chart_id)[1]
  if (!nzchar(chart_id) || !(chart_id %in% CHART_IDS)) return(NULL)

  confidence <- tolower(as.character(item$confidence %||% "medium")[1])
  if (!(confidence %in% c("high", "medium", "low"))) confidence <- "medium"

  reason <- as.character(item$reason %||% "")[1]

  mapping <- item$column_mapping %||% item$mapping %||% list()
  if (is.data.frame(mapping)) mapping <- as.list(mapping[1, , drop = TRUE])
  if (!is.list(mapping)) mapping <- list()

  patch <- item$options_patch %||% item$options %||% list()
  if (is.data.frame(patch)) patch <- as.list(patch[1, , drop = TRUE])
  if (!is.list(patch)) patch <- list()

  warnings <- item$warnings %||% character(0)
  if (is.list(warnings)) warnings <- unlist(warnings, use.names = FALSE)
  warnings <- as.character(warnings)

  list(
    chart_id = chart_id,
    confidence = confidence,
    reason = reason,
    column_mapping = mapping,
    options_patch = patch,
    warnings = warnings
  )
}

.normalize_suggestion_payload <- function(parsed) {
  recs <- list()

  if (!is.null(parsed$recommendations) && is.list(parsed$recommendations)) {
    recs <- lapply(parsed$recommendations, .normalize_recommendation_item)
    recs <- Filter(Negate(is.null), recs)
  }

  if (length(recs) == 0) {
    one <- .normalize_recommendation_item(parsed)
    if (!is.null(one)) recs <- list(one)
  }

  if (length(recs) == 0) return(NULL)

  primary <- as.character(parsed$primary %||% parsed$recommended_chart %||% recs[[1]]$chart_id)[1]
  chart_ids <- vapply(recs, function(r) r$chart_id, character(1))
  primary_idx <- match(primary, chart_ids)
  if (is.na(primary_idx)) primary_idx <- 1L
  primary_rec <- recs[[primary_idx]]

  list(
    primary            = primary_rec$chart_id,
    primary_idx        = primary_idx,
    primary_confidence = primary_rec$confidence,
    recommended_chart  = primary_rec$chart_id,
    confidence         = primary_rec$confidence,
    recommendations    = recs
  )
}

# ── Exported: generic LLM call (OpenAI-compatible, all providers) ─────────────
#
# json_mode [lgl] — when TRUE, adds response_format = {type:"json_object"} to
#   the request body.  The API then guarantees the response is valid JSON with
#   no markdown fences or surrounding prose.  Use only for structured-output
#   calls (e.g. code patches); do NOT use for general chat because
#   parse_chart_suggestion() expects a ```json``` fenced block.
chat_with_llm <<- function(messages, api_key, model, api_url = .KIMI_API_URL,
                           json_mode = FALSE) {
  if (is.null(api_key) || nchar(trimws(api_key)) == 0) {
    return(list(success = FALSE, content = "Please configure an API Key in Settings.", suggestion = NULL))
  }
  if (is.null(api_url) || nchar(trimws(api_url)) == 0) {
    return(list(success = FALSE, content = "API URL not configured. Check Settings.", suggestion = NULL))
  }

  tryCatch({
    body <- list(
      model       = model,
      messages    = messages,
      temperature = 0.2,
      max_tokens  = 1800
    )
    if (isTRUE(json_mode)) {
      body$response_format <- list(type = "json_object")
    }

    resp <- httr2::request(api_url) |>
      httr2::req_headers(
        Authorization = paste("Bearer", trimws(api_key)),
        `Content-Type` = "application/json"
      ) |>
      httr2::req_body_json(body) |>
      httr2::req_timeout(60) |>
      httr2::req_perform()

    data    <- httr2::resp_body_json(resp)
    content <- data$choices[[1]]$message$content

    list(success = TRUE, content = content, suggestion = parse_chart_suggestion(content))
  }, error = function(e) {
    msg <- conditionMessage(e)
    if      (grepl("401", msg))                                    msg <- "Invalid API Key. Please check Settings."
    else if (grepl("429", msg))                                    msg <- "Rate limit exceeded. Please retry later."
    else if (grepl("timeout|timed out", msg, ignore.case = TRUE))  msg <- "Request timed out. Check your network."

    list(success = FALSE, content = paste("API call failed:", msg), suggestion = NULL)
  })
}

# ── Exported: backward-compatible Kimi wrapper ────────────────────────────────
chat_with_kimi <<- function(messages, api_key, model = "moonshot-v1-8k") {
  chat_with_llm(messages, api_key, model, api_url = .KIMI_API_URL)
}

# ── Exported: extract structured suggestion JSON from LLM response text ───────
parse_chart_suggestion <<- function(text) {
  m <- regmatches(text, regexpr("```json[\\s\\S]*?```", text, perl = TRUE))
  if (length(m) == 0) return(NULL)

  json_str <- trimws(gsub("```json|```", "", m))

  parsed <- tryCatch(
    jsonlite::fromJSON(json_str, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(parsed)) return(NULL)

  .normalize_suggestion_payload(parsed)
}

}) # end local()