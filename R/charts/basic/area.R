# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "area", name = "面积图", category = "通用图表", 
    name_en = "Area Chart", plot_fn = function (data, options) 
    {
        pal <- get_palette(options$palette, 7)
        fill_alpha <- as.numeric(options$fill_alpha %||% 0.6)
        line_width <- as.numeric(options$line_width %||% 0.8)
        show_points <- isTRUE(options$show_points)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y))
        if (has_col(data, "group")) {
            group_levels <- unique(as.character(data$group))
            pal <- palette_values_for_column(data, "group", options, 
                levels = group_levels, palette_name = options$palette)
            p <- p + ggplot2::geom_area(ggplot2::aes(fill = factor(group), 
                group = factor(group)), alpha = fill_alpha, position = "identity", 
                linewidth = line_width) + ggplot2::geom_line(ggplot2::aes(color = factor(group), 
                group = factor(group)), linewidth = line_width) + 
                ggplot2::scale_fill_manual(values = pal, name = "分组") + 
                ggplot2::scale_color_manual(values = pal, name = "分组")
        }
        else {
            p <- p + ggplot2::geom_area(fill = pal[1], alpha = fill_alpha, 
                linewidth = line_width) + ggplot2::geom_line(color = pal[1], 
                linewidth = line_width)
        }
        if (show_points) {
            if (has_col(data, "group")) {
                p <- p + ggplot2::geom_point(ggplot2::aes(color = factor(group)), 
                  size = 2)
            }
            else {
                p <- p + ggplot2::geom_point(color = pal[1], 
                  size = 2)
            }
        }
        apply_theme(p, options)
    }, description = "折线图变体，填充线下面积，强调量的变化", 
    best_for = "时间序列、累积量展示", columns = "x(数值/时间), y(数值), group(分组，可选)", 
    sample_data = structure(list(x = c(2018L, 2019L, 2020L, 2021L, 
    2022L, 2023L, 2018L, 2019L, 2020L, 2021L, 2022L, 2023L, 2018L, 
    2019L, 2020L, 2021L, 2022L, 2023L), y = c(100, 120, 115, 
    140, 160, 180, 80, 90, 95, 110, 105, 125, 60, 70, 80, 85, 
    95, 110), group = c("北区", "北区", "北区", "北区", 
    "北区", "北区", "中区", "中区", "中区", "中区", 
    "中区", "中区", "南区", "南区", "南区", "南区", 
    "南区", "南区")), class = "data.frame", row.names = c(NA, 
    -18L)), options_def = list(list(id = "fill_alpha", label = "填充透明度", 
        type = "slider", group = "basic", min = 0.1, max = 1, 
        step = 0.05, default = 0.6), list(id = "line_width", 
        label = "边框线宽", type = "slider", group = "basic", 
        min = 0, max = 3, step = 0.1, default = 0.8), list(id = "show_points", 
        label = "显示数据点", type = "checkbox", group = "advanced", 
        default = FALSE)), code_template = function (options) 
    {
        fa <- options$fill_alpha %||% 0.6
        lw <- options$line_width %||% 0.8
        sp <- isTRUE(options$show_points)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  x     = rep(2018:2023, 3),\n  y     = c(100,120,115,140,160,180, 80,90,95,110,105,125, 60,70,80,85,95,110),\n  group = rep(c(\"北区\",\"中区\",\"南区\"), each=6)\n)\n\np <- ggplot(data, aes(x=x, y=y, fill=group, color=group, group=group)) +\n  geom_area(alpha=", 
            fa, ", linewidth=", lw, ")", if (sp) 
                " +\n  geom_point(size=2)"
            else "", "  +\n  scale_fill_brewer(palette=\"Set2\") +\n  scale_color_brewer(palette=\"Set2\") +\n  theme_minimal() +\n  labs(title=\"面积图\", x=\"年份\", y=\"数值\")\n\nprint(p)")
    })

