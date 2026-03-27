# R/kimi_api.R
# LLM API integration — OpenAI-compatible format, multi-provider.

KIMI_API_URL <- "https://api.moonshot.cn/v1/chat/completions"  # kept for backward compat

normalize_recommendation_item <- function(item) {
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

normalize_suggestion_payload <- function(parsed) {
  recs <- list()

  if (!is.null(parsed$recommendations) && is.list(parsed$recommendations)) {
    recs <- lapply(parsed$recommendations, normalize_recommendation_item)
    recs <- Filter(Negate(is.null), recs)
  }

  if (length(recs) == 0) {
    one <- normalize_recommendation_item(parsed)
    if (!is.null(one)) recs <- list(one)
  }

  if (length(recs) == 0) return(NULL)

  primary <- as.character(parsed$primary %||% parsed$recommended_chart %||% recs[[1]]$chart_id)[1]
  chart_ids <- vapply(recs, function(r) r$chart_id, character(1))
  primary_idx <- match(primary, chart_ids)
  if (is.na(primary_idx)) primary_idx <- 1L
  primary_rec <- recs[[primary_idx]]

  list(
    primary = primary_rec$chart_id,
    primary_idx = primary_idx,
    primary_confidence = primary_rec$confidence,
    recommended_chart = primary_rec$chart_id,
    confidence = primary_rec$confidence,
    recommendations = recs
  )
}

# Generic LLM call (OpenAI-compatible format, works for all supported providers)
chat_with_llm <- function(messages, api_key, model, api_url = KIMI_API_URL) {
  if (is.null(api_key) || nchar(trimws(api_key)) == 0) {
    return(list(success = FALSE, content = "请先在设置中配置 API Key。", suggestion = NULL))
  }
  if (is.null(api_url) || nchar(trimws(api_url)) == 0) {
    return(list(success = FALSE, content = "API URL 未配置，请在设置中检查。", suggestion = NULL))
  }

  tryCatch({
    resp <- httr2::request(api_url) |>
      httr2::req_headers(
        Authorization = paste("Bearer", trimws(api_key)),
        `Content-Type` = "application/json"
      ) |>
      httr2::req_body_json(list(
        model       = model,
        messages    = messages,
        temperature = 0.2,
        max_tokens  = 1800
      )) |>
      httr2::req_timeout(60) |>
      httr2::req_perform()

    data    <- httr2::resp_body_json(resp)
    content <- data$choices[[1]]$message$content

    list(success = TRUE, content = content, suggestion = parse_chart_suggestion(content))
  }, error = function(e) {
    msg <- conditionMessage(e)
    if      (grepl("401", msg))                            msg <- "API Key 无效，请检查配置。"
    else if (grepl("429", msg))                            msg <- "请求频率超限，请稍后重试。"
    else if (grepl("timeout|timed out", msg, ignore.case = TRUE)) msg <- "请求超时，请检查网络。"

    list(success = FALSE, content = paste("API 调用失败:", msg), suggestion = NULL)
  })
}

# Backward-compatible wrapper
chat_with_kimi <- function(messages, api_key, model = "moonshot-v1-8k") {
  chat_with_llm(messages, api_key, model, api_url = KIMI_API_URL)
}

# Extract structured suggestion JSON from model response text
parse_chart_suggestion <- function(text) {
  m <- regmatches(text, regexpr("```json[\\s\\S]*?```", text, perl = TRUE))
  if (length(m) == 0) return(NULL)

  json_str <- trimws(gsub("```json|```", "", m))

  parsed <- tryCatch(
    jsonlite::fromJSON(json_str, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(parsed)) return(NULL)

  normalize_suggestion_payload(parsed)
}