# Scatter family mode: grouped comparison scatter

chart_def <- list(
  id       = "scatter_grouped",
  name     = "分组散点图",
  name_en  = "Scatter (Grouped)",
  category = "散点图家族",

  plot_fn = function(data, options = list()) {
    x_col <- names(data)[1]
    y_col <- if (ncol(data) >= 2) names(data)[2] else NULL
    g_col <- if (ncol(data) >= 3) names(data)[3] else NULL
    if (is.null(y_col)) stop("scatter_grouped requires at least 2 columns (x, y).")

    df <- data.frame(
      x = suppressWarnings(as.numeric(data[[x_col]])),
      y = suppressWarnings(as.numeric(data[[y_col]])),
      stringsAsFactors = FALSE
    )
    df$group <- if (!is.null(g_col)) as.character(data[[g_col]]) else "All"
    df <- df[!is.na(df$x) & !is.na(df$y), ]
    if (nrow(df) == 0) stop("x/y contain no valid numeric rows.")

    point_size    <- as.numeric(options$point_size %||% 3)
    alpha         <- as.numeric(options$alpha %||% 0.75)
    shape_by_grp  <- isTRUE(options$shape_by_group)
    show_ellipse  <- isTRUE(options$show_ellipse)
    show_centroid <- isTRUE(options$show_centroid)

    group_levels <- unique(as.character(df$group))
    pal <- palette_values_for_column(df, "group", options, levels = group_levels, palette_name = options$palette)

    aes_base <- ggplot2::aes(x = x, y = y, color = factor(group))
    if (shape_by_grp) aes_base$shape <- as.name("factor(group)")

    p <- ggplot2::ggplot(df, aes_base) +
      ggplot2::geom_point(size = point_size, alpha = alpha) +
      ggplot2::scale_color_manual(values = pal, name = if (!is.null(g_col)) g_col else "Group")

    if (shape_by_grp) p <- p + ggplot2::guides(shape = ggplot2::guide_legend(title = if (!is.null(g_col)) g_col else "Group"))
    if (show_ellipse) p <- p + ggplot2::stat_ellipse(ggplot2::aes(group = factor(group)), linewidth = 0.8)
    if (show_centroid) {
      centers <- stats::aggregate(cbind(x, y) ~ group, data = df, FUN = mean)
      p <- p + ggplot2::geom_point(
        data = centers,
        ggplot2::aes(x = x, y = y, fill = factor(group)),
        shape = 23, color = "#1f1f1f", size = point_size + 1.2, stroke = 0.6, inherit.aes = FALSE
      ) +
        ggplot2::scale_fill_manual(values = pal, guide = "none")
    }

    apply_theme(p + ggplot2::labs(x = x_col, y = y_col), options)
  },

  description = "按分组变量展示散点分布，突出组间分离和重叠关系。",
  best_for    = "实验组对比、群体差异观察、PCA 风格二维结果展示",
  columns     = "x(numeric), y(numeric), group(categorical)",

  sample_data = data.frame(
    x = c(2.1, 2.9, 3.2, 5.6, 6.0, 6.5, 4.2, 4.7, 5.0),
    y = c(1.9, 2.5, 2.1, 5.1, 5.8, 6.2, 4.0, 4.3, 4.9),
    group = c("A", "A", "A", "B", "B", "B", "C", "C", "C")
  ),

  options_def = list(
    list(
      id = "point_size", label = "点大小", type = "slider", group = "basic",
      min = 0.5, max = 10, step = 0.5, default = 3
    ),
    list(
      id = "alpha", label = "透明度", type = "slider", group = "basic",
      min = 0.1, max = 1, step = 0.05, default = 0.75
    ),
    list(
      id = "shape_by_group", label = "按组区分点形状", type = "checkbox", group = "basic", default = FALSE
    ),
    list(
      id = "show_ellipse", label = "显示分组椭圆", type = "checkbox", group = "advanced", default = TRUE
    ),
    list(
      id = "show_centroid", label = "显示组中心", type = "checkbox", group = "advanced", default = FALSE
    )
  ),

  code_template = function(options) {
    size <- options$point_size %||% 3
    alpha <- options$alpha %||% 0.75
    paste0(
      "library(ggplot2)\n\n",
      "df <- data.frame(\n",
      "  x = c(2.1,2.9,3.2,5.6,6.0,6.5,4.2,4.7,5.0),\n",
      "  y = c(1.9,2.5,2.1,5.1,5.8,6.2,4.0,4.3,4.9),\n",
      "  group = c(\"A\",\"A\",\"A\",\"B\",\"B\",\"B\",\"C\",\"C\",\"C\")\n",
      ")\n\n",
      "p <- ggplot(df, aes(x = x, y = y, color = group)) +\n",
      "  geom_point(size = ", size, ", alpha = ", alpha, ") +\n",
      "  stat_ellipse() +\n",
      "  theme_minimal()\n\n",
      "print(p)\n"
    )
  }
)
