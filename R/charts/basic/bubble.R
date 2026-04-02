# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bubble", name = "气泡图", category = "通用图表", 
    name_en = "Bubble Chart", plot_fn = function (data, options) 
    {
        pal <- get_palette(options$palette, 7)
        size_min <- as.numeric(options$size_min %||% 3)
        size_max <- as.numeric(options$size_max %||% 15)
        alpha <- as.numeric(options$alpha %||% 0.7)
        show_labels <- isTRUE(options$show_labels)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y, 
            size = size))
        if (has_col(data, "group")) {
            p <- p + ggplot2::geom_point(ggplot2::aes(color = factor(group)), 
                alpha = alpha) + ggplot2::scale_color_manual(values = pal, 
                name = "分组")
        }
        else {
            p <- p + ggplot2::geom_point(alpha = alpha, color = pal[1])
        }
        if (show_labels && has_col(data, "label")) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = label), 
                vjust = -1, size = 3.2, color = "gray20")
        }
        else if (!show_labels && has_col(data, "label")) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = label), 
                vjust = -1, size = 3.2, color = "gray20")
        }
        p <- p + ggplot2::scale_size_continuous(range = c(size_min, 
            size_max), name = "大小")
        apply_theme(p, options)
    }, description = "散点图变体，用气泡大小编码第三个变量", 
    best_for = "三变量关系展示", columns = "x(数值), y(数值), size(气泡大小), label(标签，可选), group(分组，可选)", options_def = list(list(id = "size_min", label = "最小气泡尺寸", 
        type = "slider", group = "basic", min = 0.5, max = 10, 
        step = 0.5, default = 3), list(id = "size_max", label = "最大气泡尺寸", 
        type = "slider", group = "basic", min = 5, max = 35, 
        step = 1, default = 15), list(id = "alpha", label = "透明度", 
        type = "slider", group = "basic", min = 0.1, max = 1, 
        step = 0.05, default = 0.7), list(id = "show_labels", 
        label = "显示标签", type = "checkbox", group = "advanced", 
        default = FALSE)), code_template = function (options) 
    {
        smn <- options$size_min %||% 3
        smx <- options$size_max %||% 15
        al <- options$alpha %||% 0.7
        sl <- isTRUE(options$show_labels)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  x     = c(1,2,3,4,5,6,7),\n  y     = c(10,20,15,25,18,30,22),\n  size  = c(10,30,15,45,20,60,25),\n  label = c(\"A\",\"B\",\"C\",\"D\",\"E\",\"F\",\"G\"),\n  group = c(\"X\",\"X\",\"Y\",\"Y\",\"X\",\"Y\",\"X\")\n)\n\np <- ggplot(data, aes(x=x, y=y, size=size, color=group)) +\n  geom_point(alpha=", 
            al, ")", if (sl) 
                " +\n  geom_text(aes(label=label), vjust=-1.2, size=3.5, show.legend=FALSE)"
            else "", "  +\n  scale_size(range=c(", smn, ",", 
            smx, ")) +\n  scale_color_brewer(palette=\"Set1\") +\n  theme_minimal() +\n  labs(title=\"气泡图\", x=\"X轴\", y=\"Y轴\", size=\"权重\")\n\nprint(p)")
    })

