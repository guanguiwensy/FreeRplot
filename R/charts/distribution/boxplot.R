# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "boxplot", name = "箱线图", category = "通用图表", 
    name_en = "Box Plot", plot_fn = function (data, options) 
    {
        group_levels <- unique(as.character(data$group))
        pal <- palette_values_for_column(data, "group", options, 
            levels = group_levels, palette_name = options$palette)
        show_points <- isTRUE(options$show_points)
        notch <- isTRUE(options$notch)
        box_width <- as.numeric(options$box_width %||% 0.6)
        point_alpha <- as.numeric(options$point_alpha %||% 0.4)
        point_size <- as.numeric(options$point_size %||% 1.5)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = factor(group), 
            y = value, fill = factor(group))) + ggplot2::geom_boxplot(alpha = 0.7, 
            outlier.shape = 21, outlier.size = 2, notch = notch, 
            width = box_width) + ggplot2::scale_fill_manual(values = pal) + 
            ggplot2::theme(legend.position = "none")
        if (show_points) {
            p <- p + ggplot2::geom_jitter(width = 0.2, alpha = point_alpha, 
                size = point_size)
        }
        apply_theme(p, c(options, list(x_label = options$x_label %||% 
            "分组", y_label = options$y_label %||% "数值")))
    }, description = "展示数据的分布、中位数、四分位数和异常值", 
    best_for = "数据分布比较、异常值检测", columns = "group(分组), value(数值)", options_def = list(list(id = "show_points", label = "叠加原始数据点", 
        type = "checkbox", group = "basic", default = FALSE), 
        list(id = "notch", label = "显示缺口(notch)", type = "checkbox", 
            group = "basic", default = FALSE), list(id = "box_width", 
            label = "箱宽", type = "slider", group = "advanced", 
            min = 0.2, max = 0.9, step = 0.05, default = 0.6), 
        list(id = "point_alpha", label = "数据点透明度", 
            type = "slider", group = "advanced", min = 0.1, max = 1, 
            step = 0.05, default = 0.4, show_when = "show_points"), 
        list(id = "point_size", label = "数据点大小", type = "slider", 
            group = "advanced", min = 0.5, max = 5, step = 0.25, 
            default = 1.5, show_when = "show_points")), code_template = function (options) 
    {
        bw <- options$box_width %||% 0.6
        nc <- isTRUE(options$notch)
        sp <- isTRUE(options$show_points)
        pa <- options$point_alpha %||% 0.4
        ps <- options$point_size %||% 1.5
        paste0("library(ggplot2)\n\nset.seed(42)\ndata <- data.frame(\n  group = rep(c(\"A组\",\"B组\",\"C组\"), each=20),\n  value = c(rnorm(20,10,2), rnorm(20,12,3), rnorm(20,8,1.5))\n)\n\np <- ggplot(data, aes(x=group, y=value, fill=group)) +\n  geom_boxplot(width=", 
            bw, ", notch=", nc, ", outlier.shape=21, alpha=0.8)", 
            if (sp) 
                paste0(" +\n  geom_jitter(width=0.2, alpha=", 
                  pa, ", size=", ps, ")")
            else "", "  +\n  scale_fill_brewer(palette=\"Set2\") +\n  theme_minimal() +\n  labs(title=\"箱线图\", x=\"分组\", y=\"数值\")\n\nprint(p)")
    })

