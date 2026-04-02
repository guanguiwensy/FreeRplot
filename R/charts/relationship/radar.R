# Radar chart (wide format): first column is group, remaining columns are metrics.

chart_def <- list(
  id = "radar",
  name = "雷达图",
  name_en = "Radar / Spider Chart",
  category = "通用图表",
  description = "多维指标在雷达坐标中进行分组对比。",
  best_for = "能力画像、方案对比、综合评分展示",
  columns = "group(分组), 后续各列为指标数值（宽格式）",

  options_def = list(
    list(
      id = "fill_alpha", label = "填充透明度", type = "slider", group = "basic",
      min = 0.05, max = 0.8, step = 0.05, default = 0.3
    ),
    list(
      id = "line_width", label = "边框线宽", type = "slider", group = "basic",
      min = 0.3, max = 3, step = 0.1, default = 1
    ),
    list(
      id = "axis_manual", label = "手动设置轴范围", type = "checkbox", group = "advanced",
      default = FALSE
    ),
    list(
      id = "axis_min", label = "轴最小值", type = "numeric", group = "advanced",
      default = 0, min = NA, max = NA, step = 1, show_when = "axis_manual"
    ),
    list(
      id = "axis_max", label = "轴最大值", type = "numeric", group = "advanced",
      default = 100, min = NA, max = NA, step = 1, show_when = "axis_manual"
    )
  ),

  plot_fn = function(data, options = list()) {
    df <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
    if (ncol(df) < 3) stop("Radar chart requires at least 1 group column and 2 metric columns.")

    names(df)[1] <- "group"
    metric_cols <- names(df)[-1]
    if (length(metric_cols) < 2) stop("Radar chart requires at least two metric columns.")

    for (nm in metric_cols) {
      df[[nm]] <- suppressWarnings(as.numeric(df[[nm]]))
    }

    long <- tidyr::pivot_longer(
      df,
      cols = dplyr::all_of(metric_cols),
      names_to = "metric",
      values_to = "value"
    )
    long <- long[is.finite(long$value), , drop = FALSE]
    if (nrow(long) == 0) stop("No valid numeric values found for radar metrics.")

    fill_alpha <- as.numeric(options$fill_alpha %||% 0.3)
    line_width <- as.numeric(options$line_width %||% 1)
    axis_manual <- isTRUE(options$axis_manual)
    axis_min <- as.numeric(options$axis_min %||% 0)
    axis_max <- as.numeric(options$axis_max %||% 100)

    if (axis_manual && is.finite(axis_min) && is.finite(axis_max) && axis_max > axis_min) {
      long$value_norm <- pmax(0, pmin(1, (long$value - axis_min) / (axis_max - axis_min)))
    } else {
      long <- long |>
        dplyr::group_by(metric) |>
        dplyr::mutate(
          value_norm = (value - min(value, na.rm = TRUE)) /
            (max(value, na.rm = TRUE) - min(value, na.rm = TRUE) + 1e-9)
        ) |>
        dplyr::ungroup()
    }

    long$metric <- factor(long$metric, levels = metric_cols)
    group_levels <- unique(as.character(long$group))
    pal <- palette_values_for_column(
      long, "group", options,
      levels = group_levels,
      palette_name = options$palette
    )

    ggplot2::ggplot(
      long,
      ggplot2::aes(x = metric, y = value_norm, group = group, color = group, fill = group)
    ) +
      ggplot2::geom_polygon(alpha = fill_alpha, linewidth = line_width) +
      ggplot2::geom_point(size = 2.5) +
      ggplot2::coord_polar(clip = "off") +
      ggplot2::scale_y_continuous(
        limits = c(0, 1),
        breaks = c(0.25, 0.5, 0.75, 1)
      ) +
      ggplot2::scale_color_manual(values = pal, name = "分组") +
      ggplot2::scale_fill_manual(values = pal, name = "分组") +
      ggplot2::labs(title = options$title %||% NULL) +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        axis.title = ggplot2::element_blank(),
        axis.text.y = ggplot2::element_blank(),
        axis.text.x = ggplot2::element_text(size = 10, face = "bold"),
        panel.grid.major = ggplot2::element_line(color = "gray88"),
        legend.position = "bottom",
        plot.title = ggplot2::element_text(size = 14, face = "bold", hjust = 0.5),
        plot.margin = ggplot2::margin(15, 15, 15, 15)
      )
  },

  code_template = function(options) {
    fa <- options$fill_alpha %||% 0.3
    lw <- options$line_width %||% 1
    am <- isTRUE(options$axis_manual)
    mn <- if (am) options$axis_min %||% 0 else 0
    mx <- if (am) options$axis_max %||% 100 else 100

    norm_block <- if (am) {
      paste0(
        "long <- long |> dplyr::mutate(value_norm = pmax(0, pmin(1, (value - ",
        mn, ") / (", mx, " - ", mn, "))))\n"
      )
    } else {
      paste0(
        "long <- long |>\n",
        "  dplyr::group_by(metric) |>\n",
        "  dplyr::mutate(value_norm = (value - min(value, na.rm = TRUE)) / (max(value, na.rm = TRUE) - min(value, na.rm = TRUE) + 1e-9)) |>\n",
        "  dplyr::ungroup()\n"
      )
    }

    paste0(
      "library(ggplot2)\nlibrary(dplyr)\nlibrary(tidyr)\n\n",
      "data <- data.frame(\n",
      "  group = c(\"产品A\", \"产品B\", \"产品C\"),\n",
      "  价格 = c(80, 65, 90),\n",
      "  质量 = c(90, 70, 75),\n",
      "  服务 = c(70, 85, 80),\n",
      "  口碑 = c(85, 75, 70),\n",
      "  创新 = c(75, 90, 85),\n",
      "  check.names = FALSE\n",
      ")\n\n",
      "names(data)[1] <- \"group\"\n",
      "metric_cols <- names(data)[-1]\n",
      "long <- tidyr::pivot_longer(data, cols = dplyr::all_of(metric_cols), names_to = \"metric\", values_to = \"value\")\n",
      "long <- long[is.finite(long$value), , drop = FALSE]\n",
      "long$metric <- factor(long$metric, levels = metric_cols)\n",
      norm_block,
      "\n",
      "p <- ggplot(long, aes(x = metric, y = value_norm, group = group, color = group, fill = group)) +\n",
      "  geom_polygon(alpha = ", fa, ", linewidth = ", lw, ") +\n",
      "  geom_point(size = 2.5) +\n",
      "  coord_polar(clip = \"off\") +\n",
      "  scale_y_continuous(limits = c(0, 1), breaks = c(0.25, 0.5, 0.75, 1)) +\n",
      "  scale_color_brewer(palette = \"Set1\") +\n",
      "  scale_fill_brewer(palette = \"Set1\") +\n",
      "  theme_minimal() +\n",
      "  theme(axis.title = element_blank(), axis.text.y = element_blank(), panel.grid.major = element_line(color = \"gray88\"), legend.position = \"bottom\") +\n",
      "  labs(title = \"雷达图\")\n",
      "p\n"
    )
  }
)
