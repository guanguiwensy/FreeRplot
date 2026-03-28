# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "line", name = "折线图", category = "通用图表", 
    name_en = "Line Chart", plot_fn = function (data, options) 
    {
        pal <- get_palette(options$palette, 7)
        line_width <- as.numeric(options$line_width %||% 1)
        show_points <- isTRUE(options$show_points %||% TRUE)
        point_size <- as.numeric(options$point_size %||% 2.5)
        show_smooth <- isTRUE(options$show_smooth)
        smooth_method <- as.character(options$smooth_method %||% 
            "loess")
        line_type <- as.character(options$line_type %||% "solid")
        p <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y))
        if (has_col(data, "group")) {
            group_levels <- unique(as.character(data$group))
            pal <- palette_values_for_column(data, "group", options, 
                levels = group_levels, palette_name = options$palette)
            p <- p + ggplot2::geom_line(ggplot2::aes(color = factor(group), 
                group = factor(group)), linewidth = line_width, 
                linetype = line_type)
            if (show_points) {
                p <- p + ggplot2::geom_point(ggplot2::aes(color = factor(group)), 
                  size = point_size)
            }
            if (show_smooth) {
                p <- p + ggplot2::geom_smooth(ggplot2::aes(color = factor(group), 
                  group = factor(group)), method = smooth_method, 
                  se = FALSE, show.legend = FALSE)
            }
            p <- p + ggplot2::scale_color_manual(values = pal, 
                name = "分组")
        }
        else {
            p <- p + ggplot2::geom_line(color = pal[1], linewidth = line_width, 
                linetype = line_type)
            if (show_points) {
                p <- p + ggplot2::geom_point(color = pal[1], 
                  size = point_size)
            }
            if (show_smooth) {
                p <- p + ggplot2::geom_smooth(method = smooth_method, 
                  se = TRUE, color = pal[2], fill = pal[2], alpha = 0.15)
            }
        }
        apply_theme(p, options)
    }, description = "展示数据随时间或顺序的变化趋势", 
    best_for = "时间序列分析、趋势变化展示", columns = "x(数值/时间), y(数值), group(分组，可选)", 
    sample_data = structure(list(x = c(1L, 2L, 3L, 4L, 5L, 6L, 
    1L, 2L, 3L, 4L, 5L, 6L), y = c(10, 15, 13, 18, 20, 25, 8, 
    12, 10, 14, 17, 22), group = c("产品A", "产品A", "产品A", 
    "产品A", "产品A", "产品A", "产品B", "产品B", "产品B", 
    "产品B", "产品B", "产品B")), class = "data.frame", row.names = c(NA, 
    -12L)), options_def = list(list(id = "line_width", label = "线宽", 
        type = "slider", group = "basic", min = 0.3, max = 4, 
        step = 0.25, default = 1), list(id = "show_points", label = "显示数据点", 
        type = "checkbox", group = "basic", default = TRUE), 
        list(id = "point_size", label = "点大小", type = "slider", 
            group = "basic", min = 0.5, max = 8, step = 0.5, 
            default = 2.5), list(id = "show_smooth", label = "添加平滑线", 
            type = "checkbox", group = "advanced", default = FALSE), 
        list(id = "smooth_method", label = "平滑方法", type = "select", 
            group = "advanced", choices = c(线性 = "lm", 局部回归 = "loess"
            ), default = "loess", show_when = "show_smooth"), 
        list(id = "line_type", label = "线型", type = "select", 
            group = "advanced", choices = c(实线 = "solid", 
            虚线 = "dashed", 点线 = "dotted"), default = "solid")), 
    code_template = function (options) 
    {
        lw <- options$line_width %||% 1
        sp <- isTRUE(options$show_points %||% TRUE)
        ps <- options$point_size %||% 2.5
        lt <- options$line_type %||% "solid"
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  x     = rep(1:6, 2),\n  y     = c(10,15,13,18,20,25, 8,12,10,14,17,22),\n  group = rep(c(\"产品A\",\"产品B\"), each=6)\n)\n\np <- ggplot(data, aes(x=x, y=y, color=group, group=group)) +\n  geom_line(linewidth=", 
            lw, ", linetype=\"", lt, "\")", if (sp) 
                paste0(" +\n  geom_point(size=", ps, ")")
            else "", "  +\n  scale_color_brewer(palette=\"Set1\") +\n  theme_minimal() +\n  labs(title=\"折线图\", x=\"时间\", y=\"数值\")\n\nprint(p)")
    })

