# Scatter family mode: jitter scatter for overlap reduction

chart_def <- list(
  id       = "scatter_jitter",
  name     = "抖动散点图",
  name_en  = "Scatter (Jitter)",
  category = "散点图家族",

  plot_fn = function(data, options = list()) {
    x_col <- names(data)[1]
    y_col <- if (ncol(data) >= 2) names(data)[2] else NULL
    g_col <- if (ncol(data) >= 3) names(data)[3] else NULL
    if (is.null(y_col)) stop("scatter_jitter requires at least 2 columns (x, y).")

    df <- data.frame(
      x = suppressWarnings(as.numeric(data[[x_col]])),
      y = suppressWarnings(as.numeric(data[[y_col]])),
      stringsAsFactors = FALSE
    )
    if (!is.null(g_col)) df$group <- as.character(data[[g_col]])
    df <- df[!is.na(df$x) & !is.na(df$y), ]
    if (nrow(df) == 0) stop("x/y contain no valid numeric rows.")

    point_size <- as.numeric(options$point_size %||% 2.8)
    alpha      <- as.numeric(options$alpha %||% 0.55)
    jw         <- as.numeric(options$jitter_width %||% 0.15)
    jh         <- as.numeric(options$jitter_height %||% 0.15)
    add_trend  <- isTRUE(options$show_trend)
    method     <- as.character(options$smooth_method %||% "loess")

    pal <- get_palette(options$palette, max(2, length(unique(df$group %||% "All"))))
    p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y))

    if (!is.null(g_col)) {
      group_levels <- unique(as.character(df$group))
      pal <- palette_values_for_column(df, "group", options, levels = group_levels, palette_name = options$palette)
      p <- p +
        ggplot2::geom_jitter(
          ggplot2::aes(color = factor(group)),
          width = jw, height = jh, size = point_size, alpha = alpha
        ) +
        ggplot2::scale_color_manual(values = pal, name = g_col)
    } else {
      p <- p + ggplot2::geom_jitter(width = jw, height = jh, size = point_size, alpha = alpha, color = pal[1])
    }

    if (add_trend) {
      if (!is.null(g_col)) {
        p <- p + ggplot2::geom_smooth(
          ggplot2::aes(color = factor(group)),
          method = method, se = FALSE, linewidth = 0.8, show.legend = FALSE
        )
      } else {
        p <- p + ggplot2::geom_smooth(method = method, se = TRUE, color = pal[2], fill = pal[2], alpha = 0.12)
      }
    }

    apply_theme(p + ggplot2::labs(x = x_col, y = y_col), options)
  },

  description = "通过抖动减少点重叠，适合离散取值或重复值较多数据。",
  best_for    = "重叠点可视化、离散测量值分布检查",
  columns     = "x(numeric), y(numeric), group(optional)",

  sample_data = data.frame(
    x = c(1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4),
    y = c(4, 4, 5, 5, 6, 5, 7, 7, 6, 8, 8, 9),
    group = rep(c("G1", "G2"), each = 6)
  ),

  options_def = list(
    list(
      id = "point_size", label = "点大小", type = "slider", group = "basic",
      min = 0.5, max = 10, step = 0.5, default = 2.8
    ),
    list(
      id = "alpha", label = "透明度", type = "slider", group = "basic",
      min = 0.1, max = 1, step = 0.05, default = 0.55
    ),
    list(
      id = "jitter_width", label = "水平抖动", type = "slider", group = "basic",
      min = 0, max = 1, step = 0.05, default = 0.15
    ),
    list(
      id = "jitter_height", label = "垂直抖动", type = "slider", group = "basic",
      min = 0, max = 1, step = 0.05, default = 0.15
    ),
    list(
      id = "show_trend", label = "显示趋势线", type = "checkbox", group = "advanced", default = FALSE
    ),
    list(
      id = "smooth_method", label = "趋势方法", type = "select", group = "advanced",
      choices = c("Linear" = "lm", "Loess" = "loess"), default = "loess",
      show_when = "show_trend"
    )
  ),

  code_template = function(options) {
    jw <- options$jitter_width %||% 0.15
    jh <- options$jitter_height %||% 0.15
    paste0(
      "library(ggplot2)\n\n",
      "df <- data.frame(\n",
      "  x = c(1,1,1,2,2,2,3,3,3,4,4,4),\n",
      "  y = c(4,4,5,5,6,5,7,7,6,8,8,9)\n",
      ")\n\n",
      "p <- ggplot(df, aes(x = x, y = y)) +\n",
      "  geom_jitter(width = ", jw, ", height = ", jh, ", alpha = 0.6, size = 3) +\n",
      "  theme_minimal()\n\n",
      "print(p)\n"
    )
  }
)
