# =============================================================================
# File   : R/core/chart_capability_registry.R
# Purpose: Build/load chart capability registry from chart definitions and store
#          it as JSON under config/chart_capabilities.json.
#
# Exports:
#   chart_capability_registry_path()
#   build_chart_capability_registry(charts = CHARTS)
#   write_chart_capability_registry(charts = CHARTS, path = chart_capability_registry_path(), force = FALSE)
#   load_chart_capability_registry(charts = CHARTS, path = chart_capability_registry_path(), refresh = FALSE)
#   get_chart_settings_layout(chart_id, registry = CHART_CAP_REG)
# =============================================================================

chart_capability_registry_path <- function() {
  file.path(APP_DIR, "config", "chart_capabilities.json")
}

.as_chr <- function(x, default = "") {
  val <- x %||% default
  if (length(val) == 0 || is.null(val)) return(default)
  as.character(val)[1]
}

.as_int <- function(x, default = 0L) {
  v <- suppressWarnings(as.integer(x %||% default))
  if (length(v) == 0 || is.na(v[1])) return(as.integer(default))
  as.integer(v[1])
}

.trim <- function(x) {
  trimws(.as_chr(x, ""))
}

.compact <- function(x) {
  x <- x[!is.na(x)]
  x <- trimws(as.character(x))
  x[nzchar(x)]
}

.to_id_vec <- function(x) {
  if (is.null(x) || length(x) == 0) return(character(0))
  if (is.list(x)) return(.compact(unlist(x, use.names = FALSE)))
  .compact(as.character(x))
}

.split_column_specs <- function(columns_txt) {
  txt <- .trim(columns_txt)
  if (!nzchar(txt)) return(character(0))

  chars <- strsplit(txt, "", fixed = TRUE)[[1]]
  parts <- character(0)
  cur <- character(0)
  depth <- 0L

  for (ch in chars) {
    if (identical(ch, "(")) {
      depth <- depth + 1L
      cur <- c(cur, ch)
      next
    }
    if (identical(ch, ")")) {
      depth <- max(0L, depth - 1L)
      cur <- c(cur, ch)
      next
    }
    if (identical(ch, ",") && depth == 0L) {
      token <- trimws(paste(cur, collapse = ""))
      if (nzchar(token)) parts <- c(parts, token)
      cur <- character(0)
      next
    }
    cur <- c(cur, ch)
  }

  tail_token <- trimws(paste(cur, collapse = ""))
  if (nzchar(tail_token)) parts <- c(parts, tail_token)
  parts
}

.infer_dtype_from_role <- function(role) {
  r <- tolower(.trim(role))
  if (!nzchar(r)) return("any")

  if (r %in% c("x", "y", "value", "values", "size", "r", "low", "high", "mid", "ymin", "ymax", "xmin", "xmax", "sd", "count")) {
    return("numeric")
  }
  if (r %in% c("time", "date", "datetime", "year", "month", "day", "order")) {
    return("datetime")
  }
  if (r %in% c("group", "category", "class", "facet", "label", "name", "id", "type", "parent", "from", "to", "sequence")) {
    return("categorical")
  }
  "any"
}

.infer_dtype_from_desc <- function(desc) {
  d <- tolower(.trim(desc))
  if (!nzchar(d)) return("any")

  if (grepl("numeric|number|value|continuous|int|float|double|count|weight", d, perl = TRUE)) return("numeric")
  if (grepl("date|time|datetime|timestamp|year|month|day", d, perl = TRUE)) return("datetime")
  if (grepl("categor|group|class|factor|label|name|text|string|id", d, perl = TRUE)) return("categorical")
  "any"
}

.is_optional_role <- function(role, desc) {
  r <- tolower(.trim(role))
  d <- tolower(.trim(desc))

  if (r %in% c("group", "label", "size", "facet", "order", "time", "sub_group")) return(TRUE)
  if (grepl("optional|maybe|nullable|can be empty", d, perl = TRUE)) return(TRUE)
  FALSE
}

.parse_columns_to_schema <- function(chart) {
  txt <- .as_chr(chart[["columns"]], "")
  parts <- .split_column_specs(txt)

  if (length(parts) == 0) {
    sample_df <- chart[["sample_data"]]
    if (!is.data.frame(sample_df) || ncol(sample_df) == 0) return(list())
    return(lapply(names(sample_df), function(nm) {
      list(
        role = nm,
        required = TRUE,
        dtype = if (inherits(sample_df[[nm]], c("Date", "POSIXct", "POSIXt"))) "datetime" else if (is.numeric(sample_df[[nm]])) "numeric" else "categorical"
      )
    }))
  }

  lapply(parts, function(part) {
    role <- trimws(sub("\\s*\\(.*$", "", part))
    desc <- ""
    if (grepl("\\(", part, perl = TRUE) && grepl("\\)$", part, perl = TRUE)) {
      desc <- sub("^[^(]*\\((.*)\\)\\s*$", "\\1", part, perl = TRUE)
    }

    dtype_desc <- .infer_dtype_from_desc(desc)
    dtype_role <- .infer_dtype_from_role(role)
    dtype <- if (!identical(dtype_desc, "any")) dtype_desc else dtype_role

    list(
      role = role,
      required = !.is_optional_role(role, desc),
      dtype = dtype
    )
  })
}

.normalize_schema <- function(schema) {
  if (length(schema) == 0) return(list())

  norm <- lapply(schema, function(spec) {
    role <- .trim(spec$role %||% "")
    if (!nzchar(role)) return(NULL)

    dtype <- tolower(.trim(spec$dtype %||% "any"))
    if (!(dtype %in% c("numeric", "datetime", "categorical", "any"))) {
      dtype <- "any"
    }

    list(
      role = role,
      required = isTRUE(spec$required),
      dtype = dtype
    )
  })

  Filter(Negate(is.null), norm)
}

.infer_min_rows <- function(chart_id, schema) {
  id <- tolower(.as_chr(chart_id, ""))
  req_n <- sum(vapply(schema, function(x) isTRUE(x$required), logical(1)))

  if (identical(id, "correlation")) return(3L)
  if (grepl("^scatter", id)) return(2L)
  if (grepl("^dna_", id)) return(1L)
  if (grepl("line|area|radar|circos", id)) return(2L)
  as.integer(max(1L, min(3L, req_n)))
}

.normalize_option_meta <- function(opt) {
  list(
    id = .as_chr(opt$id, ""),
    label = .as_chr(opt$label, .as_chr(opt$id, "")),
    type = .as_chr(opt$type, "unknown"),
    group = .as_chr(opt$group, "basic"),
    default = opt$default %||% NULL,
    min = opt$min %||% NULL,
    max = opt$max %||% NULL,
    step = opt$step %||% NULL,
    choices = opt$choices %||% NULL,
    show_when = .as_chr(opt$show_when, "")
  )
}

.build_settings_layout <- function(options) {
  ids_by_group <- function(group_name) {
    ids <- vapply(Filter(function(o) identical(.as_chr(o$group, "basic"), group_name), options), `[[`, character(1), "id")
    unname(ids[nzchar(ids)])
  }

  list(
    sections = list(
      list(id = "basic", label = "Basic", option_ids = ids_by_group("basic")),
      list(id = "advanced", label = "Advanced", option_ids = ids_by_group("advanced"))
    )
  )
}

.apply_chart_specific_requirement_overrides <- function(chart_id, req) {
  id <- tolower(.as_chr(chart_id, ""))

  if (identical(id, "correlation")) {
    req$min_columns <- max(2L, .as_int(req$min_columns, 2L))
    req$min_numeric_columns <- max(2L, .as_int(req$min_numeric_columns, 2L))
    req$required_columns <- list(list(role = "values", required = TRUE, dtype = "numeric"))
    req$optional_columns <- list()
    return(req)
  }

  if (identical(id, "radar")) {
    req$min_columns <- max(4L, .as_int(req$min_columns, 4L))
    req$min_numeric_columns <- max(3L, .as_int(req$min_numeric_columns, 3L))
    req$min_categorical_columns <- max(1L, .as_int(req$min_categorical_columns, 1L))
    return(req)
  }

  if (identical(id, "dna_single")) {
    req$min_rows <- max(1L, .as_int(req$min_rows, 1L))
    req$min_columns <- max(1L, .as_int(req$min_columns, 1L))
    req$min_categorical_columns <- max(1L, .as_int(req$min_categorical_columns, 1L))
    return(req)
  }

  req
}

.chart_to_capability <- function(chart) {
  id <- .as_chr(chart[["id"]], "")
  schema <- .normalize_schema(.parse_columns_to_schema(chart))
  req_cols <- Filter(function(x) isTRUE(x$required), schema)
  opt_cols <- Filter(function(x) !isTRUE(x$required), schema)

  options <- lapply(chart[["options_def"]] %||% list(), .normalize_option_meta)

  req <- list(
    min_rows = .infer_min_rows(id, schema),
    min_columns = max(1L, length(req_cols)),
    min_numeric_columns = as.integer(sum(vapply(req_cols, function(x) identical(x$dtype, "numeric"), logical(1)))),
    min_datetime_columns = as.integer(sum(vapply(req_cols, function(x) identical(x$dtype, "datetime"), logical(1)))),
    min_categorical_columns = as.integer(sum(vapply(req_cols, function(x) identical(x$dtype, "categorical"), logical(1)))),
    required_columns = req_cols,
    optional_columns = opt_cols
  )
  req <- .apply_chart_specific_requirement_overrides(id, req)

  list(
    id = id,
    name = .as_chr(chart[["name"]], id),
    name_en = .as_chr(chart[["name_en"]], id),
    category = .as_chr(chart[["category"]], "Uncategorized"),
    description = .as_chr(chart[["description"]], ""),
    best_for = .as_chr(chart[["best_for"]], ""),
    data_requirements = req,
    supported_params = options,
    settings_layout = .build_settings_layout(options)
  )
}

build_chart_capability_registry <- function(charts = CHARTS) {
  ids <- names(charts)
  entries <- lapply(ids, function(id) .chart_to_capability(charts[[id]]))
  names(entries) <- ids

  list(
    version = "1.1.0",
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"),
    chart_order = ids,
    charts = entries
  )
}

write_chart_capability_registry <- function(charts = CHARTS,
                                            path = chart_capability_registry_path(),
                                            force = FALSE) {
  if (!isTRUE(force) && file.exists(path)) return(invisible(FALSE))

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  reg <- build_chart_capability_registry(charts)
  jsonlite::write_json(reg, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(TRUE)
}

.is_valid_registry <- function(reg) {
  !is.null(reg) &&
    is.list(reg) &&
    !is.null(reg$charts) &&
    is.list(reg$charts) &&
    !is.null(reg$chart_order)
}

.merge_registry_with_charts <- function(reg, charts) {
  ids <- names(charts)
  rebuilt <- build_chart_capability_registry(charts)
  existing <- reg$charts %||% list()

  merged <- list()
  for (id in ids) {
    if (!is.null(existing[[id]])) {
      merged[[id]] <- existing[[id]]
    } else {
      merged[[id]] <- rebuilt$charts[[id]]
    }
  }

  # Ensure required sections exist even for legacy/manual entries.
  for (id in ids) {
    cap <- merged[[id]]
    if (is.null(cap$data_requirements) || is.null(cap$supported_params) || is.null(cap$settings_layout)) {
      base <- rebuilt$charts[[id]]
      if (is.null(cap$data_requirements)) cap$data_requirements <- base$data_requirements
      if (is.null(cap$supported_params)) cap$supported_params <- base$supported_params
      if (is.null(cap$settings_layout)) cap$settings_layout <- base$settings_layout
      merged[[id]] <- cap
    }
  }

  order_old <- .to_id_vec(reg$chart_order)
  order_old <- order_old[order_old %in% ids]
  order_new <- unique(c(order_old, ids))

  list(
    version = .as_chr(reg$version, rebuilt$version),
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"),
    chart_order = order_new,
    charts = merged
  )
}

load_chart_capability_registry <- function(charts = CHARTS,
                                           path = chart_capability_registry_path(),
                                           refresh = FALSE) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  if (isTRUE(refresh) || !file.exists(path)) {
    reg <- build_chart_capability_registry(charts)
    jsonlite::write_json(reg, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
    return(reg)
  }

  reg <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) NULL
  )

  if (!.is_valid_registry(reg)) {
    reg <- build_chart_capability_registry(charts)
    jsonlite::write_json(reg, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
    return(reg)
  }

  merged <- .merge_registry_with_charts(reg, charts)
  merged_order <- .to_id_vec(merged$chart_order)
  if (!identical(merged_order, .to_id_vec(reg$chart_order)) ||
      length(names(merged$charts %||% list())) != length(names(reg$charts %||% list()))) {
    jsonlite::write_json(merged, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  }

  merged
}

get_chart_settings_layout <- function(chart_id, registry = CHART_CAP_REG) {
  id <- .as_chr(chart_id, "")
  if (!nzchar(id) || is.null(registry) || is.null(registry$charts) || is.null(registry$charts[[id]])) {
    return(list(sections = list()))
  }

  layout <- registry$charts[[id]]$settings_layout %||% list(sections = list())
  sections <- layout$sections %||% list()

  norm_sections <- lapply(sections, function(s) {
    list(
      id = .as_chr(s$id, "section"),
      label = .as_chr(s$label, "Section"),
      option_ids = .to_id_vec(s$option_ids)
    )
  })

  list(sections = norm_sections)
}
