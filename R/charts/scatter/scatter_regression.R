# Scatter family mode: regression-focused scatter

chart_def <- list(
  id       = "scatter_regression",
  name     = "回归散点图",
  name_en  = "Scatter (Regression)",
  category = "散点图家族",

  plot_fn = function(data, options = list()) {
    x_col <- names(data)[1]
    y_col <- if (ncol(data) >= 2) names(data)[2] else NULL
    g_col <- if (ncol(data) >= 3) names(data)[3] else NULL
    if (is.null(y_col)) stop("scatter_regression requires at least 2 columns (x, y).")

    df <- data.frame(
      x = suppressWarnings(as.numeric(data[[x_col]])),
      y = suppressWarnings(as.numeric(data[[y_col]])),
      stringsAsFactors = FALSE
    )
    if (!is.null(g_col)) df$group <- as.character(data[[g_col]])
    df <- df[!is.na(df$x) & !is.na(df$y), ]
    if (nrow(df) == 0) stop("x/y contain no valid numeric rows.")

    point_size    <- as.numeric(options$point_size %||% 2.8)
    alpha         <- as.numeric(options$alpha %||% 0.75)
    method        <- as.character(options$smooth_method %||% "lm")
    show_ci       <- isTRUE(options$show_ci)
    fit_by_group  <- isTRUE(options$fit_by_group)
    show_equation <- isTRUE(options$show_equation)

    pal <- get_palette(options$palette, max(2, length(unique(df$group %||% "All"))))
    p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y))

    if (!is.null(g_col) && fit_by_group) {
      group_levels <- unique(as.character(df$group))
      pal <- palette_values_for_column(df, "group", options, levels = group_levels, palette_name = options$palette)
      p <- p +
        ggplot2::geom_point(ggplot2::aes(color = factor(group)), size = point_size, alpha = alpha) +
        ggplot2::geom_smooth(
          ggplot2::aes(color = factor(group)),
          method = method, se = show_ci, linewidth = 0.9, show.legend = FALSE
        ) +
        ggplot2::scale_color_manual(values = pal, name = g_col)
    } else {
      if (!is.null(g_col)) {
        group_levels <- unique(as.character(df$group))
        pal <- palette_values_for_column(df, "group", options, levels = group_levels, palette_name = options$palette)
        p <- p +
          ggplot2::geom_point(ggplot2::aes(color = factor(group)), size = point_size, alpha = alpha) +
          ggplot2::scale_color_manual(values = pal, name = g_col)
      } else {
        p <- p + ggplot2::geom_point(size = point_size, alpha = alpha, color = pal[1])
      }

      p <- p + ggplot2::geom_smooth(
        method = method, se = show_ci,
        color = pal[min(2, length(pal))],
        fill = pal[min(2, length(pal))],
        alpha = 0.15, linewidth = 0.95
      )
    }

    if (show_equation && identical(method, "lm")) {
      fit <- stats::lm(y ~ x, data = df)
      r2 <- summary(fit)$r.squared
      txt <- sprintf("y = %.3fx + %.3f; R^2 = %.3f", coef(fit)[2], coef(fit)[1], r2)
      p <- p + ggplot2::annotate("label", x = Inf, y = -Inf, label = txt, hjust = 1.05, vjust = -0.3, size = 3)
    }

    apply_theme(p + ggplot2::labs(x = x_col, y = y_col), options)
  },

  description = "突出点云与拟合线关系，支持线性和 loess 回归。",
  best_for    = "趋势检验、相关建模、组内外拟合关系观察",
  columns     = "x(numeric), y(numeric), group(optional)",

  sample_data = data.frame(
    x = c(3, 5, 8, 10, 12, 15, 18, 20, 23, 25),
    y = c(4.2, 5.3, 7.9, 9.5, 10.7, 13.2, 14.4, 16.3, 17.8, 19.6),
    group = c("Control", "Control", "Control", "Control", "Case", "Case", "Case", "Case", "Case", "Case")
  ),

  options_def = list(
    list(
      id = "point_size", label = "点大小", type = "slider", group = "basic",
      min = 0.5, max = 10, step = 0.5, default = 2.8
    ),
    list(
      id = "alpha", label = "透明度", type = "slider", group = "basic",
      min = 0.1, max = 1, step = 0.05, default = 0.75
    ),
    list(
      id = "smooth_method", label = "拟合方法", type = "select", group = "basic",
      choices = c("Linear" = "lm", "Loess" = "loess"), default = "lm"
    ),
    list(
      id = "show_ci", label = "显示置信区间", type = "checkbox", group = "basic", default = TRUE
    ),
    list(
      id = "fit_by_group", label = "按组分别拟合", type = "checkbox", group = "advanced", default = FALSE
    ),
    list(
      id = "show_equation", label = "显示回归方程", type = "checkbox", group = "advanced", default = FALSE
    )
  ),

  code_template = function(options) {
    method <- options$smooth_method %||% "lm"
    ci <- isTRUE(options$show_ci)
    paste0(
      "library(ggplot2)\n\n",
      "df <- data.frame(\n",
      "  x = c(3,5,8,10,12,15,18,20,23,25),\n",
      "  y = c(4.2,5.3,7.9,9.5,10.7,13.2,14.4,16.3,17.8,19.6)\n",
      ")\n\n",
      "p <- ggplot(df, aes(x = x, y = y)) +\n",
      "  geom_point() +\n",
      "  geom_smooth(method = \"", method, "\", se = ", if (ci) "TRUE" else "FALSE", ") +\n",
      "  theme_minimal()\n\n",
      "print(p)\n"
    )
  }
)
