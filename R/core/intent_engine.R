# =============================================================================
# File   : R/core/intent_engine.R
# Purpose: Natural-language intent extraction engine.  Converts free-form user
#          messages into structured intent objects that the chat module can
#          apply directly to Shiny input widgets without a full AI roundtrip.
#
# Architecture (three-layer pipeline):
#   1. extract_intent_local(user_text, chart_id)
#        Fast local matching using INTENT_SYNONYMS dictionary + regex patterns.
#        No API call.  Handles ~80% of common modification requests.
#   2. extract_intent_llm(user_text, chart_id, api_key, model, api_url)
#        Calls the configured LLM with a focused parameter-extractor prompt
#        (NOT the chart-recommendation prompt).  Returns structured JSON.
#   3. parse_intent(user_text, chart_id, api_key, model, api_url)
#        Orchestrates layers 1→2: tries local first, falls back to LLM if
#        local returns no hits, assigns confidence level, routes undo.
#
# Intent object structure (returned by parse_intent):
#   list(
#     intent_type        [chr]  "modify_current" | "recommend_new" | "undo" | "unknown"
#     common_patch       [list] global params: plot_title, x_label, y_label,
#                               color_palette, chart_theme, plot_width_in,
#                               plot_height_in, plot_dpi, x/y_range_mode,
#                               x/y_min, x/y_max
#     options_patch      [list] chart-specific params keyed by options_def id
#     confidence         [chr]  "high" | "medium" | "low"
#     needs_clarification [lgl]
#     clarify_question   [chr]  follow-up question for low-confidence intents
#     source             [chr]  "local" | "llm" | "fallback"
#     hits               [chr]  field names successfully extracted
#   )
#
# Key constants:
#   INTENT_SYNONYMS  named list — canonical param → Chinese/English alias vectors
#   CHANGE_VERBS     chr  — verb phrases signalling a value assignment
#   UNDO_TRIGGERS    chr  — phrases triggering the undo action
#   BOOL_ON / BOOL_OFF chr — phrases meaning true / false for checkbox params
#
# Undo stack functions:
#   snapshot_inputs(input)        — captures current widget state as a list
#   push_history(rv, snapshot)    — pushes snapshot onto rv$patch_history (max 10)
#   restore_last(rv, session)     — pops and restores the most recent snapshot
#
# Utility:
#   format_intent_summary(intent) — human-readable "field → value | ..." string
#
# Architecture:
#   parse_intent(user_text, chart_id, api_key, model)
#     → returns a standard intent object:
#       list(
#         intent_type       chr  "modify_current" | "recommend_new" | "undo" | "unknown"
#         common_patch      list  fields for global settings (plot_title, x_label, ...)
#         options_patch     list  fields for chart-specific opt_* inputs
#         confidence        chr  "high" | "medium" | "low"
#         needs_clarification lgl
#         clarify_question  chr
#         source            chr  "local" | "llm" | "fallback"
#         hits              chr vector of matched field names
#       )
#
# Execution flow (in mod_ai_chat.R):
#   high       → auto-apply, push to history, show summary
#   medium     → store as rv$pending_intent, show preview card
#   low/clarify → append clarify_question to chat, do NOT apply


# ── Synonym dictionary ────────────────────────────────────────────────────────
# Each entry: field_name = character vector of all accepted Chinese/English aliases.
# Matching is case-insensitive.

INTENT_SYNONYMS <- list(
  plot_title  = c("标题", "题目", "图题", "图名", "图表名", "图表标题",
                  "title", "chart title", "plot title", "名字", "名称"),
  x_label     = c("x轴", "x轴标签", "x轴标题", "x轴名", "x轴名称",
                  "横轴", "横轴标签", "横坐标", "x坐标轴",
                  "x label", "xlabel", "x-label"),
  y_label     = c("y轴", "y轴标签", "y轴标题", "y轴名", "y轴名称",
                  "纵轴", "纵轴标签", "纵坐标", "y坐标轴",
                  "y label", "ylabel", "y-label"),
  # Numeric chart-option aliases (matched only if that opt exists for current chart)
  alpha       = c("透明度", "alpha", "不透明度", "透明"),
  point_size  = c("点大小", "点尺寸", "点的大小", "散点大小",
                  "point size", "pointsize", "point_size"),
  bar_width   = c("柱宽", "条宽", "bar width", "barwidth"),
  line_size   = c("线宽", "线条粗细", "线条宽度", "line width", "linewidth"),
  label_size  = c("标签字号", "标签大小", "label size", "labelsize"),
  font_size   = c("字号", "字体大小", "font size", "fontsize"),
  # Boolean chart-option aliases
  show_labels = c("标签", "数值标签", "数据标签", "label", "labels", "data label"),
  show_smooth = c("趋势线", "拟合线", "回归线", "smooth", "trend", "trendline"),
  show_legend = c("图例", "legend")
)

# Verbs that signal "set X to VALUE"
CHANGE_VERBS <- c(
  "改成", "改为", "设为", "设置为", "换成", "换为", "变成",
  "调整为", "修改为", "更改为", "替换为", "替换成",
  "用", "叫", "命名为", "取名", "起名",
  "=", "：", ":", "->", "→", "——"
)

# Words/phrases that unambiguously signal "undo"
UNDO_TRIGGERS <- c("撤销", "回退", "undo", "取消上一步",
                   "恢复上一次", "撤回", "还原")

# Words that signal "turn ON" a boolean option
BOOL_ON  <- c("开", "开启", "显示", "打开", "on", "true", "yes",
              "要", "需要", "加上", "加", "启用")
# Words that signal "turn OFF"
BOOL_OFF <- c("关", "关闭", "隐藏", "去掉", "去除", "off", "false",
              "no", "不要", "不显示", "禁用", "移除")


# ── Low-level helpers ─────────────────────────────────────────────────────────

.re_escape <- function(s) gsub("([.+*?^${}()|\\[\\]\\\\])", "\\\\\\1", s)

# Try to parse a value string as a number; return NA on failure.
.parse_number <- function(s) {
  s <- trimws(s)
  # Remove trailing % and convert
  s <- sub("%$", "", s)
  suppressWarnings(as.numeric(s))
}

# Detect "X 到/~ Y" range patterns; returns list(lo, hi) or NULL.
.parse_range <- function(txt) {
  m <- regmatches(
    txt,
    regexec(
      "([\\-]?[0-9]+(?:\\.[0-9]+)?)\\s*(?:到|~|\\-|to)\\s*([\\-]?[0-9]+(?:\\.[0-9]+)?)",
      txt, perl = TRUE
    )
  )[[1]]
  if (length(m) < 3) return(NULL)
  lo <- suppressWarnings(as.numeric(m[2]))
  hi <- suppressWarnings(as.numeric(m[3]))
  if (is.na(lo) || is.na(hi)) return(NULL)
  list(lo = lo, hi = hi)
}

# Given a field's aliases and raw text, find the value after a change-verb.
# Returns the raw value string, or NULL if no match.
.match_set_value <- function(txt, aliases) {
  verb_pat <- paste(vapply(CHANGE_VERBS, .re_escape, character(1)), collapse = "|")
  for (alias in aliases) {
    pattern <- paste0(
      "(?i)", .re_escape(alias),
      "\\s*(?:", verb_pat, ")\\s*",
      "[\"'\u201c\u201d\u300a\u300b\u3010\u3011]?",
      "([^\"\u201d\u300b\u3011\\n]+?)",
      "[\"'\u201c\u201d\u300a\u300b\u3010\u3011]?\\s*$"
    )
    m <- regmatches(txt, regexec(pattern, txt, perl = TRUE))[[1]]
    if (length(m) >= 2) return(trimws(m[2]))
  }
  NULL
}

# Detect boolean intent for a field (ON / OFF / NULL = not mentioned).
# Uses word boundaries (\b) for pure-ASCII words to avoid false positives
# like "on" matching inside "Month", "font", etc.
.match_bool <- function(txt, aliases) {
  .gpat <- function(w) {
    if (grepl("^[A-Za-z]+$", w))
      paste0("(?i)\\b", .re_escape(w), "\\b")
    else
      paste0("(?i)", .re_escape(w))
  }
  field_hit <- any(vapply(aliases, function(a) grepl(.gpat(a), txt, perl = TRUE), logical(1)))
  if (!field_hit) return(NULL)
  for (w in BOOL_ON)  if (grepl(.gpat(w), txt, perl = TRUE)) return(TRUE)
  for (w in BOOL_OFF) if (grepl(.gpat(w), txt, perl = TRUE)) return(FALSE)
  NULL
}


# ── Local intent extractor ────────────────────────────────────────────────────
# Fast, deterministic, no API call.
# Returns an intent object or NULL if nothing matched.

extract_intent_local <- function(user_text, chart_id) {
  txt      <- trimws(user_text)
  common   <- list()
  opts     <- list()
  hits     <- character(0)

  # ── 1. Undo ──────────────────────────────────────────────────────────────
  if (any(vapply(UNDO_TRIGGERS, function(w) grepl(w, txt, ignore.case = TRUE), logical(1)))) {
    return(list(
      intent_type = "undo", common_patch = list(), options_patch = list(),
      confidence = "high", needs_clarification = FALSE, clarify_question = "",
      source = "local", hits = "undo"
    ))
  }

  # ── 2. Global text fields (title / x_label / y_label) ────────────────────
  for (field in c("plot_title", "x_label", "y_label")) {
    val <- .match_set_value(txt, INTENT_SYNONYMS[[field]])
    if (!is.null(val) && nzchar(val)) {
      common[[field]] <- val
      hits <- c(hits, field)
    }
  }
  # Special: "起名/取名/命名(为) VALUE" → plot_title
  if (is.null(common$plot_title)) {
    m <- regmatches(txt, regexec(
      "(?:\u8d77\u540d|\u53d6\u540d|\u547d\u540d)\\s*(?:\u4e3a|\u53eb|\u6210)?\\s*[\"'\u201c\u201d]?([^\"\u201d\n]+?)[\"'\u201c\u201d]?\\s*$",
      txt, perl = TRUE
    ))[[1]]
    if (length(m) >= 2 && nzchar(trimws(m[2]))) {
      common$plot_title <- trimws(m[2])
      hits <- c(hits, "plot_title")
    }
  }

  # ── 3. Axis range ("x范围 0到100" / "y range 0~50") ──────────────────────
  for (axis in c("x", "y")) {
    if (!is.null(common[[paste0(axis, "_min")]])) next  # already matched
    axis_pats <- if (axis == "x")
      c("x坐标范围", "x轴范围", "x范围", "x range", "x坐标", "x轴",
        "横坐标范围", "横轴范围", "横坐标", "横轴", "x-axis", "x axis")
    else
      c("y坐标范围", "y轴范围", "y范围", "y range", "y坐标", "y轴",
        "纵坐标范围", "纵轴范围", "纵坐标", "纵轴", "y-axis", "y axis")
    for (pat in axis_pats) {
      if (!grepl(pat, txt, ignore.case = TRUE, perl = TRUE)) next
      after <- sub(paste0("(?i).*", .re_escape(pat)), "", txt, perl = TRUE)
      rng <- .parse_range(after)
      if (!is.null(rng)) {
        common[[paste0(axis, "_range_mode")]] <- "manual"
        common[[paste0(axis, "_min")]]        <- rng$lo
        common[[paste0(axis, "_max")]]        <- rng$hi
        hits <- c(hits, paste0(axis, "_range"))
        break
      }
    }
    # "x范围自动" → reset to auto
    if (grepl(paste0("(?i)", axis, ".*自动.*范围|", axis, "范围.*自动"), txt, perl = TRUE)) {
      common[[paste0(axis, "_range_mode")]] <- "auto"
      hits <- c(hits, paste0(axis, "_range_auto"))
    }
  }

  # ── 4. Width / height / DPI ───────────────────────────────────────────────
  for (cfg in list(
    list(field = "plot_width_in",  pats = c("宽度", "宽", "width")),
    list(field = "plot_height_in", pats = c("高度", "高", "height")),
    list(field = "plot_dpi",       pats = c("dpi", "分辨率", "清晰度"))
  )) {
    val <- .match_set_value(txt, cfg$pats)
    n   <- if (!is.null(val)) .parse_number(val) else NA_real_
    if (!is.na(n)) { common[[cfg$field]] <- n; hits <- c(hits, cfg$field) }
  }

  # ── 5. Theme / palette (exact name matching) ──────────────────────────────
  for (nm in names(CHART_THEMES)) {
    if (grepl(.re_escape(nm), txt, perl = TRUE, ignore.case = TRUE)) {
      common$chart_theme <- nm; hits <- c(hits, "chart_theme"); break
    }
  }
  for (nm in names(COLOR_PALETTES)) {
    if (grepl(.re_escape(nm), txt, perl = TRUE, ignore.case = TRUE)) {
      common$color_palette <- nm; hits <- c(hits, "color_palette"); break
    }
  }

  # ── 6. Chart-specific numeric options ────────────────────────────────────
  defs <- CHARTS[[chart_id]]$options_def %||% list()
  has_opt <- function(id) any(vapply(defs, function(d) identical(d$id, id), logical(1)))
  get_opt_def <- function(id) defs[[which(vapply(defs, function(d) identical(d$id, id), logical(1)))[1]]]

  numeric_opt_fields <- c("alpha", "point_size", "bar_width", "line_size",
                          "label_size", "font_size")
  for (field in numeric_opt_fields) {
    if (!has_opt(field)) next
    val <- .match_set_value(txt, INTENT_SYNONYMS[[field]])
    n   <- if (!is.null(val)) .parse_number(val) else NA_real_
    # Also try "透明度 0.5" without a verb (just juxtaposition)
    if (is.na(n) && !is.null(INTENT_SYNONYMS[[field]])) {
      for (alias in INTENT_SYNONYMS[[field]]) {
        m <- regmatches(txt, regexec(
          paste0("(?i)", .re_escape(alias), "\\s+([0-9]+(?:\\.[0-9]+)?)"),
          txt, perl = TRUE
        ))[[1]]
        if (length(m) >= 2) { n <- .parse_number(m[2]); break }
      }
    }
    if (!is.na(n)) {
      # Clamp to defined range if available
      d <- if (has_opt(field)) get_opt_def(field) else NULL
      if (!is.null(d) && !is.null(d$min) && !is.null(d$max)) {
        n <- max(d$min, min(d$max, n))
      }
      opts[[field]] <- n; hits <- c(hits, paste0("opt_", field))
    }
  }

  # ── 7. Boolean options ────────────────────────────────────────────────────
  bool_opt_fields <- c("show_labels", "show_smooth", "show_legend")
  for (field in bool_opt_fields) {
    if (!has_opt(field)) next
    val <- .match_bool(txt, INTENT_SYNONYMS[[field]])
    if (!is.null(val)) { opts[[field]] <- val; hits <- c(hits, paste0("opt_", field)) }
  }

  if (length(hits) == 0) return(NULL)

  list(
    intent_type         = "modify_current",
    common_patch        = common,
    options_patch       = opts,
    confidence          = "high",         # local regex match → high confidence
    needs_clarification = FALSE,
    clarify_question    = "",
    source              = "local",
    hits                = unique(hits)
  )
}


# ── LLM intent extractor ──────────────────────────────────────────────────────
# Sends a focused, minimal prompt to Kimi asking ONLY for intent JSON.
# Returns an intent object or NULL on failure.

# Format a single options_def entry into a rich comment line for the LLM prompt.
# Includes type, range, all choices (with Chinese labels), and dependency hint.
.opt_prompt_line <- function(d) {
  type_hint <- switch(d$type %||% "unknown",
    slider = {
      rng <- if (!is.null(d$min) && !is.null(d$max))
        sprintf("%.4g ~ %.4g", d$min, d$max) else "number"
      stp <- if (!is.null(d$step)) sprintf(", step %.4g", d$step) else ""
      sprintf("[数字 %s%s]", rng, stp)
    },
    numeric = {
      rng <- if (!is.null(d$min) && !is.null(d$max))
        sprintf("%.4g ~ %.4g", d$min, d$max) else "整数"
      sprintf("[整数 %s]", rng)
    },
    checkbox = "[true/false 布尔开关]",
    select = {
      ch <- d$choices
      if (is.null(ch) || length(ch) == 0) return(sprintf('  "%s": null  // %s [select]', d$id, d$label))
      # choices in R are named vectors: names = display labels, values = option values
      opts <- paste(
        vapply(seq_along(ch), function(i) {
          sprintf('"%s"(%s)', as.character(ch[[i]]), names(ch)[i])
        }, character(1)),
        collapse = " | "
      )
      sprintf("[选项: %s]", opts)
    },
    sprintf("[%s]", d$type)
  )
  dep <- if (!is.null(d$show_when) && nzchar(d$show_when))
    sprintf(", 仅当 %s=true 时生效", d$show_when) else ""
  sprintf('  "%s": null  // %s %s%s', d$id, d$label, type_hint, dep)
}

.build_intent_prompt <- function(chart_id, defs) {
  chart <- CHARTS[[chart_id]]

  # Rich option block: every parameter with full type/choices/dependency info
  param_lines <- vapply(defs, .opt_prompt_line, character(1))
  param_block <- paste(param_lines, collapse = "\n")

  # Available palette and theme names so LLM can pick exact strings
  palette_opts <- paste(names(COLOR_PALETTES), collapse = " | ")
  theme_opts   <- paste(names(CHART_THEMES),   collapse = " | ")

  paste0(
    '你是一个 R 绘图工具的参数提取器，当前图表: ', chart$name %||% chart_id,
    ' (id=', chart_id, ')\n\n',
    '任务: 将用户的自然语言（中文或英文）映射到下面 JSON 模板的字段。\n',
    '规则:\n',
    '  1. 只填写用户明确提到的字段，其余保持 null\n',
    '  2. 仅返回合法 JSON，不要 markdown 代码块，不要任何解释\n',
    '  3. select 类型字段必须使用括号前的值（如 "lm" 而不是 "Linear"）\n',
    '  4. 若用户意图不明确，将 needs_clarification 设为 true 并填写 clarify_question\n\n',
    '## 通用设置\n',
    '  "plot_title"     // 图表标题 / 图名 / 名称\n',
    '  "x_label"        // x轴 / 横轴 / 横坐标 的说明文字\n',
    '  "y_label"        // y轴 / 纵轴 / 纵坐标 的说明文字\n',
    '  "color_palette"  // 配色方案，可选: ', palette_opts, '\n',
    '  "chart_theme"    // 主题风格，可选: ', theme_opts, '\n',
    '  "x_min"/"x_max" // 手动指定 x 轴范围时同时设置 x_range_mode="manual"\n',
    '  "y_min"/"y_max" // 手动指定 y 轴范围时同时设置 y_range_mode="manual"\n\n',
    '## 当前图表专属选项\n',
    param_block, '\n\n',
    '## 返回 JSON 模板\n',
    '{\n',
    '  "intent_type": "modify_current",\n',
    '  "common_patch": {\n',
    '    "plot_title": null, "x_label": null, "y_label": null,\n',
    '    "color_palette": null, "chart_theme": null,\n',
    '    "plot_width_in": null, "plot_height_in": null, "plot_dpi": null,\n',
    '    "x_range_mode": null, "x_min": null, "x_max": null,\n',
    '    "y_range_mode": null, "y_min": null, "y_max": null\n',
    '  },\n',
    '  "options_patch": {\n',
    paste(
      vapply(defs, function(d) sprintf('    "%s": null', d$id), character(1)),
      collapse = ",\n"
    ), '\n',
    '  },\n',
    '  "confidence": "high|medium|low",\n',
    '  "needs_clarification": false,\n',
    '  "clarify_question": ""\n',
    '}'
  )
}

extract_intent_llm <- function(user_text, chart_id, api_key, model = "moonshot-v1-8k",
                               api_url = KIMI_API_URL) {
  if (is.null(api_key) || !nzchar(trimws(api_key))) return(NULL)

  defs    <- CHARTS[[chart_id]]$options_def %||% list()
  sys_msg <- .build_intent_prompt(chart_id, defs)

  result  <- tryCatch(
    chat_with_llm(
      messages = list(
        list(role = "system",  content = sys_msg),
        list(role = "user",    content = user_text)
      ),
      api_key = api_key,
      model   = model,
      api_url = api_url
    ),
    error = function(e) NULL
  )
  if (is.null(result) || !isTRUE(result$success)) return(NULL)

  # Parse raw JSON from the response (no markdown code fence expected, but handle it)
  raw <- trimws(result$content)
  raw <- gsub("^```json\\s*|^```\\s*|\\s*```$", "", raw, perl = TRUE)

  parsed <- tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(parsed)) return(NULL)

  # Normalise
  intent_type <- as.character(parsed$intent_type %||% "unknown")[1]
  confidence  <- tolower(as.character(parsed$confidence %||% "medium")[1])
  if (!confidence %in% c("high", "medium", "low")) confidence <- "medium"

  # Flatten common_patch and options_patch, removing nulls
  clean_patch <- function(p) {
    if (!is.list(p)) return(list())
    Filter(function(v) !is.null(v), p)
  }
  common  <- clean_patch(parsed$common_patch)
  opts    <- clean_patch(parsed$options_patch)

  hits <- c(names(common), paste0("opt_", names(opts)))
  if (length(hits) == 0 && identical(intent_type, "modify_current")) {
    intent_type <- "unknown"
  }

  list(
    intent_type         = intent_type,
    common_patch        = common,
    options_patch       = opts,
    confidence          = confidence,
    needs_clarification = isTRUE(parsed$needs_clarification),
    clarify_question    = as.character(parsed$clarify_question %||% "")[1],
    source              = "llm",
    hits                = unique(hits)
  )
}


# ── Orchestrator ──────────────────────────────────────────────────────────────
# 1. Try local (instant)
# 2. If local hits with non-zero confidence → return immediately
# 3. Else try LLM with focused intent prompt
# 4. Merge: LLM wins on discovered fields, local wins on high-confidence fields

parse_intent <- function(user_text, chart_id, api_key = NULL, model = "moonshot-v1-8k",
                         api_url = KIMI_API_URL) {
  # Local fast path
  local_result <- extract_intent_local(user_text, chart_id)

  # Undo is always handled locally
  if (!is.null(local_result) && identical(local_result$intent_type, "undo")) {
    return(local_result)
  }

  # If local matched something, trust it (high confidence, no API cost)
  if (!is.null(local_result) && length(local_result$hits) > 0) {
    return(local_result)
  }

  # Fall back to LLM
  llm_result <- extract_intent_llm(user_text, chart_id, api_key, model, api_url)

  if (!is.null(llm_result)) return(llm_result)

  # Complete fallback: unknown, let caller handle via normal AI chat
  NULL
}


# ── Patch history helpers ─────────────────────────────────────────────────────

# Snapshot the current input state for undo
snapshot_inputs <- function(input) {
  list(
    chart_id       = input$chart_type_select,
    plot_title     = input$plot_title     %||% "",
    x_label        = input$x_label        %||% "",
    y_label        = input$y_label        %||% "",
    color_palette  = input$color_palette  %||% "",
    chart_theme    = input$chart_theme    %||% "",
    plot_width_in  = input$plot_width_in,
    plot_height_in = input$plot_height_in,
    plot_dpi       = input$plot_dpi,
    x_range_mode   = input$x_range_mode   %||% "auto",
    x_min          = input$x_min,
    x_max          = input$x_max,
    y_range_mode   = input$y_range_mode   %||% "auto",
    y_min          = input$y_min,
    y_max          = input$y_max
  )
}

# Push a snapshot onto the history stack (max 10 entries)
push_history <- function(rv, snapshot) {
  rv$patch_history <- c(list(snapshot), rv$patch_history)[seq_len(min(10, length(rv$patch_history) + 1))]
  invisible(NULL)
}

# Restore the most recent snapshot from history
restore_last <- function(rv, session) {
  if (length(rv$patch_history) == 0) {
    showNotification("没有可撤销的操作", type = "warning", duration = 3)
    return(invisible(FALSE))
  }
  snap <- rv$patch_history[[1]]
  rv$patch_history <- rv$patch_history[-1]

  updateTextInput(session, "plot_title",    value = snap$plot_title    %||% "")
  updateTextInput(session, "x_label",       value = snap$x_label       %||% "")
  updateTextInput(session, "y_label",       value = snap$y_label       %||% "")
  if (!is.null(snap$color_palette) && nzchar(snap$color_palette))
    updateSelectInput(session, "color_palette", selected = snap$color_palette)
  if (!is.null(snap$chart_theme) && nzchar(snap$chart_theme))
    updateSelectInput(session, "chart_theme", selected = snap$chart_theme)
  if (!is.null(snap$plot_width_in))
    updateNumericInput(session, "plot_width_in",  value = snap$plot_width_in)
  if (!is.null(snap$plot_height_in))
    updateNumericInput(session, "plot_height_in", value = snap$plot_height_in)
  if (!is.null(snap$plot_dpi))
    updateNumericInput(session, "plot_dpi",       value = snap$plot_dpi)
  if (!is.null(snap$x_range_mode))
    updateSelectInput(session, "x_range_mode", selected = snap$x_range_mode)
  if (!is.null(snap$x_min)) updateNumericInput(session, "x_min", value = snap$x_min)
  if (!is.null(snap$x_max)) updateNumericInput(session, "x_max", value = snap$x_max)
  if (!is.null(snap$y_range_mode))
    updateSelectInput(session, "y_range_mode", selected = snap$y_range_mode)
  if (!is.null(snap$y_min)) updateNumericInput(session, "y_min", value = snap$y_min)
  if (!is.null(snap$y_max)) updateNumericInput(session, "y_max", value = snap$y_max)

  invisible(TRUE)
}


# ── Intent summary formatter ──────────────────────────────────────────────────
# Produces a human-readable string for the preview card or the chat echo.

format_intent_summary <- function(intent) {
  if (is.null(intent)) return("（无改动）")

  parts <- character(0)

  common_labels <- list(
    plot_title    = "标题",
    x_label       = "X轴标签",
    y_label       = "Y轴标签",
    color_palette = "配色",
    chart_theme   = "主题",
    plot_width_in = "宽度(in)",
    plot_height_in= "高度(in)",
    plot_dpi      = "DPI",
    x_range       = "X范围",
    y_range       = "Y范围"
  )

  for (k in names(intent$common_patch %||% list())) {
    v   <- intent$common_patch[[k]]
    lbl <- common_labels[[k]] %||% k
    parts <- c(parts, sprintf("%s → %s", lbl, v))
  }

  for (k in names(intent$options_patch %||% list())) {
    v <- intent$options_patch[[k]]
    parts <- c(parts, sprintf("%s → %s", k, v))
  }

  if (length(parts) == 0) return("（无改动）")
  paste(parts, collapse = "　|　")
}
