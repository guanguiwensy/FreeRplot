# =============================================================================
# File   : R/core/module_shared.R
# Purpose: Shared server-module helpers for numeric coercion, active-data
#          resolution, and chart option parsing. Keeps duplicated logic out of
#          mod_code/mod_plot/mod_overlay/mod_settings.
#
# Depends: shiny (reactive), rhandsontable (hot_to_r)
#          R/ui_helpers.R (collect_options)
#          R/plot_core.R  (COLOR_PALETTES, infer_palette_target,
#                          palette_values_for_levels, palette_override_input_id)
#
# Exported functions:
#   shared_as_num_or(x, default)
#   shared_is_probably_numeric(x)
#   shared_clamp_plot_dimensions(width_in, height_in, dpi)
#   shared_parse_axis_limits(x_min, x_max, y_min, y_max)
#   shared_collect_column_mapping(input)
#   shared_chart_expected_roles(chart_id = NULL)
#   shared_prepare_code_context(data, chart_id = NULL)
#   shared_active_data_reactive(input, rv, data_input_id = "data_table",
#                               rv_field = "current_data")
#   shared_build_plot_options(input, data, chart_id = input$chart_type_select,
#                             mapping = shared_collect_column_mapping(input))
# =============================================================================

local({
  .value_or <- function(x, default) {
    if (is.null(x) || length(x) == 0) return(default)
    v <- x[1]
    if (is.na(v)) return(default)
    if (is.character(v) && !nzchar(v)) return(default)
    v
  }

  shared_as_num_or <<- function(x, default = NA_real_) {
    v <- suppressWarnings(as.numeric(x))
    if (length(v) == 0 || is.na(v[1])) default else v[1]
  }

  shared_is_probably_numeric <<- function(x) {
    if (is.null(x)) return(FALSE)
    if (is.numeric(x)) return(TRUE)
    sx <- suppressWarnings(as.numeric(x))
    !all(is.na(sx))
  }

  shared_clamp_plot_dimensions <<- function(width_in, height_in, dpi = 150) {
    w <- shared_as_num_or(width_in, 10)
    h <- shared_as_num_or(height_in, 6)
    d <- shared_as_num_or(dpi, 150)

    list(
      plot_width_in = min(max(w, 2), 40),
      plot_height_in = min(max(h, 2), 40),
      plot_dpi = min(max(d, 72), 600)
    )
  }

  shared_parse_axis_limits <<- function(x_min, x_max, y_min, y_max) {
    list(
      x_min = shared_as_num_or(x_min, NA_real_),
      x_max = shared_as_num_or(x_max, NA_real_),
      y_min = shared_as_num_or(y_min, NA_real_),
      y_max = shared_as_num_or(y_max, NA_real_)
    )
  }

  shared_collect_column_mapping <<- function(input) {
    as_map_value <- function(v) {
      v <- as.character(v %||% "")[1]
      if (!nzchar(v)) NULL else v
    }

    list(
      x = as_map_value(input$map_x_col),
      y = as_map_value(input$map_y_col),
      size = as_map_value(input$map_size_col),
      group = as_map_value(input$map_group_col),
      label = as_map_value(input$map_label_col)
    )
  }

  shared_chart_expected_roles <<- function(chart_id = NULL) {
    if (is.null(chart_id) || !nzchar(chart_id) || is.null(CHARTS[[chart_id]])) {
      return(character(0))
    }
    cols_txt <- CHARTS[[chart_id]]$columns %||% ""
    hits <- regmatches(cols_txt, gregexpr("[A-Za-z_]+\\s*\\(", cols_txt, perl = TRUE))[[1]]
    if (length(hits) == 0 || identical(hits, "-1")) return(character(0))
    unique(tolower(trimws(gsub("\\($", "", hits))))
  }

  .is_numeric_like <- function(x) {
    if (is.numeric(x)) return(TRUE)
    sx <- suppressWarnings(as.numeric(x))
    !all(is.na(sx))
  }

  shared_prepare_code_context <<- function(data, chart_id = NULL, mapping = list()) {
    df <- as.data.frame(data %||% data.frame(), stringsAsFactors = FALSE, check.names = FALSE)
    if (ncol(df) == 0L) {
      return(list(
        data = df, df = df,
        col_names = character(0), num_cols = character(0), extra_cols = character(0),
        x_col = NULL, y_col = NULL, size_col = NULL, group_col = NULL, label_col = NULL
      ))
    }

    col_names <- names(df)
    mapping <- mapping %||% list()
    pick_mapped <- function(key, fallback = NULL) {
      cand <- as.character(mapping[[key]] %||% "")[1]
      if (nzchar(cand) && cand %in% col_names) cand else fallback
    }

    num_cols <- col_names[vapply(df, .is_numeric_like, logical(1))]
    default_x <- if (length(num_cols) >= 1) num_cols[1] else col_names[1]
    default_y <- if (length(num_cols) >= 2) num_cols[2] else if (length(col_names) >= 2) col_names[2] else col_names[1]
    default_size <- if (length(num_cols) >= 3) num_cols[3] else if (length(num_cols) >= 2) num_cols[2] else default_x
    x_col <- pick_mapped("x", default_x)
    y_col <- pick_mapped("y", default_y)
    size_col <- pick_mapped("size", default_size)
    group_col <- pick_mapped("group", NULL)
    label_col <- pick_mapped("label", NULL)
    roles <- shared_chart_expected_roles(chart_id)

    if ("x" %in% roles && !("x" %in% names(df)) && !is.null(x_col)) df$x <- df[[x_col]]
    if ("y" %in% roles && !("y" %in% names(df)) && !is.null(y_col)) df$y <- df[[y_col]]

    if ("size" %in% roles) {
      if (!("size" %in% names(df))) df$size <- suppressWarnings(as.numeric(df[[size_col]]))
      if ("size" %in% names(df)) df$size <- suppressWarnings(as.numeric(df$size))
      if (!("size" %in% names(df)) || all(!is.finite(df$size))) df$size <- rep(1, nrow(df))
      bad <- !is.finite(df$size)
      if (any(bad)) df$size[bad] <- 1
    }

    used <- unique(c(
      x_col, y_col,
      if ("size" %in% roles) size_col else NULL,
      group_col, label_col
    ))
    extra_cols <- setdiff(col_names, used)

    if ("group" %in% roles && !("group" %in% names(df))) {
      if (!is.null(group_col) && group_col %in% col_names) {
        df$group <- as.character(df[[group_col]])
      } else if (length(extra_cols) >= 1) {
        group_col <- extra_cols[1]
        df$group <- as.character(df[[group_col]])
      }
    }
    label_pool <- setdiff(extra_cols, group_col %||% character(0))
    if ("label" %in% roles && !("label" %in% names(df))) {
      if (!is.null(label_col) && label_col %in% col_names) {
        df$label <- as.character(df[[label_col]])
      } else if (length(label_pool) >= 1) {
        label_col <- label_pool[1]
        df$label <- as.character(df[[label_col]])
      }
    }

    list(
      data = df,
      df = df,
      col_names = col_names,
      num_cols = num_cols,
      extra_cols = extra_cols,
      x_col = x_col,
      y_col = y_col,
      size_col = size_col,
      group_col = group_col,
      label_col = label_col
    )
  }

  shared_active_data_reactive <<- function(input, rv, data_input_id = "data_table", rv_field = "current_data") {
    reactive({
      tryCatch({
        fallback <- rv[[rv_field]]
        tbl <- hot_to_r(input[[data_input_id]])
        if (is.null(tbl)) return(fallback)

        expected <- names(fallback)
        if (length(expected) == 0) return(tbl)
        if (!all(expected %in% names(tbl))) return(fallback)
        tbl
      }, error = function(e) rv[[rv_field]])
    })
  }

  shared_build_plot_options <<- function(input, data, chart_id = input$chart_type_select, mapping = shared_collect_column_mapping(input)) {
    chart <- CHARTS[[chart_id]]
    defs <- list()
    if (!is.null(chart$options_def)) {
      defs <- Filter(function(d) !identical(d$id, "color_palette"), chart$options_def)
    }

    ctx <- shared_prepare_code_context(data, chart_id = chart_id, mapping = mapping)
    x_col <- ctx$x_col
    y_col <- ctx$y_col

    dims <- shared_clamp_plot_dimensions(input$plot_width_in, input$plot_height_in, input$plot_dpi)
    axis <- shared_parse_axis_limits(input$x_min, input$x_max, input$y_min, input$y_max)

    palette_default <- names(COLOR_PALETTES)[1]
    palette_value <- .value_or(input$color_palette, palette_default)

    target_column <- .value_or(input$palette_target_column, infer_palette_target(chart_id, data))
    if (!is.null(target_column) && !is.na(target_column) && !nzchar(as.character(target_column))) {
      target_column <- NULL
    }

    color_overrides <- list()
    if (!is.null(target_column) && target_column %in% names(data)) {
      levels <- unique(as.character(data[[target_column]]))
      defaults <- palette_values_for_levels(levels, palette_value, list())

      for (level in levels) {
        iid <- palette_override_input_id(target_column, level)
        val <- input[[iid]]
        if (is.null(val)) next
        val <- as.character(val)[1]
        if (!nzchar(val)) next
        if (!identical(toupper(val), toupper(defaults[[level]]))) {
          color_overrides[[level]] <- val
        }
      }
    }

    c(
      list(
        title = .value_or(input$plot_title, ""),
        x_label = .value_or(input$x_label, ""),
        y_label = .value_or(input$y_label, ""),
        palette = palette_value,
        theme = .value_or(input$chart_theme, names(CHART_THEMES)[1]),
        plot_width_in = dims$plot_width_in,
        plot_height_in = dims$plot_height_in,
        plot_dpi = dims$plot_dpi,
        x_range_mode = .value_or(input$x_range_mode, "auto"),
        x_min = axis$x_min,
        x_max = axis$x_max,
        y_range_mode = .value_or(input$y_range_mode, "auto"),
        y_min = axis$y_min,
        y_max = axis$y_max,
        color_settings = list(
          base_palette = palette_value,
          target_column = target_column,
          overrides = color_overrides
        ),
        column_mapping = mapping,
        x_is_numeric = if (!is.null(x_col) && x_col %in% names(ctx$data)) shared_is_probably_numeric(ctx$data[[x_col]]) else FALSE,
        y_is_numeric = if (!is.null(y_col) && y_col %in% names(ctx$data)) shared_is_probably_numeric(ctx$data[[y_col]]) else FALSE
      ),
      collect_options(input, defs)
    )
  }
})
