# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "density", name = "密度图", category = "通用图表", 
    name_en = "Density Plot", plot_fn = function (data, options) 
    {
        group_levels <- unique(as.character(data$group))
        pal <- palette_values_for_column(data, "group", options, 
            levels = group_levels, palette_name = options$palette)
        fill_alpha <- as.numeric(options$fill_alpha %||% 0.6)
        line_width <- as.numeric(options$line_width %||% 1)
        bw_adjust <- as.numeric(options$bw_adjust %||% 1)
        show_rug <- isTRUE(options$show_rug)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = value))
        if (has_col(data, "group")) {
            p <- p + ggplot2::geom_density(ggplot2::aes(fill = factor(group), 
                color = factor(group)), alpha = fill_alpha, linewidth = line_width, 
                adjust = bw_adjust) + ggplot2::scale_fill_manual(values = pal, 
                name = "分组") + ggplot2::scale_color_manual(values = pal, 
                name = "分组")
        }
        else {
            p <- p + ggplot2::geom_density(fill = pal[1], color = pal[2], 
                alpha = fill_alpha, linewidth = line_width, adjust = bw_adjust)
        }
        if (show_rug) {
            p <- p + ggplot2::geom_rug(alpha = 0.3)
        }
        apply_theme(p, c(options, list(x_label = options$x_label %||% 
            "数值", y_label = options$y_label %||% "密度")))
    }, description = "平滑的直方图，展示连续变量的概率密度", 
    best_for = "数据分布形状、多组分布比较", columns = "value(数值), group(分组，可选)", options_def = list(list(id = "fill_alpha", label = "填充透明度", 
        type = "slider", group = "basic", min = 0.1, max = 1, 
        step = 0.05, default = 0.6), list(id = "line_width", 
        label = "线宽", type = "slider", group = "basic", min = 0.3, 
        max = 3, step = 0.1, default = 1), list(id = "bw_adjust", 
        label = "带宽调整", type = "slider", group = "advanced", 
        min = 0.1, max = 3, step = 0.1, default = 1), list(id = "show_rug", 
        label = "显示地毯图", type = "checkbox", group = "advanced", 
        default = FALSE)), code_template = function (options) 
    {
        fa <- options$fill_alpha %||% 0.6
        lw <- options$line_width %||% 1
        bwa <- options$bw_adjust %||% 1
        sr <- isTRUE(options$show_rug)
        paste0("library(ggplot2)\n\nset.seed(42)\ndata <- data.frame(\n  value = c(rnorm(100,0,1), rnorm(100,2,1.5)),\n  group = rep(c(\"分布A\",\"分布B\"), each=100)\n)\n\np <- ggplot(data, aes(x=value, fill=group, color=group)) +\n  geom_density(alpha=", 
            fa, ", linewidth=", lw, ", adjust=", bwa, ")", if (sr) 
                " +\n  geom_rug(alpha=0.3)"
            else "", "  +\n  scale_fill_brewer(palette=\"Set1\") +\n  scale_color_brewer(palette=\"Set1\") +\n  theme_minimal() +\n  labs(title=\"密度图\", x=\"数值\", y=\"密度\")\n\nprint(p)")
    })

