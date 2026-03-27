# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "stacked_area", name = "堆叠面积图", category = "通用图表", 
    name_en = "Stacked Area Chart", plot_fn = function (data, 
        options) 
    {
        pal <- get_palette(options$palette, length(unique(data$group)))
        fill_alpha <- as.numeric(options$fill_alpha %||% 0.8)
        line_width <- as.numeric(options$line_width %||% 0.3)
        show_points <- isTRUE(options$show_points)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = value, 
            fill = group, group = group)) + ggplot2::geom_area(position = "stack", 
            alpha = fill_alpha, color = "white", linewidth = line_width) + 
            ggplot2::scale_fill_manual(values = pal, name = "分组")
        if (show_points) {
            p <- p + ggplot2::geom_point(ggplot2::aes(color = group), 
                size = 1.5, show.legend = FALSE) + ggplot2::scale_color_manual(values = pal)
        }
        apply_theme(p, options)
    }, description = "多组面积叠加，同时展示各组趋势和整体总量变化", 
    best_for = "多类别随时间的累积变化、占比趋势", 
    columns = "x(数值/时间), group(分组), value(数值)", 
    sample_data = structure(list(x = c(2018L, 2019L, 2020L, 2021L, 
    2022L, 2023L, 2018L, 2019L, 2020L, 2021L, 2022L, 2023L, 2018L, 
    2019L, 2020L, 2021L, 2022L, 2023L, 2018L, 2019L, 2020L, 2021L, 
    2022L, 2023L), group = c("华东", "华东", "华东", "华东", 
    "华东", "华东", "华南", "华南", "华南", "华南", 
    "华南", "华南", "华北", "华北", "华北", "华北", 
    "华北", "华北", "西部", "西部", "西部", "西部", 
    "西部", "西部"), value = c(120, 135, 128, 150, 168, 185, 
    90, 98, 105, 115, 112, 130, 70, 78, 82, 88, 95, 108, 45, 
    52, 58, 65, 72, 80)), class = "data.frame", row.names = c(NA, 
    -24L)), options_def = list(list(id = "fill_alpha", label = "填充透明度", 
        type = "slider", group = "basic", min = 0.1, max = 1, 
        step = 0.05, default = 0.8), list(id = "line_width", 
        label = "边框线宽", type = "slider", group = "basic", 
        min = 0, max = 2, step = 0.1, default = 0.3), list(id = "show_points", 
        label = "显示数据点", type = "checkbox", group = "advanced", 
        default = FALSE)), code_template = function (options) 
    {
        fa <- options$fill_alpha %||% 0.8
        lw <- options$line_width %||% 0.3
        sp <- isTRUE(options$show_points)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  x     = rep(2018:2023, 4),\n  group = rep(c(\"华东\",\"华南\",\"华北\",\"西部\"), each=6),\n  value = c(120,135,128,150,168,185, 90,98,105,115,112,130,\n            70,78,82,88,95,108, 45,52,58,65,72,80)\n)\n\np <- ggplot(data, aes(x=x, y=value, fill=group)) +\n  geom_area(alpha=", 
            fa, ", linewidth=", lw, ", color=\"white\", position=\"stack\")", 
            if (sp) 
                " +\n  geom_point(size=1.5, position=\"stack\")"
            else "", "  +\n  scale_fill_brewer(palette=\"Set2\") +\n  theme_minimal() +\n  labs(title=\"堆叠面积图\", x=\"年份\", y=\"销售额\")\n\nprint(p)")
    })

