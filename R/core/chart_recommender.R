# =============================================================================
# File   : R/core/chart_recommender.R
# Purpose: Recommend charts by combining:
#            1) data profile summary
#            2) chart capability JSON registry
#
# Exports:
#   profile_data_for_recommend(data)
#   recommend_charts_for_data(data, registry = CHART_CAP_REG, charts = CHARTS, data_summary = NULL)
# =============================================================================

.rec_as_chr <- function(x, default = "") {
  v <- x %||% default
  if (length(v) == 0 || is.null(v)) return(default)
  as.character(v)[1]
}

.rec_compact <- function(x) {
  x <- x[!is.na(x)]
  x <- trimws(as.character(x))
  x[nzchar(x)]
}

.rec_to_vec <- function(x) {
  if (is.null(x) || length(x) == 0) return(character(0))
  if (is.list(x)) return(.rec_compact(unlist(x, use.names = FALSE)))
  .rec_compact(as.character(x))
}

profile_data_for_recommend <- function(data) {
  if (is.null(data) || !is.data.frame(data) || ncol(data) == 0) {
    return(list(
      rows = 0L,
      cols = 0L,
      columns = list(),
      col_names = character(0),
      numeric_cols = character(0),
      datetime_cols = character(0),
      categorical_cols = character(0),
      text_cols = character(0),
      binary_cols = character(0)
    ))
  }

  df <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  n <- nrow(df)

  infer_dtype <- function(v) {
    if (inherits(v, c("Date", "POSIXct", "POSIXt"))) return("datetime")
    if (is.numeric(v)) return("numeric")
    if (is.factor(v) || is.logical(v)) return("categorical")

    if (is.character(v)) {
      vals <- v[!is.na(v) & nzchar(trimws(v))]
      if (length(vals) == 0) return("text")

      num_like <- suppressWarnings(as.numeric(vals))
      num_ratio <- mean(is.finite(num_like))
      if (is.finite(num_ratio) && num_ratio >= 0.95) return("numeric")

      time_like <- tryCatch(
        suppressWarnings(as.POSIXct(vals, tz = "UTC")),
        error = function(e) as.POSIXct(rep(NA_character_, length(vals)), tz = "UTC")
      )
      time_ratio <- mean(!is.na(time_like))
      if (is.finite(time_ratio) && time_ratio >= 0.8) return("datetime")

      uniq <- length(unique(vals))
      if (uniq <= min(25L, max(3L, floor(length(vals) * 0.2)))) return("categorical")
      return("text")
    }

    "any"
  }

  col_profiles <- lapply(names(df), function(nm) {
    v <- df[[nm]]
    dtype <- infer_dtype(v)
    missing <- sum(is.na(v))
    uniq <- length(unique(v[!is.na(v)]))
    list(
      name = nm,
      dtype = dtype,
      missing = as.integer(missing),
      missing_rate = if (n > 0) as.numeric(missing / n) else 0,
      unique = as.integer(uniq)
    )
  })
  names(col_profiles) <- names(df)

  cols_by <- function(dtype) {
    names(Filter(function(x) identical(x$dtype, dtype), col_profiles))
  }

  list(
    rows = as.integer(nrow(df)),
    cols = as.integer(ncol(df)),
    columns = col_profiles,
    col_names = names(df),
    numeric_cols = cols_by("numeric"),
    datetime_cols = cols_by("datetime"),
    categorical_cols = unique(c(cols_by("categorical"), cols_by("text"))),
    text_cols = cols_by("text"),
    binary_cols = names(Filter(function(x) isTRUE(x$unique == 2L), col_profiles))
  )
}

.status_rank <- function(status) {
  switch(
    .rec_as_chr(status, "unknown"),
    recommended = 3L,
    available = 2L,
    not_recommended = 1L,
    0L
  )
}

.summary_cols_by_dtype <- function(summary, dtype) {
  if (identical(dtype, "numeric")) return(summary$numeric_cols %||% character(0))
  if (identical(dtype, "datetime")) return(summary$datetime_cols %||% character(0))
  if (identical(dtype, "categorical")) return(summary$categorical_cols %||% character(0))
  summary$col_names %||% character(0)
}

.auto_mapping_from_requirements <- function(summary, req) {
  used <- character(0)
  mapping <- list(
    x = NA_character_,
    y = NA_character_,
    group = NA_character_,
    size = NA_character_,
    label = NA_character_
  )

  pick_col <- function(dtype = "any", fallback = character(0)) {
    pool <- setdiff(.summary_cols_by_dtype(summary, dtype), used)
    pool <- unique(c(pool, setdiff(fallback, used)))
    if (length(pool) == 0) return(NA_character_)
    pool[1]
  }

  assign_role <- function(role, dtype) {
    key <- tolower(.rec_as_chr(role, ""))
    if (!(key %in% names(mapping))) return(invisible(NULL))
    if (!is.na(mapping[[key]]) && nzchar(mapping[[key]])) return(invisible(NULL))

    value <- pick_col(dtype)
    mapping[[key]] <<- value
    if (!is.na(value) && nzchar(value)) used <<- c(used, value)
  }

  req_cols <- req$required_columns %||% list()
  opt_cols <- req$optional_columns %||% list()

  for (spec in req_cols) assign_role(spec$role, spec$dtype %||% "any")
  for (spec in opt_cols) assign_role(spec$role, spec$dtype %||% "any")

  if (is.na(mapping$x) || !nzchar(mapping$x)) {
    mapping$x <- pick_col("numeric", fallback = summary$datetime_cols %||% character(0))
  }
  if (is.na(mapping$y) || !nzchar(mapping$y)) {
    mapping$y <- pick_col("numeric")
  }
  if ((is.na(mapping$group) || !nzchar(mapping$group)) && length(summary$categorical_cols %||% character(0)) > 0) {
    mapping$group <- summary$categorical_cols[[1]]
  }
  if ((is.na(mapping$label) || !nzchar(mapping$label)) && length(summary$text_cols %||% character(0)) > 0) {
    mapping$label <- summary$text_cols[[1]]
  }
  if ((is.na(mapping$size) || !nzchar(mapping$size)) && length(summary$numeric_cols %||% character(0)) >= 3) {
    mapping$size <- summary$numeric_cols[[3]]
  }

  mapping
}

.evaluate_capability_fit <- function(cap, summary) {
  req <- cap$data_requirements %||% list()

  min_rows <- suppressWarnings(as.integer(req$min_rows %||% 1L))
  min_cols <- suppressWarnings(as.integer(req$min_columns %||% 1L))
  min_num <- suppressWarnings(as.integer(req$min_numeric_columns %||% 0L))
  min_dt <- suppressWarnings(as.integer(req$min_datetime_columns %||% 0L))
  min_cat <- suppressWarnings(as.integer(req$min_categorical_columns %||% 0L))

  if (is.na(min_rows)) min_rows <- 1L
  if (is.na(min_cols)) min_cols <- 1L
  if (is.na(min_num)) min_num <- 0L
  if (is.na(min_dt)) min_dt <- 0L
  if (is.na(min_cat)) min_cat <- 0L

  blockers <- character(0)
  notes <- character(0)
  score <- 70L

  if (summary$rows < min_rows) blockers <- c(blockers, sprintf("Need at least %d rows.", min_rows))
  if (summary$cols < min_cols) blockers <- c(blockers, sprintf("Need at least %d columns.", min_cols))
  if (length(summary$numeric_cols %||% character(0)) < min_num) blockers <- c(blockers, sprintf("Need at least %d numeric columns.", min_num))
  if (length(summary$datetime_cols %||% character(0)) < min_dt) blockers <- c(blockers, sprintf("Need at least %d datetime columns.", min_dt))
  if (length(summary$categorical_cols %||% character(0)) < min_cat) blockers <- c(blockers, sprintf("Need at least %d categorical/text columns.", min_cat))

  req_cols <- req$required_columns %||% list()
  for (spec in req_cols) {
    dtype <- tolower(.rec_as_chr(spec$dtype, "any"))
    candidates <- .summary_cols_by_dtype(summary, dtype)
    if (length(candidates) == 0) {
      blockers <- c(blockers, sprintf("Required role `%s` is missing a `%s` column.", .rec_as_chr(spec$role, "col"), dtype))
    }
  }

  if (length(blockers) == 0) {
    score <- score + 20L
    if (summary$rows >= max(10L, min_rows * 3L)) score <- score + 5L

    opt_cols <- req$optional_columns %||% list()
    if (length(opt_cols) > 0) {
      opt_match <- sum(vapply(opt_cols, function(spec) {
        length(.summary_cols_by_dtype(summary, tolower(.rec_as_chr(spec$dtype, "any")))) > 0
      }, logical(1)))
      score <- score + min(10L, opt_match * 2L)
    }
  }

  chart_id <- tolower(.rec_as_chr(cap$id, ""))
  if (grepl("^scatter", chart_id) && summary$rows > 5000L) {
    notes <- c(notes, "Large point count detected; use alpha/jitter/density enhancement.")
    score <- score - 10L
  }
  if (identical(chart_id, "pie") && length(summary$categorical_cols %||% character(0)) > 0) {
    cat_col <- summary$categorical_cols[[1]]
    k <- summary$columns[[cat_col]]$unique %||% 0L
    if (isTRUE(k > 12L)) {
      notes <- c(notes, "Too many categories for pie readability; bar/treemap may be clearer.")
      score <- score - 8L
    }
  }
  if (identical(chart_id, "radar")) {
    if (length(summary$numeric_cols %||% character(0)) <= 2) {
      notes <- c(notes, "Radar is usually better with at least 3 numeric metrics.")
      score <- score - 15L
    }
    if (length(summary$categorical_cols %||% character(0)) == 0) {
      notes <- c(notes, "Radar comparison benefits from at least one grouping/category column.")
      score <- score - 10L
    }
  }

  score <- as.integer(max(0L, min(100L, score)))
  status <- if (length(blockers) > 0) {
    "not_recommended"
  } else if (score >= 80L) {
    "recommended"
  } else {
    "available"
  }

  list(
    status = status,
    score = score,
    reason = c(blockers, notes),
    mapping = .auto_mapping_from_requirements(summary, req)
  )
}

recommend_charts_for_data <- function(data,
                                      registry = CHART_CAP_REG,
                                      charts = CHARTS,
                                      data_summary = NULL) {
  summary <- data_summary %||% profile_data_for_recommend(data)

  reg <- registry
  if (is.null(reg) || is.null(reg$charts)) {
    reg <- load_chart_capability_registry(charts = charts, refresh = FALSE)
  }

  chart_order <- .rec_to_vec(reg$chart_order)
  if (length(chart_order) == 0) {
    chart_order <- names(reg$charts %||% list())
  }
  chart_order <- chart_order[chart_order %in% names(reg$charts %||% list())]
  if (length(chart_order) == 0) return(list())

  recs <- lapply(chart_order, function(id) {
    cap <- reg$charts[[id]]
    fit <- .evaluate_capability_fit(cap, summary)
    list(
      chart_id = id,
      chart_name = .rec_as_chr(cap$name, .rec_as_chr(charts[[id]]$name, id)),
      status = fit$status,
      score = fit$score,
      reason = fit$reason %||% character(0),
      mapping = fit$mapping %||% list()
    )
  })

  ord <- order(
    vapply(recs, function(x) -.status_rank(x$status), integer(1)),
    vapply(recs, function(x) -as.integer(x$score %||% 0L), integer(1)),
    vapply(recs, function(x) .rec_as_chr(x$chart_name, ""), character(1))
  )
  recs[ord]
}
