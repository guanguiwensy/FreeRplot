# =============================================================================
# File   : R/core/ai_local_patch_parser.R
# Purpose: Local rule-based parsing for patch-like chart tuning commands.
# =============================================================================

build_ai_local_patch_parser <- function(input, session, rv, module_name = "mod_ai_chat") {
  extract_local_patch <- function(user_text, chart_id) {
    txt_vec <- as.character(user_text %||% "")
    if (!is.character(txt_vec) || length(txt_vec) == 0) return(NULL)
    txt <- trimws(txt_vec[[1]])
    if (is.na(txt) || !nzchar(txt)) return(NULL)

    common <- list()
    opt <- list()
    hits <- character(0)

    .scalar_chr <- function(x, default = "") {
      if (is.null(x) || length(x) == 0) return(default)
      out <- trimws(as.character(x[[1]] %||% default))
      if (!length(out) || is.na(out) || !nzchar(out)) default else out
    }

    .rule <- function(key, default = "") {
      .scalar_chr(ai_match_rule_string(c("mod_ai_chat", "local_patch", key), default = default), default = default)
    }

    .safe_regexec <- function(pat, s) {
      if (!is.character(pat) || length(pat) != 1 || !nzchar(pat)) return(character(0))
      out <- tryCatch(
        regmatches(s, regexec(pat, s, perl = TRUE, ignore.case = TRUE))[[1]],
        error = function(e) character(0)
      )
      if (is.null(out)) character(0) else out
    }

    .safe_grepl <- function(pat, s, fixed = FALSE) {
      if (!is.character(pat) || length(pat) != 1 || !nzchar(pat)) return(FALSE)
      if (isTRUE(fixed)) {
        return(isTRUE(tryCatch(
          grepl(pat, s, fixed = TRUE),
          error = function(e) FALSE
        )))
      }
      isTRUE(tryCatch(
        grepl(pat, s, perl = TRUE, ignore.case = TRUE),
        error = function(e) FALSE
      ))
    }

    .capture1 <- function(key) {
      pat <- .rule(key)
      if (!is.character(pat) || length(pat) != 1 || !nzchar(pat)) return(NULL)
      m <- .safe_regexec(pat, txt)
      if (length(m) >= 2) trimws(m[2]) else NULL
    }

    .capture2num <- function(key) {
      pat <- .rule(key)
      if (!is.character(pat) || length(pat) != 1 || !nzchar(pat)) return(NULL)
      m <- .safe_regexec(pat, txt)
      if (length(m) >= 3) {
        a <- suppressWarnings(as.numeric(m[2]))
        b <- suppressWarnings(as.numeric(m[3]))
        if (is.finite(a) && is.finite(b)) return(list(a = a, b = b))
      }
      NULL
    }

    .match_rule <- function(key) {
      pat <- .rule(key)
      .safe_grepl(pat, txt)
    }

    .is_scalar_finite <- function(x) {
      is.numeric(x) && length(x) == 1 && !is.na(x) && is.finite(x)
    }

    title_val <- .capture1("plot_title")
    if (!is.null(title_val) && nzchar(title_val)) {
      common$plot_title <- title_val
      hits <- c(hits, "plot_title")
    }

    x_label_val <- .capture1("x_label")
    if (!is.null(x_label_val) && nzchar(x_label_val)) {
      common$x_label <- x_label_val
      hits <- c(hits, "x_label")
    }

    y_label_val <- .capture1("y_label")
    if (!is.null(y_label_val) && nzchar(y_label_val)) {
      common$y_label <- y_label_val
      hits <- c(hits, "y_label")
    }

    width_val <- suppressWarnings(as.numeric(.capture1("plot_width_in")))
    if (.is_scalar_finite(width_val)) {
      common$plot_width_in <- width_val
      hits <- c(hits, "plot_width_in")
    }

    height_val <- suppressWarnings(as.numeric(.capture1("plot_height_in")))
    if (.is_scalar_finite(height_val)) {
      common$plot_height_in <- height_val
      hits <- c(hits, "plot_height_in")
    }

    dpi_val <- suppressWarnings(as.numeric(.capture1("plot_dpi")))
    if (.is_scalar_finite(dpi_val)) {
      common$plot_dpi <- dpi_val
      hits <- c(hits, "plot_dpi")
    }

    xr <- .capture2num("x_range")
    if (!is.null(xr)) {
      common$x_range_mode <- "manual"
      common$x_min <- xr$a
      common$x_max <- xr$b
      hits <- c(hits, "x_range")
    }

    yr <- .capture2num("y_range")
    if (!is.null(yr)) {
      common$y_range_mode <- "manual"
      common$y_min <- yr$a
      common$y_max <- yr$b
      hits <- c(hits, "y_range")
    }

    if (.match_rule("x_auto_range")) {
      common$x_range_mode <- "auto"
      hits <- c(hits, "x_range_mode")
    }
    if (.match_rule("y_auto_range")) {
      common$y_range_mode <- "auto"
      hits <- c(hits, "y_range_mode")
    }

    for (nm in names(CHART_THEMES %||% list())) {
      if (.safe_grepl(nm, txt, fixed = TRUE)) {
        common$chart_theme <- nm
        hits <- c(hits, "chart_theme")
        break
      }
    }
    for (nm in names(COLOR_PALETTES %||% list())) {
      if (.safe_grepl(nm, txt, fixed = TRUE)) {
        common$color_palette <- nm
        hits <- c(hits, "color_palette")
        break
      }
    }

    defs <- tryCatch(CHARTS[[chart_id]]$options_def %||% list(), error = function(e) list())
    has_opt <- function(opt_id) any(vapply(defs, function(d) identical(d$id, opt_id), logical(1)))

    if (has_opt("alpha")) {
      alpha_val <- suppressWarnings(as.numeric(.capture1("alpha")))
      if (.is_scalar_finite(alpha_val)) {
        opt$alpha <- alpha_val
        hits <- c(hits, "opt_alpha")
      }
    }

    if (has_opt("point_size")) {
      psize_val <- suppressWarnings(as.numeric(.capture1("point_size")))
      if (.is_scalar_finite(psize_val)) {
        opt$point_size <- psize_val
        hits <- c(hits, "opt_point_size")
      }
    }

    bool_on <- .rule("bool_on")
    bool_off <- .rule("bool_off")
    has_bool_on <- is.character(bool_on) && length(bool_on) == 1 && nzchar(bool_on)
    has_bool_off <- is.character(bool_off) && length(bool_off) == 1 && nzchar(bool_off)

    if (has_opt("show_smooth") && .match_rule("smooth_trigger")) {
      if (has_bool_on && .safe_grepl(bool_on, txt)) {
        opt$show_smooth <- TRUE
        hits <- c(hits, "opt_show_smooth")
      } else if (has_bool_off && .safe_grepl(bool_off, txt)) {
        opt$show_smooth <- FALSE
        hits <- c(hits, "opt_show_smooth")
      }
    }

    if (has_opt("show_labels") && .match_rule("labels_trigger")) {
      if (has_bool_on && .safe_grepl(bool_on, txt)) {
        opt$show_labels <- TRUE
        hits <- c(hits, "opt_show_labels")
      } else if (has_bool_off && .safe_grepl(bool_off, txt)) {
        opt$show_labels <- FALSE
        hits <- c(hits, "opt_show_labels")
      }
    }

    if (length(hits) == 0) return(NULL)
    list(common_patch = common, options_patch = opt, hits = unique(hits))
  }

  list(extract_local_patch = extract_local_patch)
}
