# =============================================================================
# FILE:    R/core/code_engine.R
# PURPOSE: Code-first plot engine 鈥?three-layer code modification pipeline.
#
#   Layer 1 (zero LLM): quick_code_patch(user_text, code)
#     Matches common user intents with regex; directly modifies the code string.
#     Covers ~60% of requests: alpha, size, theme, palette, title, labels.
#
#   Layer 2 (LLM diff): build_patch_prompt() + apply_code_patches()
#     LLM returns [{search, replace}] patches; only changed lines are transmitted.
#     Covers complex but targeted changes: add geom, change aesthetics, etc.
#
#   Layer 3 (LLM rewrite): full code regeneration, fallback only.
#
# FUNCTIONS:
#   get_editor_code(chart_id, data)
#     Returns a clean, runnable code string for the shinyAce editor.
#     Strips library() calls and data definitions from the existing code_template;
#     inserts a header comment and ensures the last expression returns the plot.
#     Parameters: chart_id [chr]; data [data.frame] current data (for col hints).
#     Returns: chr
#
#   apply_code_patches(code, patches)
#     Applies a list of {search, replace} patches to a code string.
#     Parameters: code [chr]; patches [list] of list(search, replace).
#     Returns: list(ok [lgl], code [chr], failed [chr|NULL])
#
#   quick_code_patch(user_text, code)
#     Layer 1: tries every LOCAL_QUICK_OPS rule in order.
#     Returns the modified code [chr] on first match, or NULL if no rule matched.
#     Parameters: user_text [chr]; code [chr].
#     Returns: chr | NULL
#
#   build_patch_prompt(user_text, code, data_cols)
#     Builds the focused LLM prompt for Layer 2 patch mode.
#     Parameters: user_text [chr]; code [chr]; data_cols [chr] column names.
#     Returns: chr
#
#   parse_patch_response(response_text)
#     Parses the JSON response from a Layer 2 LLM call.
#     Returns: list(ok [lgl], patches [list] | NULL, raw [chr])
#
# DEPENDENCIES (incoming):
#   CHARTS, CHART_THEMES, COLOR_PALETTES  鈥?from global.R globals
#   get_default_options()                 鈥?from R/ui_helpers.R
#   %||%                                  鈥?from global.R
# =============================================================================

MODULE <- "code_engine"

.quick_pattern <- function(name) {
  pat <- ai_match_rule_string(c("code_engine", "quick_ops_patterns", name), default = "")
  if (!nzchar(pat)) return("(?!)")

  # Expand dynamic placeholders from runtime registries.
  pat <- gsub("\\{\\{chart_themes\\}\\}", paste(names(CHART_THEMES), collapse = "|"), pat)
  pat <- gsub("\\{\\{color_palettes\\}\\}", paste(names(COLOR_PALETTES), collapse = "|"), pat)
  pat
}

# 鈹€鈹€ get_editor_code 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Generates the initial code shown in the editor when a chart type is selected.
# Uses the chart's existing code_template with default options, then strips the
# standalone boilerplate (library calls, embedded data definition).

get_editor_code <- function(chart_id, data, data_file = NULL) {
  chart <- CHARTS[[chart_id]]
  if (is.null(chart)) {
    return("# Chart not found\nggplot() + theme_void()\n")
  }

  opts <- get_default_options(chart_id)

  # Attempt to use the chart's own code_template
  raw <- tryCatch({
    if (!is.function(chart$code_template)) return(NULL)
    argn <- length(formals(chart$code_template))
    if (argn >= 2) chart$code_template(opts, data) else chart$code_template(opts)
  }, error = function(e) NULL)

  if (!is.null(raw) && nzchar(raw)) {
    return(.strip_to_editor_code(raw, chart, data, data_file = data_file))
  }

  # Fallback: minimal template
  .fallback_editor_code(chart_id, data, data_file = data_file)
}

# Internal: strip library() / data<- boilerplate, adapt for eval environment.
.strip_to_editor_code <- function(raw_code, chart, data, data_file = NULL) {
  .is_inline_data_block <- function(block) {
    has_df_assign <- grepl(
      "(?m)^\\s*[A-Za-z.][A-Za-z0-9._]*\\s*<-\\s*data\\.frame\\s*\\(",
      block,
      perl = TRUE
    )
    has_structure_assign <- grepl(
      "(?m)^\\s*[A-Za-z.][A-Za-z0-9._]*\\s*<-\\s*structure\\s*\\(\\s*list\\s*\\(",
      block,
      perl = TRUE
    )
    has_df_assign || has_structure_assign
  }

  .main_data_symbol <- function(code) {
    hit <- regmatches(
      code,
      regexec("(?:ggplot2::)?ggplot\\(\\s*([A-Za-z.][A-Za-z0-9._]*)\\s*,", code, perl = TRUE)
    )[[1]]
    if (length(hit) >= 2) hit[2] else "data"
  }

  .runtime_context_comment <- function(data_symbol = "data") {
    var <- as.character(data_symbol %||% "data")
    if (!grepl("^[A-Za-z.][A-Za-z0-9._]*$", var, perl = TRUE)) var <- "data"
    alias_line <- if (!identical(var, "data")) {
      paste0(var, " <- data\n")
    } else {
      ""
    }
    paste0(
      "# Data/context is prepared by backend before code execution.\n",
      "# Available vars: data, df, col_names, num_cols, x_col, y_col, size_col, extra_cols.\n",
      alias_line
    )
  }

  .rewrite_main_aes_xy <- function(code, data_symbol) {
    sym <- as.character(data_symbol %||% "data")
    if (!grepl("^[A-Za-z.][A-Za-z0-9._]*$", sym, perl = TRUE)) return(code)

    # Skip rewrite when the symbol is reassigned inside template body.
    # In such cases, x/y may intentionally refer to transformed columns.
    if (grepl(paste0("(?m)^\\s*", sym, "\\s*<-"), code, perl = TRUE)) return(code)

    pat <- paste0(
      "((?:ggplot2::)?ggplot\\(\\s*", sym, "\\s*,\\s*(?:ggplot2::)?aes\\()",
      "([^\\)]*)",
      "(\\)\\s*\\))"
    )
    hits <- regmatches(code, gregexpr(pat, code, perl = TRUE))[[1]]
    if (length(hits) == 0 || identical(hits, character(0))) return(code)

    for (hit in hits) {
      rewritten <- gsub("\\bx\\s*=\\s*x\\b", "x = .data[[x_col]]", hit, perl = TRUE)
      rewritten <- gsub("\\by\\s*=\\s*y\\b", "y = .data[[y_col]]", rewritten, perl = TRUE)
      code <- sub(hit, rewritten, code, fixed = TRUE)
    }
    code
  }

  # Split on paragraph breaks; discard library() and inline sample-data blocks.
  blocks <- strsplit(raw_code, "\n{2,}")[[1]]

  keep <- vapply(blocks, function(b) {
    first <- trimws(strsplit(b, "\n")[[1]][1] %||% "")
    !grepl("^library\\(", first, perl = TRUE) &&
      !.is_inline_data_block(b)
  }, logical(1))

  plot_code <- paste(trimws(blocks[keep]), collapse = "\n\n")

  # Replace print(p) -> p so eval() returns the ggplot object.
  plot_code <- gsub("(?m)^\\s*print\\(p\\)\\s*$", "p", plot_code, perl = TRUE)

  # Ensure the code ends with the plot variable (p or last ggplot assignment).
  last_line <- trimws(tail(strsplit(plot_code, "\n")[[1]], 1))
  if (!grepl("^p\\s*$|^p\\s*\\+|^ggplot", last_line, perl = TRUE)) {
    if (grepl("\\bp\\s*<-\\s*ggplot|\\bp\\s*<-\\s*p\\s*\\+", plot_code, perl = TRUE)) {
      plot_code <- paste0(trimws(plot_code), "\n\np\n")
    }
  }

  data_symbol <- .main_data_symbol(plot_code)
  plot_code <- .rewrite_main_aes_xy(plot_code, data_symbol)
  runtime_context <- .runtime_context_comment(data_symbol)
  col_hint <- .col_hint_comment(chart, data)

  paste0(
    "# Runtime behavior: backend injects prepared data context before evaluation.\n",
    col_hint,
    "\n",
    runtime_context,
    "\n\n",
    trimws(plot_code),
    "\n"
  )
}

# Internal: one-line comment showing expected vs current columns.
.col_hint_comment <- function(chart, data) {
  expected <- chart$columns %||% ""
  current  <- if (!is.null(data) && ncol(data) > 0) paste(names(data), collapse = ", ") else "none"
  if (nzchar(expected)) {
    sprintf("# Expected columns: %s\n# Current  columns: %s\n", expected, current)
  } else {
    sprintf("# Current columns: %s\n", current)
  }
}

# Internal: minimal fallback when code_template is absent or fails.
.fallback_editor_code <- function(chart_id, data, data_file = NULL) {
  paste0(
    "# Runtime behavior: backend injects prepared data context before evaluation.\n",
    "# Available vars: data, df, col_names, num_cols, x_col, y_col, size_col, extra_cols.\n\n",
    "ggplot(data, aes(x = .data[[x_col]], y = .data[[y_col]])) +   # [aes]\n",
    "  geom_point(alpha = 0.8, size = 3) +          # [geom]\n",
    "  labs(title = \"\", x = x_col, y = y_col) +      # [labels]\n",
    "  theme_minimal()                               # [theme]\n"
  )
}


# ── apply_code_patches ────────────────────────────────────────────────────────
#
# Applies a list of {search, replace} patches sequentially.
# Each patch's search string must match exactly once in the code.
apply_code_patches <- function(code, patches) {
  if (!is.list(patches) || length(patches) == 0) {
    return(list(ok = TRUE, code = code, failed = NULL))
  }

  for (p in patches) {
    search  <- p$search  %||% ""
    replace <- p$replace %||% ""
    if (!nzchar(search)) next

    if (!grepl(search, code, fixed = TRUE)) {
      return(list(
        ok     = FALSE,
        code   = code,
        failed = sprintf("search string not found: '%s'", substr(search, 1, 60))
      ))
    }
    code <- sub(search, replace, code, fixed = TRUE)
  }

  code <- .repair_generated_code(code)
  list(ok = TRUE, code = code, failed = NULL)
}


# 鈹€鈹€ quick_code_patch 鈥?Layer 1 local regex ops 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Returns updated code string when one or more rules match, or NULL if no rule
# matched. All patterns are tried in order; multiple operations can be applied
# in one pass so compound instructions are handled together.

quick_code_patch <- function(user_text, code) {
  txt <- trimws(user_text)
  if (!nzchar(txt) || !nzchar(code)) return(NULL)

  out <- code
  matched_ops <- character(0)

  for (op in .QUICK_OPS) {
    m <- tryCatch(
      suppressWarnings(regexpr(op$pattern, txt, perl = TRUE, ignore.case = TRUE)),
      error = function(e) -1L
    )
    if (length(m) == 0 || is.na(m[1]) || m[1] == -1) next

    captures <- tryCatch(
      regmatches(txt, suppressWarnings(regexec(op$pattern, txt, perl = TRUE, ignore.case = TRUE)))[[1]],
      error = function(e) character(0)
    )
    if (length(captures) == 0) next
    result <- tryCatch(
      op$handler(out, captures),
      error = function(e) NULL
    )

    if (!is.null(result) && !identical(result, out)) {
      out <- .repair_generated_code(result)
      matched_ops <- c(matched_ops, op$name)
    }
  }

  if (length(matched_ops) == 0) return(NULL)
  log_debug(MODULE, "quick_ops matched (%d): %s", length(matched_ops), paste(matched_ops, collapse = ", "))
  out
}

# Internal: set or insert labs(x=...)/labs(y=...) without touching aes mapping.
.upsert_labs_value <- function(code, axis = c("x", "y"), value) {
  axis <- match.arg(axis)
  val <- trimws(as.character(value)[1] %||% "")
  if (!nzchar(val)) return(NULL)
  val <- gsub('"', "\\\\\"", val)

  out <- code
  labs_hit <- regmatches(out, regexpr("labs\\([^\\)]*\\)", out, perl = TRUE))

  if (length(labs_hit) > 0 && nzchar(labs_hit)) {
    labs_call <- labs_hit[[1]]
    if (grepl(paste0("\\b", axis, "\\s*="), labs_call, perl = TRUE)) {
      labs_new <- gsub(
        paste0("\\b", axis, "\\s*=\\s*(\"[^\"]*\"|'[^']*'|`[^`]*`|[^,\\)]+)"),
        paste0(axis, " = \"", val, "\""),
        labs_call, perl = TRUE
      )
    } else {
      labs_new <- sub("\\)$", paste0(", ", axis, " = \"", val, "\")"), labs_call, perl = TRUE)
    }
    out <- sub("labs\\([^\\)]*\\)", labs_new, out, perl = TRUE)
    return(if (identical(out, code)) NULL else out)
  }

  if (grepl("\\+\\s*theme_[A-Za-z0-9_]+\\(\\)", out, perl = TRUE)) {
    out <- sub(
      "\\+\\s*(theme_[A-Za-z0-9_]+\\(\\))",
      paste0("+ labs(", axis, " = \"", val, "\") + \\1"),
      out, perl = TRUE
    )
    return(if (identical(out, code)) NULL else out)
  }

  out <- sub(
    "(geom_\\w+\\([^\\)]*\\)\\s*\\+)",
    paste0("\\1\n  labs(", axis, " = \"", val, "\") +"),
    out, perl = TRUE
  )
  if (identical(out, code)) NULL else out
}

# Internal: set or insert labs(title=...) in the ggplot chain.
.upsert_labs_title <- function(code, value) {
  val <- trimws(as.character(value)[1] %||% "")
  if (!nzchar(val)) return(NULL)
  val <- gsub('"', "\\\\\"", val)

  out <- code
  labs_hit <- regmatches(out, regexpr("labs\\([^\\)]*\\)", out, perl = TRUE))

  if (length(labs_hit) > 0 && nzchar(labs_hit)) {
    labs_call <- labs_hit[[1]]
    if (grepl("\\btitle\\s*=", labs_call, perl = TRUE)) {
      labs_new <- gsub(
        "\\btitle\\s*=\\s*(\"[^\"]*\"|'[^']*'|`[^`]*`|[^,\\)]+)",
        paste0("title = \"", val, "\""),
        labs_call, perl = TRUE
      )
    } else {
      labs_new <- sub("\\)$", paste0(", title = \"", val, "\")"), labs_call, perl = TRUE)
    }
    out <- sub("labs\\([^\\)]*\\)", labs_new, out, perl = TRUE)
    return(if (identical(out, code)) NULL else out)
  }

  if (grepl("\\+\\s*theme_[A-Za-z0-9_]+\\(\\)", out, perl = TRUE)) {
    out <- sub(
      "\\+\\s*(theme_[A-Za-z0-9_]+\\(\\))",
      paste0("+ labs(title = \"", val, "\") + \\1"),
      out, perl = TRUE
    )
    return(if (identical(out, code)) NULL else out)
  }

  out <- sub(
    "(geom_\\w+\\([^\\)]*\\)\\s*\\+)",
    paste0("\\1\n  labs(title = \"", val, "\") +"),
    out, perl = TRUE
  )
  if (identical(out, code)) NULL else out
}

# 鈹€鈹€ LOCAL_QUICK_OPS 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
# Each entry: name, pattern (captures values in group 1+), handler(code, captures)

.QUICK_OPS <- list(
  list(
    name    = "title_set_safe",
    pattern = .quick_pattern("title_set_safe"),
    handler = function(code, m) {
      val <- trimws(m[2] %||% "")
      .upsert_labs_title(code, val)
    }
  ),
  list(
    name    = "xlabel_set_safe",
    pattern = .quick_pattern("xlabel_set_safe"),
    handler = function(code, m) {
      .upsert_labs_value(code, "x", m[2] %||% "")
    }
  ),
  list(
    name    = "ylabel_set_safe",
    pattern = .quick_pattern("ylabel_set_safe"),
    handler = function(code, m) {
      .upsert_labs_value(code, "y", m[2] %||% "")
    }
  ),
  list(
    name    = "alpha_absolute_safe",
    pattern = .quick_pattern("alpha_absolute_safe"),
    handler = function(code, m) {
      val <- m[2]
      gsub("\\balpha\\s*=\\s*[0-9.]+", paste0("alpha = ", val), code, perl = TRUE)
    }
  ),
  list(
    name    = "smooth_add_safe",
    pattern = .quick_pattern("smooth_add_safe"),
    handler = function(code, m) {
      if (grepl("geom_smooth", code, fixed = TRUE)) return(NULL)
      gsub("(geom_\\w+[^+]*\\+)", "\\1\n  geom_smooth(method = \"loess\", se = TRUE) +", code, perl = TRUE)
    }
  ),
  list(
    name    = "smooth_remove_safe",
    pattern = .quick_pattern("smooth_remove_safe"),
    handler = function(code, m) {
      if (!grepl("geom_smooth", code, fixed = TRUE)) return(NULL)
      gsub("\\s*\\+?\\s*geom_smooth\\([^)]*\\)", "", code, perl = TRUE)
    }
  ),
  list(
    name    = "theme_clean_safe",
    pattern = .quick_pattern("theme_clean_safe"),
    handler = function(code, m) {
      out <- code
      out <- gsub("theme_[^[:ascii:][:space:]\\(\\)]+\\(\\)", "theme_minimal()", out, perl = TRUE)
      out <- gsub("theme_\\w+\\(\\)", "theme_minimal()", out, perl = TRUE)
      out <- gsub("\\balpha\\s*=\\s*[0-9.]+", "alpha = 0.7", out, perl = TRUE)
      if (identical(out, code) && !grepl("theme_minimal\\(", out, perl = TRUE)) {
        out <- sub("\\+\\s*(labs\\([^\\)]*\\))", "+ \\1 + theme_minimal()", out, perl = TRUE)
      }
      if (identical(out, code)) NULL else out
    }
  ),

  # 鈹€鈹€ alpha / transparency 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  list(
    name    = "alpha_absolute",
    pattern = .quick_pattern("alpha_absolute"),
    handler = function(code, m) {
      val <- m[2]
      gsub("\\balpha\\s*=\\s*[0-9.]+", paste0("alpha = ", val), code, perl = TRUE)
    }
  ),
  list(
    name    = "alpha_more",
    pattern = .quick_pattern("alpha_more"),
    handler = function(code, m) {
      .scale_param(code, "alpha", 0.85, clamp = c(0.05, 1))
    }
  ),
  list(
    name    = "alpha_less",
    pattern = .quick_pattern("alpha_less"),
    handler = function(code, m) {
      .scale_param(code, "alpha", 1 / 0.85, clamp = c(0.05, 1))
    }
  ),

  # 鈹€鈹€ point / bar size 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  list(
    name    = "size_absolute",
    pattern = .quick_pattern("size_absolute"),
    handler = function(code, m) {
      val <- m[2]
      gsub("\\bsize\\s*=\\s*[0-9.]+", paste0("size = ", val), code, perl = TRUE)
    }
  ),
  list(
    name    = "size_bigger",
    pattern = .quick_pattern("size_bigger"),
    handler = function(code, m) {
      .scale_param(code, "size", 1.35, clamp = c(0.5, 20))
    }
  ),
  list(
    name    = "size_smaller",
    pattern = .quick_pattern("size_smaller"),
    handler = function(code, m) {
      .scale_param(code, "size", 1 / 1.35, clamp = c(0.5, 20))
    }
  ),

  list(
    name    = "size_map_to_y",
    pattern = .quick_pattern("size_map_to_y"),
    handler = function(code, m) {
      out <- code
      out <- gsub("(geom_(?:point|jitter)\\([^\\)]*?)\\bsize\\s*=\\s*[^,\\)]+\\s*,?\\s*", "\\1", out, perl = TRUE)
      out <- gsub("\\(\\s*,", "(", out, perl = TRUE)
      out <- gsub(",\\s*\\)", ")", out, perl = TRUE)
      if (grepl("aes\\(", out, perl = TRUE) && !grepl("aes\\([^\\)]*size\\s*=", out, perl = TRUE)) {
        out <- sub("aes\\(([^\\)]*)\\)", "aes(\\1, size = .data[[y_col]])", out, perl = TRUE)
      }
      if (identical(out, code)) NULL else out
    }
  ),
  list(
    name    = "highlight_xy_point",
    pattern = .quick_pattern("highlight_xy_point"),
    handler = function(code, m) {
      x_val <- m[2]
      y_val <- m[3]
      col   <- .normalize_highlight_color(m[4])
      .inject_highlight_layer(code, x_val, y_val, col)
    }
  ),
  list(
    name    = "highlight_xy_default",
    pattern = .quick_pattern("highlight_xy_default"),
    handler = function(code, m) {
      x_val <- m[2]
      y_val <- m[3]
      .inject_highlight_layer(code, x_val, y_val, "red")
    }
  ),
  list(
    name    = "shape_triangle",
    pattern = .quick_pattern("shape_triangle"),
    handler = function(code, m) {
      if (!grepl("\\bshape\\s*=", code, perl = TRUE)) return(NULL)
      gsub("\\bshape\\s*=\\s*(\"[^\"]+\"|'[^']+'|[0-9]+)", "shape = 17", code, perl = TRUE)
    }
  ),
  list(
    name    = "shape_circle",
    pattern = .quick_pattern("shape_circle"),
    handler = function(code, m) {
      if (!grepl("\\bshape\\s*=", code, perl = TRUE)) return(NULL)
      gsub("\\bshape\\s*=\\s*(\"[^\"]+\"|'[^']+'|[0-9]+)", "shape = 16", code, perl = TRUE)
    }
  ),
  list(
    name    = "shape_square",
    pattern = .quick_pattern("shape_square"),
    handler = function(code, m) {
      if (!grepl("\\bshape\\s*=", code, perl = TRUE)) return(NULL)
      gsub("\\bshape\\s*=\\s*(\"[^\"]+\"|'[^']+'|[0-9]+)", "shape = 15", code, perl = TRUE)
    }
  ),
  list(
    name    = "shape_numeric",
    pattern = .quick_pattern("shape_numeric"),
    handler = function(code, m) {
      val <- m[2]
      if (!grepl("\\bshape\\s*=", code, perl = TRUE)) return(NULL)
      gsub("\\bshape\\s*=\\s*(\"[^\"]+\"|'[^']+'|[0-9]+)", paste0("shape = ", val), code, perl = TRUE)
    }
  ),

  # 鈹€鈹€ line width 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  list(
    name    = "linewidth_absolute",
    pattern = .quick_pattern("linewidth_absolute"),
    handler = function(code, m) {
      val <- m[2]
      gsub("\\blinewidth\\s*=\\s*[0-9.]+", paste0("linewidth = ", val), code, perl = TRUE)
    }
  ),

  # 鈹€鈹€ theme 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  list(
    name    = "theme_named",
    pattern = .quick_pattern("theme_named"),
    handler = function(code, m) {
      nm <- m[2]
      gsub("theme_\\w+\\(\\)", paste0("theme_", nm, "()"), code, perl = TRUE)
    }
  ),

  # 鈹€鈹€ colour palette 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  list(
    name    = "palette_named",
    pattern = .quick_pattern("palette_named"),
    handler = function(code, m) {
      nm <- m[2]
      gsub('palette\\s*=\\s*"[^"]*"', paste0('palette = "', nm, '"'), code, perl = TRUE)
    }
  ),

  # 鈹€鈹€ plot title 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  list(
    name    = "title_set",
    pattern = .quick_pattern("title_set"),
    handler = function(code, m) {
      val <- trimws(m[2])
      .upsert_labs_title(code, val)
    }
  ),

  # 鈹€鈹€ axis labels 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  list(
    name    = "xlabel_set",
    pattern = .quick_pattern("xlabel_set"),
    handler = function(code, m) {
      val <- trimws(m[2])
      gsub('(?<=\\bx\\s*=\\s*")[^"]*(?=")', val, code, perl = TRUE)
    }
  ),
  list(
    name    = "ylabel_set",
    pattern = .quick_pattern("ylabel_set"),
    handler = function(code, m) {
      val <- trimws(m[2])
      gsub('(?<=\\by\\s*=\\s*")[^"]*(?=")', val, code, perl = TRUE)
    }
  ),

  # 鈹€鈹€ show/hide trend line 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  list(
    name    = "smooth_add",
    pattern = .quick_pattern("smooth_add"),
    handler = function(code, m) {
      if (grepl("geom_smooth", code, fixed = TRUE)) return(NULL)
      # Insert after first geom_ line
      gsub("(geom_\\w+[^+]*\\+)", "\\1\n  geom_smooth(method = \"loess\", se = TRUE) +",
           code, perl = TRUE)
    }
  ),
  list(
    name    = "smooth_remove",
    pattern = .quick_pattern("smooth_remove"),
    handler = function(code, m) {
      if (!grepl("geom_smooth", code, fixed = TRUE)) return(NULL)
      gsub("\\s*\\+?\\s*geom_smooth\\([^)]*\\)", "", code, perl = TRUE)
    }
  )
)

# Internal: scale a numeric parameter in code by a factor, clamped to range.
.scale_param <- function(code, param_name, factor, clamp = c(0, Inf)) {
  pattern <- paste0("\\b", param_name, "\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)")
  m <- regexpr(pattern, code, perl = TRUE)
  if (m == -1) return(NULL)

  cap <- regmatches(code, regexec(pattern, code, perl = TRUE))[[1]]
  current_val <- as.numeric(cap[2])
  new_val <- round(max(clamp[1], min(clamp[2], current_val * factor)), 3)

  gsub(paste0("\\b", param_name, "\\s*=\\s*[0-9.]+"),
       paste0(param_name, " = ", new_val),
       code, perl = TRUE)
}

# Internal: normalize user color tokens to safe CSS color names.
.normalize_highlight_color <- function(token) {
  t <- tolower(trimws(as.character(token)[1] %||% "red"))
  map <- c(
    "绾㈣壊" = "red", "red" = "red",
    "钃濊壊" = "blue", "blue" = "blue",
    "缁胯壊" = "green", "green" = "green",
    "榛戣壊" = "black", "black" = "black",
    "姗欒壊" = "orange", "orange" = "orange",
    "榛勮壊" = "yellow", "yellow" = "yellow",
    "绱壊" = "purple", "purple" = "purple"
  )
  unname(map[[t]] %||% "red")
}

# Internal: extract main ggplot data/x/y mapping expressions.
.extract_main_xy_expr <- function(code) {
  m <- regmatches(
    code,
    regexec("(?:ggplot2::)?ggplot\\(([^,\\n]+)\\s*,\\s*(?:ggplot2::)?aes\\(([^\\)]*)\\)", code, perl = TRUE)
  )[[1]]
  if (length(m) < 3) return(NULL)

  aes_txt <- m[3]
  x_m <- regmatches(aes_txt, regexec("\\bx\\s*=\\s*([^,\\)]+)", aes_txt, perl = TRUE))[[1]]
  y_m <- regmatches(aes_txt, regexec("\\by\\s*=\\s*([^,\\)]+)", aes_txt, perl = TRUE))[[1]]

  x_expr <- if (length(x_m) >= 2) trimws(x_m[2]) else NULL
  y_expr <- if (length(y_m) >= 2) trimws(y_m[2]) else NULL
  if (is.null(x_expr) || is.null(y_expr)) return(NULL)

  list(
    data_expr = trimws(m[2]),
    x_expr = x_expr,
    y_expr = y_expr
  )
}

# Internal: convert aes mapping expression into a data[[...]] index token.
# Returns quoted column name ("x") or a variable symbol (x_col), or NULL.
.mapping_to_data_index <- function(expr) {
  e <- trimws(as.character(expr)[1] %||% "")
  if (!nzchar(e)) return(NULL)

  m_var <- regmatches(e, regexec("^\\.data\\s*\\[\\[\\s*([A-Za-z.][A-Za-z0-9._]*)\\s*\\]\\]$", e, perl = TRUE))[[1]]
  if (length(m_var) >= 2) return(m_var[2])

  m_sq <- regmatches(e, regexec("^\\.data\\s*\\[\\[\\s*['\"]([^'\"]+)['\"]\\s*\\]\\]$", e, perl = TRUE))[[1]]
  if (length(m_sq) >= 2) return(paste0("\"", gsub("\"", "\\\\\"", m_sq[2]), "\""))

  m_bt <- regmatches(e, regexec("^`([^`]+)`$", e, perl = TRUE))[[1]]
  if (length(m_bt) >= 2) return(paste0("\"", gsub("\"", "\\\\\"", m_bt[2]), "\""))

  if (grepl("^[A-Za-z.][A-Za-z0-9._]*$", e, perl = TRUE)) {
    return(paste0("\"", e, "\""))
  }

  NULL
}

# Internal: parse ggplot(data, aes(...)) context from current code.
.extract_plot_context <- function(code) {
  xy <- .extract_main_xy_expr(code)
  if (is.null(xy)) return(NULL)

  data_expr <- xy$data_expr
  if (!grepl("^[A-Za-z.][A-Za-z0-9._]*$", data_expr, perl = TRUE)) return(NULL)

  x_idx <- .mapping_to_data_index(xy$x_expr)
  y_idx <- .mapping_to_data_index(xy$y_expr)
  if (is.null(x_idx) || is.null(y_idx)) return(NULL)

  size_m <- regmatches(code, regexec("geom_(?:point|jitter)\\([^\\)]*\\bsize\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)", code, perl = TRUE))[[1]]
  base_size <- if (length(size_m) >= 2) suppressWarnings(as.numeric(size_m[2])) else 3
  if (is.na(base_size)) base_size <- 3
  hi_size <- round(min(base_size + 1, 20), 2)

  list(
    data_expr = data_expr,
    x_idx = x_idx,
    y_idx = y_idx,
    hi_size = hi_size
  )
}

# Internal: add a robust highlight layer (never uses bare x/y in static params).
.inject_highlight_layer <- function(code, x_val, y_val, color_name = "red") {
  ctx <- .extract_plot_context(code)
  if (is.null(ctx)) return(NULL)

  layer <- paste0(
    "geom_point(data = ", ctx$data_expr, "[",
    ctx$data_expr, "[[", ctx$x_idx, "]] == ", x_val, " & ",
    ctx$data_expr, "[[", ctx$y_idx, "]] == ", y_val,
    ", , drop = FALSE], ",
    "color = \"", color_name, "\", size = ", ctx$hi_size, ") +"
  )

  if (grepl(layer, code, fixed = TRUE)) return(NULL)

  out <- sub("(geom_(?:point|jitter)\\([^\\)]*\\)\\s*\\+)", paste0("\\1\n  ", layer), code, perl = TRUE)
  if (identical(out, code)) NULL else out
}

# Internal: repair common unsafe LLM output patterns that break data masking.
.repair_generated_code <- function(code) {
  out <- code

  # Ensure helper formatters always resolve even when library(scales) is stripped.
  out <- gsub("(?<![:A-Za-z0-9_.])percent_format\\(", "scales::percent_format(", out, perl = TRUE)
  out <- gsub("(?<![:A-Za-z0-9_.])percent\\(", "scales::percent(", out, perl = TRUE)

  # Code editor runs with backend-injected `data`; strip ad-hoc CSV loading lines.
  out <- gsub(
    "(?m)^\\s*data\\s*<-\\s*utils::read\\.csv\\([^\\n]*\\)\\s*$",
    "# data is provided by backend runtime context",
    out,
    perl = TRUE
  )
  out <- gsub(
    "(?m)^\\s*data\\s*<-\\s*read\\.csv\\([^\\n]*\\)\\s*$",
    "# data is provided by backend runtime context",
    out,
    perl = TRUE
  )

  xy <- .extract_main_xy_expr(out)

  safe_x <- if (!is.null(xy$x_expr)) xy$x_expr else ".data[[x_col]]"
  safe_y <- if (!is.null(xy$y_expr)) xy$y_expr else ".data[[y_col]]"
  if (identical(trimws(safe_x), "x")) safe_x <- ".data[[x_col]]"
  if (identical(trimws(safe_y), "y")) safe_y <- ".data[[y_col]]"
  if (is.null(.mapping_to_data_index(safe_x))) safe_x <- ".data[[x_col]]"
  if (is.null(.mapping_to_data_index(safe_y))) safe_y <- ".data[[y_col]]"

  # Prevent "object 'x' not found": bare x/y in static geom params.
  for (a in c("shape", "size", "alpha", "color", "colour", "fill")) {
    pat <- paste0("(geom_(?:point|jitter)\\([^\\)]*?)\\b", a, "\\s*=\\s*(ifelse\\([^\\)]*\\b(?:x|y)\\b[^\\)]*\\))")
    rep <- paste0("\\1mapping = aes(", a, " = \\2)")
    out <- gsub(pat, rep, out, perl = TRUE)
  }

  # Common bad patch: geom_point(size = y) / geom_jitter(size = x)
  # Convert to data-masked aesthetic mapping.
  out <- gsub(
    "(geom_(?:point|jitter)\\([^\\)]*?)\\bsize\\s*=\\s*([A-Za-z.][A-Za-z0-9._]*)",
    paste0("\\1mapping = aes(size = ", safe_y, ")"),
    out, perl = TRUE
  )

  # Bad axis-label patches occasionally write labels into aes(...).
  # Example: aes(x = 'Time', y = y)  -> aes(x = x, y = y) + labs(x = "Time")
  x_lbl <- regmatches(out, regexec("aes\\(\\s*x\\s*=\\s*['\"]([^'\"]+)['\"]\\s*,\\s*y\\s*=\\s*([A-Za-z.`][A-Za-z0-9._`]*)\\s*\\)", out, perl = TRUE))[[1]]
  if (length(x_lbl) >= 3) {
    out <- sub(
      "aes\\(\\s*x\\s*=\\s*['\"][^'\"]+['\"]\\s*,\\s*y\\s*=\\s*([A-Za-z.`][A-Za-z0-9._`]*)\\s*\\)",
      paste0("aes(x = ", safe_x, ", y = \\1)"),
      out, perl = TRUE
    )
    out2 <- .upsert_labs_value(out, "x", x_lbl[2])
    if (!is.null(out2)) out <- out2
  }

  y_lbl <- regmatches(out, regexec("aes\\(\\s*x\\s*=\\s*([A-Za-z.`][A-Za-z0-9._`]*)\\s*,\\s*y\\s*=\\s*['\"]([^'\"]+)['\"]\\s*\\)", out, perl = TRUE))[[1]]
  if (length(y_lbl) >= 3) {
    out <- sub(
      "aes\\(\\s*x\\s*=\\s*([A-Za-z.`][A-Za-z0-9._`]*)\\s*,\\s*y\\s*=\\s*['\"][^'\"]+['\"]\\s*\\)",
      paste0("aes(x = \\1, y = ", safe_y, ")"),
      out, perl = TRUE
    )
    out2 <- .upsert_labs_value(out, "y", y_lbl[3])
    if (!is.null(out2)) out <- out2
  }

  y_bt <- regmatches(out, regexec("aes\\(\\s*x\\s*=\\s*([A-Za-z.`][A-Za-z0-9._`]*)\\s*,\\s*y\\s*=\\s*`([^`]+)`\\s*\\)", out, perl = TRUE))[[1]]
  if (length(y_bt) >= 3 && grepl("\\s", y_bt[3], perl = TRUE)) {
    out <- sub(
      "aes\\(\\s*x\\s*=\\s*([A-Za-z.`][A-Za-z0-9._`]*)\\s*,\\s*y\\s*=\\s*`[^`]+`\\s*\\)",
      paste0("aes(x = \\1, y = ", safe_y, ")"),
      out, perl = TRUE
    )
    out2 <- .upsert_labs_value(out, "y", y_bt[3])
    if (!is.null(out2)) out <- out2
  }

  # Bad title patch pattern: standalone ggtitle("...") outside ggplot '+' chain.
  # Normalize it into labs(title=...) on the main plot expression.
  title_dq <- regmatches(out, regexec("(?m)^\\s*ggtitle\\(\\s*\"([^\"]*)\"\\s*\\)\\s*$", out, perl = TRUE))[[1]]
  title_sq <- regmatches(out, regexec("(?m)^\\s*ggtitle\\(\\s*'([^']*)'\\s*\\)\\s*$", out, perl = TRUE))[[1]]
  title_val <- NULL
  if (length(title_dq) >= 2) title_val <- title_dq[2]
  if (is.null(title_val) && length(title_sq) >= 2) title_val <- title_sq[2]
  if (!is.null(title_val) && nzchar(trimws(title_val))) {
    out <- gsub("(?m)^\\s*ggtitle\\(\\s*(\"[^\"]*\"|'[^']*')\\s*\\)\\s*\\n?", "", out, perl = TRUE)
    out2 <- .upsert_labs_title(out, title_val)
    if (!is.null(out2)) out <- out2
  }

  # Normalize invalid / unknown theme calls from loose natural-language outputs.
  out <- gsub("theme_[^[:ascii:][:space:]\\(\\)]+\\(\\)", "theme_minimal()", out, perl = TRUE)
  valid_themes <- c(
    "theme_gray()", "theme_grey()", "theme_bw()", "theme_linedraw()",
    "theme_light()", "theme_dark()", "theme_minimal()", "theme_classic()",
    "theme_void()", "theme_test()"
  )
  theme_hits <- unique(regmatches(out, gregexpr("theme_[A-Za-z0-9_]+\\(\\)", out, perl = TRUE))[[1]])
  if (length(theme_hits) > 0 && !identical(theme_hits, character(0))) {
    for (th in theme_hits) {
      if (!(th %in% valid_themes)) {
        out <- gsub(th, "theme_minimal()", out, fixed = TRUE)
      }
    }
  }

  out <- gsub("\\(\\s*,", "(", out, perl = TRUE)
  out <- gsub(",\\s*\\)", ")", out, perl = TRUE)
  out
}


# 鈹€鈹€ build_patch_prompt 鈥?Layer 2 LLM prompt 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Returns the complete prompt to send to the LLM for code patching.
# The LLM must return ONLY a JSON object with a "patches" array.

build_patch_prompt <- function(user_text, code, data_cols = character(0)) {
  col_line <- if (length(data_cols) > 0)
    paste0("Available data columns: ", paste(data_cols, collapse = ", "), "\n")
  else ""

  paste0(
    "You are a precise R code editor. Your ONLY job is to make minimal changes to the code.\n",
    "Return a JSON object with a \"patches\" array. Each element has exactly two string fields:\n",
    "  search  - a substring that appears exactly once in the current code\n",
    "  replace - the text to substitute in its place\n",
    "Example: {\"patches\": [{\"search\": \"alpha = 0.5\", \"replace\": \"alpha = 0.8\"}]}\n\n",
    "Rules:\n",
    "- Each 'search' must match exactly once in the code.\n",
    "- Keep changes minimal: touch only what the user asked for.\n",
    "- Preserve indentation and ggplot2 '+' chaining.\n",
    "- Never ask follow-up questions; pick reasonable defaults when details are missing.\n",
    "- Never put x/y expressions in static geom args (e.g. shape = ifelse(x...)). Use mapping = aes(...) or a separate highlight layer.\n",
    "- If user asks to rename axis labels, update labs(x=..., y=...) and do NOT change aes(x=..., y=...) variable mapping.\n",
    "- Use only packages already loaded (ggplot2, dplyr, tidyr).\n",
    col_line,
    "\nCurrent R code:\n```r\n", code, "\n```\n\n",
    "User request: ", user_text
  )
}


# 鈹€鈹€ parse_patch_response 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Parses the JSON patch response returned by the LLM.
# Returns list(ok, patches, raw).

parse_patch_response <- function(response_text) {
  if (is.null(response_text) || !nzchar(trimws(response_text))) {
    return(list(ok = FALSE, patches = NULL, raw = ""))
  }

  # With JSON mode enabled on the API side the response is guaranteed to be
  # pure JSON — no markdown fences, no prose.  We therefore parse strictly:
  # the trimmed response must begin with '{'.
  clean <- trimws(response_text)
  if (!startsWith(clean, "{")) {
    return(list(ok = FALSE, patches = NULL, raw = response_text))
  }

  parsed <- tryCatch(jsonlite::fromJSON(clean, simplifyVector = FALSE),
                     error = function(e) NULL)

  if (is.null(parsed) || is.null(parsed$patches)) {
    return(list(ok = FALSE, patches = NULL, raw = response_text))
  }

  patches <- parsed$patches
  # Each element must have search + replace strings
  valid <- Filter(function(p) {
    is.list(p) && is.character(p$search) && is.character(p$replace)
  }, patches)

  if (length(valid) == 0) {
    return(list(ok = FALSE, patches = NULL, raw = response_text))
  }

  list(ok = TRUE, patches = valid, raw = response_text)
}
