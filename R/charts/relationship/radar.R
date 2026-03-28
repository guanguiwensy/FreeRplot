# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "radar", name = "雷达图", category = "通用图表", 
    name_en = "Radar / Spider Chart", plot_fn = function (data, 
        options) 
    {
        group_col <- names(data)[1]
        axes <- names(data)[-1]
        n_axes <- length(axes)
        group_levels <- unique(as.character(data$group))
        pal <- palette_values_for_column(data, "group", options, 
            levels = group_levels, palette_name = options$palette)
        fill_alpha <- as.numeric(options$fill_alpha %||% 0.3)
        line_width <- as.numeric(options$line_width %||% 1)
        axis_manual <- isTRUE(options$axis_manual)
        axis_min <- as.numeric(options$axis_min %||% 0)
        axis_max <- as.numeric(options$axis_max %||% 100)
        long <- tidyr::pivot_longer(data, cols = -1, names_to = "axis", 
            values_to = "value")
        names(long)[1] <- "group"
        if (axis_manual) {
            long <- dplyr::mutate(long, value_norm = (value - 
                axis_min)/(axis_max - axis_min + 1e-09))
        }
        else {
            long <- dplyr::ungroup(dplyr::mutate(dplyr::group_by(long, 
                axis), value_norm = (value - min(value, na.rm = TRUE))/(max(value, 
                na.rm = TRUE) - min(value, na.rm = TRUE) + 1e-09)))
        }
        long$axis <- factor(long$axis, levels = axes)
        p <- ggplot2::ggplot(long, ggplot2::aes(x = axis, y = value_norm, 
            group = group, color = group, fill = group)) + ggplot2::geom_polygon(alpha = fill_alpha, 
            linewidth = line_width) + ggplot2::geom_point(size = 3) + 
            ggplot2::coord_polar(clip = "off") + ggplot2::scale_y_continuous(limits = c(0, 
            1), breaks = c(0.25, 0.5, 0.75, 1)) + ggplot2::scale_color_manual(values = pal, 
            name = "分组") + ggplot2::scale_fill_manual(values = pal, 
            name = "分组") + ggplot2::labs(title = options$title %||% 
            NULL) + ggplot2::theme_minimal() + ggplot2::theme(axis.title = ggplot2::element_blank(), 
            axis.text.y = ggplot2::element_blank(), axis.text.x = ggplot2::element_text(size = 10, 
                face = "bold"), panel.grid.major = ggplot2::element_line(color = "gray88"), 
            legend.position = "bottom", plot.title = ggplot2::element_text(size = 14, 
                face = "bold", hjust = 0.5), plot.margin = ggplot2::margin(15, 
                15, 15, 15))
        p
    }, description = "多维指标在放射状坐标轴上的多边形展示，便于综合评估", 
    best_for = "多维度能力对比、综合评分可视化", 
    columns = "group(分组), 后续各列为指标名称和数值（宽格式）", 
    sample_data = structure(list(group = c("产品A", "产品B", 
    "产品C"), 价格 = c(80, 65, 90), 质量 = c(90, 70, 75
    ), 服务 = c(70, 85, 80), 口碑 = c(85, 75, 70), 创新 = c(75, 
    90, 85)), class = "data.frame", row.names = c(NA, -3L)), 
    options_def = list(list(id = "fill_alpha", label = "填充透明度", 
        type = "slider", group = "basic", min = 0.05, max = 0.8, 
        step = 0.05, default = 0.3), list(id = "line_width", 
        label = "边框线宽", type = "slider", group = "basic", 
        min = 0.3, max = 3, step = 0.1, default = 1), list(id = "axis_manual", 
        label = "手动设置轴范围", type = "checkbox", group = "advanced", 
        default = FALSE), list(id = "axis_min", label = "轴最小值", 
        type = "numeric", group = "advanced", default = 0, min = NA, 
        max = NA, step = 1, show_when = "axis_manual"), list(
        id = "axis_max", label = "轴最大值", type = "numeric", 
        group = "advanced", default = 100, min = NA, max = NA, 
        step = 1, show_when = "axis_manual")), code_template = function (options) 
    {
        fa <- options$fill_alpha %||% 0.3
        lw <- options$line_width %||% 1
        am <- isTRUE(options$axis_manual)
        mn <- if (am) 
            (options$axis_min %||% 0)
        else 0
        mx <- if (am) 
            (options$axis_max %||% 100)
        else 100
        paste0("library(ggplot2)\nlibrary(tidyr)\nlibrary(dplyr)\n\ndata <- data.frame(\n  group  = c(\"产品A\",\"产品B\",\"产品C\"),\n  价格=c(80,65,90), 质量=c(90,70,75),\n  服务=c(70,85,80), 口碑=c(85,75,70), 创新=c(75,90,85)\n)\n\n# 转为长格式\nlong <- data |>\n  pivot_longer(-group, names_to=\"metric\", values_to=\"value\") |>\n  mutate(metric = factor(metric, unique(metric)))\n\nn_metrics <- n_distinct(long$metric)\nlong <- long |>\n  group_by(group) |>\n  mutate(angle = (as.integer(metric)-1) * 2*pi/n_metrics,\n         x = value * sin(angle),\n         y = value * cos(angle)) |>\n  ungroup()\n\np <- ggplot(long, aes(x=x, y=y, fill=group, color=group, group=group)) +\n  geom_polygon(alpha=", 
            fa, ", linewidth=", lw, ") +\n  coord_equal() +\n  scale_fill_brewer(palette=\"Set1\") +\n  scale_color_brewer(palette=\"Set1\") +\n  theme_void() +\n  labs(title=\"雷达图\")\n\nprint(p)")
    })

