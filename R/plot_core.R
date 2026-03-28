# =============================================================================
# File   : R/plot_core.R
# Purpose: Shared plotting primitives used by every chart's plot_fn.
#          Provides colour palettes, ggplot2 themes, axis-limit helpers, and
#          the top-level generate_plot() dispatcher.
#
# Globals exported to the app environment:
#   COLOR_PALETTES  named list of hex-colour vectors (length 7 each)
#   CHART_THEMES    named list of ggplot2 theme functions
#
# Functions:
#   get_palette(name, n)
#     Returns n colours from the named palette, interpolated if n > 7.
#     Parameters: name [chr] palette name; n [int] number of colours needed.
#
#   palette_values_for_levels(levels, palette_name, overrides)
#     Returns a named colour vector for discrete levels.  Applies explicit
#     per-value overrides on top of the selected base palette.
#
#   candidate_palette_columns(data)
#     Returns candidate discrete columns for the palette override editor.
#
#   palette_override_input_id(target, value)
#     Builds a stable Shiny input id for one color override row.
#
#   palette_values_for_column(data, column, options, levels = NULL, palette_name = NULL)
#     Returns a named colour vector for one mapped column, automatically
#     applying local overrides only when the requested column matches the active
#     override target.
#
#   infer_palette_target(chart_id, data)
#     Guesses which data column should drive the palette override editor for
#     the active chart and current dataset.  Returns a column name or NULL.
#
#   safe_limits(min_v, max_v)
#     Validates a numeric range and returns c(min, max) or NULL if invalid.
#     Parameters: min_v, max_v [num | chr] — coerced to numeric internally.
#
#   apply_axis_limits(p, options)
#     Appends coord_cartesian() to p when manual range mode is active.
#     Parameters: p [ggplot]; options [list] with x/y_range_mode, x/y_min/max.
#
#   apply_theme(p, options)
#     Applies axis limits, selected theme function, and labs() to the plot.
#     Parameters: p [ggplot]; options [list] with theme, title, x_label, y_label.
#
#   has_col(data, col)
#     Returns TRUE if col exists in data and is not all-NA.
#     Parameters: data [data.frame]; col [chr] column name.
#
#   .bar_orient(p, orient)
#     Conditionally flips coordinates for horizontal bar charts.
#
#   .bar_label_params(orient)
#     Returns list(vjust, hjust) appropriate for the bar orientation.
#
#   generate_plot(chart_id, data, options)
#     Dispatches to CHARTS[[chart_id]]$plot_fn(data, options).
#     Parameters: chart_id [chr]; data [data.frame]; options [list].
#
#   build_plot_script(chart_id, data, options)
#     Builds a standalone R script that recreates the current chart with the
#     exact data, options, helper functions, and plot_fn currently in use.
#
#   execute_plot_script(script)
#     Evaluates one generated plot script in an isolated environment and
#     returns the resulting plot object.
#
#   build_r_code_view_ui(code)
#     Renders a line-numbered, syntax-highlighted code view for the R Code tab.
# =============================================================================

COLOR_PALETTES <- list(
  "\u9ed8\u8ba4"   = c("#4ECDC4", "#FF6B6B", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F", "#C3A6FF"),
  "\u5546\u52a1\u84dd" = c("#003f5c", "#2f4b7c", "#665191", "#a05195", "#d45087", "#f95d6a", "#ff7c43"),
  "\u81ea\u7136\u7eff" = c("#264653", "#2a9d8f", "#57cc99", "#80b918", "#e9c46a", "#f4a261", "#e76f51"),
  "\u6d3b\u529b\u6a59" = c("#d62828", "#e85d04", "#f48c06", "#faa307", "#ffba08", "#e9c46a", "#a8dadc"),
  "\u7c89\u7d2b\u7cfb" = c("#7b2d8b", "#9b5de5", "#f15bb5", "#fee440", "#00bbf9", "#00f5d4", "#fb5607")
)

CHART_THEMES <- list(
  "\u7b80\u6d01\u767d" = ggplot2::theme_minimal,
  "\u7ecf\u5178"       = ggplot2::theme_classic,
  "\u7070\u8272"       = ggplot2::theme_gray,
  "\u9ed1\u767d"       = ggplot2::theme_bw
)

get_palette <- function(name, n = 7) {
  pal <- COLOR_PALETTES[[name %||% "\u9ed8\u8ba4"]]
  if (is.null(pal)) pal <- COLOR_PALETTES[["\u9ed8\u8ba4"]]
  if (n <= length(pal)) pal[seq_len(n)] else grDevices::colorRampPalette(pal)(n)
}

palette_values_for_levels <- function(levels, palette_name = "\u9ed8\u8ba4", overrides = list()) {
  levels <- unique(as.character(levels %||% character(0)))
  if (length(levels) == 0) return(setNames(character(0), character(0)))

  values <- get_palette(palette_name, length(levels))
  names(values) <- levels

  if (is.list(overrides) && length(overrides) > 0) {
    override_names <- names(overrides)
    if (!is.null(override_names)) {
      for (nm in intersect(levels, override_names)) {
        val <- as.character(overrides[[nm]])[1]
        if (nzchar(val)) values[[nm]] <- val
      }
    }
  }

  values
}

candidate_palette_columns <- function(data) {
  if (is.null(data) || ncol(data) == 0) return(character(0))

  names(data)[vapply(data, function(col) {
    is.factor(col) || is.character(col) || is.logical(col)
  }, logical(1))]
}

palette_override_input_id <- function(target, value) {
  encode <- function(x) {
    raw <- charToRaw(enc2utf8(as.character(x %||% "")))
    paste0(sprintf("%02x", as.integer(raw)), collapse = "")
  }

  paste0("color_override_", encode(target), "_", encode(value))
}

palette_values_for_column <- function(data, column, options, levels = NULL, palette_name = NULL) {
  if (is.null(levels)) {
    if (is.null(data) || !(column %in% names(data))) return(setNames(character(0), character(0)))
    levels <- unique(as.character(data[[column]]))
  }

  palette_name <- palette_name %||%
    options$color_palette %||%
    options$palette %||%
    names(COLOR_PALETTES)[1]

  color_settings <- options$color_settings %||% list()
  target_column <- color_settings$target_column %||% options$palette_target_column %||% NULL
  overrides <- if (!is.null(target_column) && identical(column, target_column)) {
    color_settings$overrides %||% options$palette_overrides %||% list()
  } else {
    list()
  }

  palette_values_for_levels(levels, palette_name, overrides)
}

infer_palette_target <- function(chart_id, data) {
  if (is.null(data) || ncol(data) == 0) return(NULL)

  cols <- names(data)
  has_col_name <- function(nm) nm %in% cols

  discrete_candidates <- cols[vapply(data, function(col) {
    is.factor(col) || is.character(col) || is.logical(col)
  }, logical(1))]

  if (chart_id %in% c("scatter_basic", "scatter_grouped", "scatter_regression",
                      "scatter_jitter", "scatter_bubble", "scatter",
                      "line", "area", "stacked_area")) {
    if (ncol(data) >= 3) return(cols[3])
    return(NULL)
  }

  if (chart_id %in% c("bar_grouped", "bar_stacked", "bar_filled",
                      "bar_grouped_stacked", "bar_dotplot")) {
    if (ncol(data) >= 3) return(cols[3])
    return(NULL)
  }

  if (identical(chart_id, "bar_errorbar")) {
    if (ncol(data) >= 3 && !cols[3] %in% c("ymin", "ymax", "sd", "se")) return(cols[3])
    return(NULL)
  }

  if (chart_id %in% c("bar", "bar_facet", "bar_sorted", "lollipop", "pie", "radar")) {
    return(cols[1])
  }

  if (chart_id %in% c("boxplot", "violin", "histogram")) {
    if (ncol(data) >= 1) return(cols[1])
    return(NULL)
  }

  if (chart_id %in% c("density", "ridgeline")) {
    if (ncol(data) >= 2) return(cols[2])
    return(NULL)
  }

  if (identical(chart_id, "treemap")) {
    if (has_col_name("parent")) return("parent")
    if (has_col_name("label")) return("label")
    return(cols[1])
  }

  if (length(discrete_candidates) > 0) discrete_candidates[1] else NULL
}

safe_limits <- function(min_v, max_v) {
  if (is.null(min_v) || is.null(max_v)) return(NULL)
  min_v <- suppressWarnings(as.numeric(min_v))
  max_v <- suppressWarnings(as.numeric(max_v))
  if (is.na(min_v) || is.na(max_v)) return(NULL)
  if (!is.finite(min_v) || !is.finite(max_v)) return(NULL)
  if (max_v <= min_v) return(NULL)
  c(min_v, max_v)
}

apply_axis_limits <- function(p, options) {
  xlim <- NULL
  ylim <- NULL

  if (identical(options$x_range_mode %||% "auto", "manual") && isTRUE(options$x_is_numeric)) {
    xlim <- safe_limits(options$x_min, options$x_max)
  }
  if (identical(options$y_range_mode %||% "auto", "manual") && isTRUE(options$y_is_numeric)) {
    ylim <- safe_limits(options$y_min, options$y_max)
  }

  if (is.null(xlim) && is.null(ylim)) return(p)
  p + ggplot2::coord_cartesian(xlim = xlim, ylim = ylim)
}

apply_theme <- function(p, options) {
  theme_fn <- CHART_THEMES[[options$theme %||% "\u7b80\u6d01\u767d"]]
  if (is.null(theme_fn)) theme_fn <- ggplot2::theme_minimal

  p <- apply_axis_limits(p, options)

  p +
    theme_fn() +
    ggplot2::labs(
      title = options$title   %||% NULL,
      x     = options$x_label %||% NULL,
      y     = options$y_label %||% NULL
    ) +
    ggplot2::theme(
      plot.title      = ggplot2::element_text(size = 14, face = "bold",
                                              hjust = 0.5, margin = ggplot2::margin(b = 10)),
      axis.title      = ggplot2::element_text(size = 11),
      legend.position = "bottom",
      plot.margin     = ggplot2::margin(15, 15, 15, 15)
    )
}

has_col <- function(data, col) col %in% names(data) && !all(is.na(data[[col]]))

.bar_orient <- function(p, orient) {
  if (identical(orient, "horizontal")) p + ggplot2::coord_flip() else p
}

.bar_label_params <- function(orient) {
  if (identical(orient, "horizontal")) {
    list(vjust = 0.5, hjust = -0.2)
  } else {
    list(vjust = -0.4, hjust = 0.5)
  }
}

generate_plot <- function(chart_id, data, options = list()) {
  if (is.null(data) || nrow(data) == 0) stop("\u6570\u636e\u4e3a\u7a7a\uff0c\u8bf7\u5148\u5f55\u5165\u6570\u636e\u3002")
  fn <- CHARTS[[chart_id]]$plot_fn
  if (!is.function(fn)) stop(paste("\u672a\u6ce8\u518c\u7684\u56fe\u8868\u7c7b\u578b:", chart_id))
  fn(data, options)
}

.as_r_assignment_name <- function(name) {
  if (make.names(name) == name && !grepl("\\.", name, fixed = TRUE)) {
    name
  } else {
    paste0("`", name, "`")
  }
}

.dput_as_assignment <- function(name, value) {
  paste0(
    .as_r_assignment_name(name),
    " <- ",
    paste(capture.output(dput(value)), collapse = "\n")
  )
}

.deparse_function_assignment <- function(name, fn) {
  paste0(
    .as_r_assignment_name(name),
    " <- ",
    paste(deparse(fn, width.cutoff = 500L), collapse = "\n")
  )
}

.theme_registry_code <- function() {
  theme_map <- c(
    "\u7b80\u6d01\u767d" = "theme_minimal",
    "\u7ecf\u5178" = "theme_classic",
    "\u7070\u8272" = "theme_gray",
    "\u9ed1\u767d" = "theme_bw"
  )

  paste(
    "CHART_THEMES <- list(",
    paste(sprintf("  \"%s\" = ggplot2::%s", names(theme_map), unname(theme_map)), collapse = ",\n"),
    ")",
    sep = "\n"
  )
}

.required_packages_for_script <- function(plot_fn) {
  fn_text <- paste(deparse(plot_fn, width.cutoff = 500L), collapse = "\n")
  refs <- regmatches(fn_text, gregexpr("([A-Za-z][A-Za-z0-9.]*)::", fn_text, perl = TRUE))[[1]]
  pkgs <- sub("::$", "", refs)
  unique(c("ggplot2", sort(pkgs)))
}

.plot_script_helper_bundle <- function() {
  helper_lines <- c(
    .dput_as_assignment("COLOR_PALETTES", COLOR_PALETTES),
    .theme_registry_code(),
    .deparse_function_assignment("%||%", `%||%`),
    .deparse_function_assignment("get_palette", get_palette),
    .deparse_function_assignment("palette_values_for_levels", palette_values_for_levels),
    .deparse_function_assignment("palette_values_for_column", palette_values_for_column),
    .deparse_function_assignment("safe_limits", safe_limits),
    .deparse_function_assignment("apply_axis_limits", apply_axis_limits),
    .deparse_function_assignment("apply_theme", apply_theme),
    .deparse_function_assignment("has_col", has_col),
    .deparse_function_assignment(".bar_orient", .bar_orient),
    .deparse_function_assignment(".bar_label_params", .bar_label_params)
  )

  paste(helper_lines, collapse = "\n\n")
}

build_plot_script <- function(chart_id, data, options = list()) {
  chart <- CHARTS[[chart_id]]
  if (is.null(chart) || !is.function(chart$plot_fn)) {
    stop(paste("\u672a\u6ce8\u518c\u7684\u56fe\u8868\u7c7b\u578b:", chart_id))
  }

  pkg_comment <- paste(.required_packages_for_script(chart$plot_fn), collapse = ", ")

  sections <- c(
    "# =============================================================================",
    "# Synchronized R code export",
    "# Generated from the same plot function path used by the current preview.",
    paste0("# Chart ID: ", chart_id),
    paste0("# Required packages: ", pkg_comment),
    "# =============================================================================",
    .dput_as_assignment("data", data),
    .dput_as_assignment("options", options),
    .plot_script_helper_bundle(),
    .deparse_function_assignment("plot_fn", chart$plot_fn),
    paste(
      "p <- plot_fn(data, options)",
      "",
      "render_now <- getOption(\"freerplot_render_on_run\", interactive())",
      "if (isTRUE(render_now)) {",
      "  if (inherits(p, \"circos_plot\")) {",
      "    p$draw()",
      "  } else {",
        "    print(p)",
      "  }",
      "}",
      sep = "\n"
    )
  )

  paste(sections, collapse = "\n\n")
}

execute_plot_script <- function(script) {
  env <- new.env(parent = baseenv())
  old_opts <- options(freerplot_render_on_run = FALSE)
  on.exit(options(old_opts), add = TRUE)

  eval(parse(text = script, keep.source = FALSE), envir = env)

  if (!exists("p", envir = env, inherits = FALSE)) {
    stop("Generated script did not create plot object `p`.")
  }

  list(
    plot = get("p", envir = env, inherits = FALSE),
    env = env
  )
}

.code_token_css_class <- function(token, text) {
  if (identical(token, "COMMENT")) return("code-token-comment")
  if (identical(token, "STR_CONST")) return("code-token-string")
  if (identical(token, "NUM_CONST")) return("code-token-number")
  if (token %in% c("FUNCTION", "IF", "ELSE", "FOR", "WHILE", "REPEAT", "IN", "NEXT", "BREAK")) {
    return("code-token-keyword")
  }
  if (identical(token, "SYMBOL_FUNCTION_CALL")) return("code-token-function")
  if (identical(token, "SYMBOL_PACKAGE")) return("code-token-package")
  if (token %in% c("SPECIAL", "LEFT_ASSIGN", "RIGHT_ASSIGN", "EQ_ASSIGN", "EQ_SUB", "NS_GET", "NS_GET_INT")) {
    return("code-token-operator")
  }
  if (identical(token, "NULL_CONST") || text %in% c("TRUE", "FALSE", "NULL", "NA", "NA_character_", "NA_real_", "NA_integer_", "NA_complex_")) {
    return("code-token-keyword")
  }
  NULL
}

.build_r_code_line_html <- function(lines, tokens, line_no) {
  line <- lines[[line_no]]
  if (!nchar(line)) return("&nbsp;")

  line_tokens <- tokens[tokens$line1 == line_no & tokens$line2 == line_no, , drop = FALSE]
  if (!nrow(line_tokens)) return(htmltools::htmlEscape(line))

  line_tokens <- line_tokens[order(line_tokens$col1, line_tokens$col2), , drop = FALSE]
  cursor <- 1L
  chunks <- character(0)

  for (idx in seq_len(nrow(line_tokens))) {
    tok <- line_tokens[idx, ]
    if (tok$col1 > cursor) {
      chunks <- c(chunks, htmltools::htmlEscape(substr(line, cursor, tok$col1 - 1L)))
    }

    token_text <- substr(line, tok$col1, tok$col2)
    css_class <- .code_token_css_class(tok$token, tok$text)
    escaped <- htmltools::htmlEscape(token_text)

    if (is.null(css_class)) {
      chunks <- c(chunks, escaped)
    } else {
      chunks <- c(chunks, sprintf("<span class=\"%s\">%s</span>", css_class, escaped))
    }

    cursor <- tok$col2 + 1L
  }

  if (cursor <= nchar(line)) {
    chunks <- c(chunks, htmltools::htmlEscape(substr(line, cursor, nchar(line))))
  }

  paste(chunks, collapse = "")
}

build_r_code_view_ui <- function(code) {
  lines <- strsplit(code %||% "", "\n", fixed = TRUE)[[1]]
  if (length(lines) == 0) lines <- ""

  parse_tokens <- tryCatch({
    parsed <- utils::getParseData(parse(text = code, keep.source = TRUE))
    parsed[parsed$terminal, c("line1", "col1", "line2", "col2", "token", "text"), drop = FALSE]
  }, error = function(e) NULL)

  rendered_lines <- lapply(seq_along(lines), function(i) {
    line_html <- if (is.null(parse_tokens)) {
      if (nzchar(lines[[i]])) htmltools::htmlEscape(lines[[i]]) else "&nbsp;"
    } else {
      .build_r_code_line_html(lines, parse_tokens, i)
    }

    div(
      class = "code-line-row",
      span(class = "code-line-number", sprintf("%d", i)),
      tags$code(class = "code-line-content", HTML(line_html))
    )
  })

  div(
    class = "code-lines-shell",
    div(class = "code-lines", rendered_lines)
  )
}
