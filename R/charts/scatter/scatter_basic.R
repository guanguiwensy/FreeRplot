# Scatter family mode: basic correlation scatter

chart_def <- list(
  id       = "scatter_basic",
  name     = "基础散点图",
  name_en  = "Scatter (Basic)",
  category = "散点图家族",

  plot_fn = function(data, options = list()) {
    x_col <- names(data)[1]
    y_col <- if (ncol(data) >= 2) names(data)[2] else NULL
    if (is.null(y_col)) stop("scatter_basic requires at least 2 columns (x, y).")

    df <- data.frame(
      x = suppressWarnings(as.numeric(data[[x_col]])),
      y = suppressWarnings(as.numeric(data[[y_col]]))
    )
    if (has_col(data, "group")) {
      df$group <- as.character(data$group)
    } else if (ncol(data) >= 3 && !has_col(data, "label")) {
      df$group <- as.character(data[[3]])
    }
    if (has_col(data, "label")) {
      df$label <- as.character(data$label)
    } else if (ncol(data) >= 4) {
      df$label <- as.character(data[[4]])
    }
    df <- df[!is.na(df$x) & !is.na(df$y), ]
    if (nrow(df) == 0) stop("x/y contain no valid numeric rows.")

    point_size    <- as.numeric(options$point_size %||% 3)
    alpha         <- as.numeric(options$alpha %||% 0.8)
    shape_code    <- as.integer(options$point_shape %||% 16)
    show_smooth   <- isTRUE(options$show_smooth)
    smooth_method <- as.character(options$smooth_method %||% "loess")
    show_ci       <- isTRUE(options$show_ci)
    show_ellipse  <- isTRUE(options$show_ellipse)
    show_labels   <- isTRUE(options$show_labels)
    label_top_n   <- as.integer(options$label_top_n %||% 8)

    pal <- get_palette(options$palette, max(2, length(unique(df$group %||% "All"))))
    p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y))

    if ("group" %in% names(df)) {
      group_levels <- unique(as.character(df$group))
      pal <- palette_values_for_column(df, "group", options, levels = group_levels, palette_name = options$palette)
      p <- p +
        ggplot2::geom_point(
          ggplot2::aes(color = factor(group)),
          size = point_size, alpha = alpha, shape = shape_code
        ) +
        ggplot2::scale_color_manual(values = pal, name = "Group")

      if (show_smooth) {
        p <- p + ggplot2::geom_smooth(
          ggplot2::aes(color = factor(group)),
          method = smooth_method, se = show_ci, linewidth = 0.9,
          show.legend = FALSE
        )
      }

      if (show_ellipse) {
        p <- p + ggplot2::stat_ellipse(ggplot2::aes(color = factor(group)))
      }
    } else {
      p <- p + ggplot2::geom_point(size = point_size, alpha = alpha, shape = shape_code, color = pal[1])
      if (show_smooth) {
        p <- p + ggplot2::geom_smooth(
          method = smooth_method, se = show_ci,
          color = pal[2], fill = pal[2], alpha = 0.15, linewidth = 0.9
        )
      }
      if (show_ellipse) p <- p + ggplot2::stat_ellipse(color = pal[2])
    }

    if (show_labels && "label" %in% names(df)) {
      if (is.na(label_top_n) || label_top_n < 1) {
        label_df <- df
      } else {
        cx <- stats::median(df$x, na.rm = TRUE)
        cy <- stats::median(df$y, na.rm = TRUE)
        d <- (df$x - cx)^2 + (df$y - cy)^2
        keep <- order(d, decreasing = TRUE)[seq_len(min(length(d), label_top_n))]
        label_df <- df[keep, , drop = FALSE]
      }
      p <- p + ggplot2::geom_text(
        data = label_df,
        ggplot2::aes(x = x, y = y, label = label),
        inherit.aes = FALSE,
        vjust = -0.8, size = 3, color = "#303030"
      )
    }

    apply_theme(p + ggplot2::labs(x = x_col, y = y_col), options)
  },

  description = "用于查看两个连续变量之间的关系，可选趋势线和置信区间。",
  best_for    = "相关性探索、初步模式识别",
  columns     = "x(numeric), y(numeric), group(optional), label(optional)",

  sample_data = data.frame(
    x = c(1, 2, 3, 4, 5, 6, 7, 8),
    y = c(1.4, 2.1, 3.4, 3.8, 5.2, 5.9, 6.8, 8.1)
  ),

  options_def = list(
    list(
      id = "point_size", label = "点大小", type = "slider", group = "basic",
      min = 0.5, max = 10, step = 0.5, default = 3
    ),
    list(
      id = "alpha", label = "透明度", type = "slider", group = "basic",
      min = 0.1, max = 1, step = 0.05, default = 0.8
    ),
    list(
      id = "point_shape", label = "点形状", type = "select", group = "basic",
      choices = c("Circle" = "16", "Triangle" = "17", "Square" = "15", "Hollow" = "1"),
      default = "16"
    ),
    list(
      id = "show_smooth", label = "显示拟合趋势", type = "checkbox", group = "basic", default = FALSE
    ),
    list(
      id = "smooth_method", label = "拟合方法", type = "select", group = "basic",
      choices = c("Linear" = "lm", "Loess" = "loess"), default = "loess",
      show_when = "show_smooth"
    ),
    list(
      id = "show_ci", label = "显示置信区间", type = "checkbox", group = "advanced", default = TRUE,
      show_when = "show_smooth"
    ),
    list(
      id = "show_ellipse", label = "显示置信椭圆", type = "checkbox", group = "advanced", default = FALSE
    ),
    list(
      id = "show_labels", label = "显示标签", type = "checkbox", group = "advanced", default = FALSE
    ),
    list(
      id = "label_top_n", label = "最多标注点数", type = "numeric", group = "advanced",
      min = 1, max = 100, step = 1, default = 8, show_when = "show_labels"
    )
  ),

  code_template = function(options) {
    point_size <- options$point_size %||% 3
    alpha      <- options$alpha %||% 0.8
    shape      <- options$point_shape %||% "16"
    method     <- options$smooth_method %||% "loess"
    smooth     <- isTRUE(options$show_smooth)
    ci         <- isTRUE(options$show_ci)

    paste0(
      "library(ggplot2)\n\n",
      "df <- data.frame(\n",
      "  x = c(1,2,3,4,5,6,7,8),\n",
      "  y = c(1.4,2.1,3.4,3.8,5.2,5.9,6.8,8.1)\n",
      ")\n\n",
      "p <- ggplot(df, aes(x = x, y = y)) +\n",
      "  geom_point(size = ", point_size, ", alpha = ", alpha, ", shape = ", shape, ")",
      if (smooth) paste0(
        " +\n  geom_smooth(method = \"", method, "\", se = ", if (ci) "TRUE" else "FALSE", ")"
      ) else "",
      " +\n  theme_minimal()\n\n",
      "print(p)\n"
    )
  }
)
