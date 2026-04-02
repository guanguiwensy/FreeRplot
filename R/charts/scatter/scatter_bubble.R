# Scatter family mode: bubble scatter

chart_def <- list(
  id       = "scatter_bubble",
  name     = "气泡散点图",
  name_en  = "Scatter (Bubble)",
  category = "散点图家族",

  plot_fn = function(data, options = list()) {
    x_col <- names(data)[1]
    y_col <- if (ncol(data) >= 2) names(data)[2] else NULL
    s_col <- if (ncol(data) >= 3) names(data)[3] else NULL
    g_col <- if (ncol(data) >= 4) names(data)[4] else NULL
    l_col <- if (ncol(data) >= 5) names(data)[5] else NULL

    if (is.null(y_col) || is.null(s_col)) {
      stop("scatter_bubble requires at least 3 columns (x, y, size).")
    }

    df <- data.frame(
      x = suppressWarnings(as.numeric(data[[x_col]])),
      y = suppressWarnings(as.numeric(data[[y_col]])),
      size = suppressWarnings(as.numeric(data[[s_col]])),
      stringsAsFactors = FALSE
    )
    if (!is.null(g_col)) df$group <- as.character(data[[g_col]])
    if (!is.null(l_col)) df$label <- as.character(data[[l_col]])
    df <- df[!is.na(df$x) & !is.na(df$y) & !is.na(df$size), ]
    if (nrow(df) == 0) stop("x/y/size contain no valid numeric rows.")

    size_min    <- as.numeric(options$size_min %||% 3)
    size_max    <- as.numeric(options$size_max %||% 16)
    alpha       <- as.numeric(options$alpha %||% 0.65)
    border_size <- as.numeric(options$stroke_width %||% 0.4)
    show_labels <- isTRUE(options$show_labels)

    pal <- get_palette(options$palette, max(2, length(unique(df$group %||% "All"))))
    p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, size = size))

    if ("group" %in% names(df)) {
      p <- p +
        ggplot2::geom_point(
          ggplot2::aes(color = factor(group)),
          alpha = alpha, stroke = border_size
        ) +
        ggplot2::scale_color_manual(values = pal, name = g_col)
    } else {
      p <- p + ggplot2::geom_point(color = pal[1], alpha = alpha, stroke = border_size)
    }

    if (show_labels && "label" %in% names(df)) {
      p <- p + ggplot2::geom_text(ggplot2::aes(label = label), size = 3.2, vjust = -0.9, show.legend = FALSE)
    }

    p <- p + ggplot2::scale_size_continuous(range = c(size_min, size_max), name = s_col)
    apply_theme(p + ggplot2::labs(x = x_col, y = y_col), options)
  },

  description = "在二维散点基础上用气泡大小编码第三变量。",
  best_for    = "三变量关系展示、影响力或权重对比",
  columns     = "x(numeric), y(numeric), size(numeric), group(optional), label(optional)",

  options_def = list(
    list(
      id = "size_min", label = "最小气泡", type = "slider", group = "basic",
      min = 1, max = 12, step = 0.5, default = 3
    ),
    list(
      id = "size_max", label = "最大气泡", type = "slider", group = "basic",
      min = 6, max = 30, step = 1, default = 16
    ),
    list(
      id = "alpha", label = "透明度", type = "slider", group = "basic",
      min = 0.1, max = 1, step = 0.05, default = 0.65
    ),
    list(
      id = "show_labels", label = "显示标签", type = "checkbox", group = "basic", default = FALSE
    ),
    list(
      id = "stroke_width", label = "边线粗细", type = "slider", group = "advanced",
      min = 0, max = 2, step = 0.1, default = 0.4
    )
  ),

  code_template = function(options) {
    smin <- options$size_min %||% 3
    smax <- options$size_max %||% 16
    paste0(
      "library(ggplot2)\n\n",
      "df <- data.frame(\n",
      "  x = c(2,4,6,8,10,12),\n",
      "  y = c(6,4,7,8,10,11),\n",
      "  size = c(15,35,20,55,42,68),\n",
      "  group = c(\"North\",\"North\",\"South\",\"South\",\"West\",\"West\")\n",
      ")\n\n",
      "p <- ggplot(df, aes(x = x, y = y, size = size, color = group)) +\n",
      "  geom_point(alpha = 0.65) +\n",
      "  scale_size(range = c(", smin, ", ", smax, ")) +\n",
      "  theme_minimal()\n\n",
      "print(p)\n"
    )
  }
)
