# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "violin", name = "小提琴图", category = "通用图表", 
    name_en = "Violin Plot", plot_fn = function (data, options) 
    {
        group_levels <- unique(as.character(data$group))
        pal <- palette_values_for_column(data, "group", options, 
            levels = group_levels, palette_name = options$palette)
        show_boxplot <- if (is.null(options$show_boxplot)) 
            TRUE
        else isTRUE(options$show_boxplot)
        trim <- isTRUE(options$trim)
        fill_alpha <- as.numeric(options$fill_alpha %||% 0.7)
        scale_type <- as.character(options$scale_type %||% "area")
        bw_adjust <- as.numeric(options$bw_adjust %||% 1)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = factor(group), 
            y = value, fill = factor(group))) + ggplot2::geom_violin(alpha = fill_alpha, 
            trim = trim, scale = scale_type, adjust = bw_adjust) + 
            ggplot2::scale_fill_manual(values = pal) + ggplot2::theme(legend.position = "none")
        if (show_boxplot) {
            p <- p + ggplot2::geom_boxplot(width = 0.12, fill = "white", 
                outlier.shape = NA)
        }
        apply_theme(p, c(options, list(x_label = options$x_label %||% 
            "分组", y_label = options$y_label %||% "数值")))
    }, description = "展示数据分布密度，结合箱线图优点", 
    best_for = "多组数据分布形状比较", columns = "group(分组), value(数值)", options_def = list(list(id = "show_boxplot", label = "内嵌箱线图", 
        type = "checkbox", group = "basic", default = TRUE), 
        list(id = "trim", label = "裁剪尾端", type = "checkbox", 
            group = "basic", default = FALSE), list(id = "fill_alpha", 
            label = "填充透明度", type = "slider", group = "basic", 
            min = 0.1, max = 1, step = 0.05, default = 0.7), 
        list(id = "scale_type", label = "缩放方式", type = "select", 
            group = "advanced", choices = c(面积相等 = "area", 
            按计数 = "count", 宽度相等 = "width"), default = "area"), 
        list(id = "bw_adjust", label = "带宽调整", type = "slider", 
            group = "advanced", min = 0.3, max = 3, step = 0.1, 
            default = 1)), code_template = function (options) 
    {
        sbp <- isTRUE(options$show_boxplot %||% TRUE)
        tr <- isTRUE(options$trim)
        fa <- options$fill_alpha %||% 0.7
        sc <- options$scale_type %||% "area"
        bwa <- options$bw_adjust %||% 1
        paste0("library(ggplot2)\n\nset.seed(42)\ndata <- data.frame(\n  group = rep(c(\"处理A\",\"处理B\",\"处理C\"), each=30),\n  value = c(rnorm(30,5,1), rnorm(30,7,2), c(rnorm(15,4,0.5), rnorm(15,8,0.5)))\n)\n\np <- ggplot(data, aes(x=group, y=value, fill=group)) +\n  geom_violin(trim=", 
            tr, ", alpha=", fa, ", scale=\"", sc, "\", adjust=", 
            bwa, ")", if (sbp) 
                " +\n  geom_boxplot(width=0.12, fill=\"white\", outlier.shape=NA)"
            else "", "  +\n  scale_fill_brewer(palette=\"Set2\") +\n  theme_minimal() +\n  labs(title=\"小提琴图\", x=\"处理组\", y=\"数值\")\n\nprint(p)")
    })

