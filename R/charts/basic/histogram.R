# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "histogram", name = "直方图", category = "通用图表", 
    name_en = "Histogram", plot_fn = function (data, options) 
    {
        pal <- get_palette(options$palette, 7)
        bins <- suppressWarnings(as.integer(options$bins %||% 
            30))
        if (is.na(bins) || bins < 1) 
            bins <- 30
        fill_alpha <- as.numeric(options$fill_alpha %||% 0.85)
        show_density <- isTRUE(options$show_density)
        show_rug <- isTRUE(options$show_rug)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = value))
        if (has_col(data, "group")) {
            p <- p + ggplot2::geom_histogram(ggplot2::aes(fill = factor(group)), 
                bins = bins, alpha = fill_alpha, position = "identity", 
                color = "white") + ggplot2::scale_fill_manual(values = pal, 
                name = "分组")
        }
        else {
            p <- p + ggplot2::geom_histogram(bins = bins, fill = pal[1], 
                color = "white", alpha = fill_alpha)
        }
        if (show_density) {
            if (has_col(data, "group")) {
                p <- p + ggplot2::geom_density(ggplot2::aes(y = ggplot2::after_stat(count), 
                  color = factor(group)), linewidth = 1, show.legend = FALSE) + 
                  ggplot2::scale_color_manual(values = pal)
            }
            else {
                p <- p + ggplot2::geom_density(ggplot2::aes(y = ggplot2::after_stat(count)), 
                  color = pal[2], linewidth = 1)
            }
        }
        if (show_rug) {
            p <- p + ggplot2::geom_rug(alpha = 0.3)
        }
        apply_theme(p, c(options, list(x_label = options$x_label %||% 
            "数值", y_label = options$y_label %||% "频数")))
    }, description = "展示单个连续变量的分布情况", 
    best_for = "数据分布分析、频率统计", columns = "value(数值), group(分组，可选)", options_def = list(
        list(id = "bins", label = "分箱数", type = "slider", 
            group = "basic", min = 5, max = 100, step = 1, default = 30), 
        list(id = "fill_alpha", label = "填充透明度", type = "slider", 
            group = "basic", min = 0.1, max = 1, step = 0.05, 
            default = 0.85), list(id = "show_density", label = "叠加密度曲线", 
            type = "checkbox", group = "advanced", default = FALSE), 
        list(id = "show_rug", label = "显示地毯图", type = "checkbox", 
            group = "advanced", default = FALSE)), code_template = function (options) 
    {
        bn <- as.integer(options$bins %||% 30)
        fa <- options$fill_alpha %||% 0.85
        sd_ <- isTRUE(options$show_density)
        sr <- isTRUE(options$show_rug)
        paste0("library(ggplot2)\n\nset.seed(42)\ndata <- data.frame(\n  value = c(rnorm(50, 170, 8), rnorm(50, 162, 7)),\n  group = rep(c(\"男\",\"女\"), each=50)\n)\n\np <- ggplot(data, aes(x=value, fill=group)) +\n  geom_histogram(bins=", 
            bn, ", alpha=", fa, ", position=\"identity\")", if (sd_) 
                " +\n  geom_density(aes(y=after_stat(count)), color=\"black\", linewidth=0.8)"
            else "", if (sr) 
                " +\n  geom_rug(alpha=0.3)"
            else "", "  +\n  scale_fill_brewer(palette=\"Set1\") +\n  theme_minimal() +\n  labs(title=\"直方图\", x=\"数值\", y=\"频数\")\n\nprint(p)")
    })

