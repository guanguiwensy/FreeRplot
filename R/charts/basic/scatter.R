# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "scatter", name = "散点图", name_en = "Scatter Plot", 
    category = "通用图表", plot_fn = function (data, options) 
    {
        pal <- get_palette(options$palette, 7)
        point_size <- as.numeric(options$point_size %||% 3)
        alpha <- as.numeric(options$alpha %||% 0.8)
        show_smooth <- isTRUE(options$show_smooth)
        smooth_method <- as.character(options$smooth_method %||% 
            "loess")
        show_ellipse <- isTRUE(options$ellipse)
        show_jitter <- isTRUE(options$show_jitter)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y))
        if (has_col(data, "group")) {
            if (show_jitter) {
                p <- p + ggplot2::geom_jitter(ggplot2::aes(color = factor(group)), 
                  size = point_size, alpha = alpha)
            }
            else {
                p <- p + ggplot2::geom_point(ggplot2::aes(color = factor(group)), 
                  size = point_size, alpha = alpha)
            }
            if (show_smooth) {
                p <- p + ggplot2::geom_smooth(ggplot2::aes(color = factor(group)), 
                  method = smooth_method, se = FALSE, linetype = "dashed", 
                  linewidth = 0.7, show.legend = FALSE)
            }
            if (show_ellipse) {
                p <- p + ggplot2::stat_ellipse(ggplot2::aes(color = factor(group)))
            }
            p <- p + ggplot2::scale_color_manual(values = pal, 
                name = "分组")
        }
        else {
            if (show_jitter) {
                p <- p + ggplot2::geom_jitter(size = point_size, 
                  alpha = alpha, color = pal[1])
            }
            else {
                p <- p + ggplot2::geom_point(size = point_size, 
                  alpha = alpha, color = pal[1])
            }
            if (show_smooth) {
                p <- p + ggplot2::geom_smooth(method = smooth_method, 
                  se = TRUE, color = pal[2], fill = pal[2], alpha = 0.15, 
                  linewidth = 0.9)
            }
            if (show_ellipse) {
                p <- p + ggplot2::stat_ellipse(color = pal[2])
            }
        }
        apply_theme(p, options)
    }, description = "展示两个连续变量之间的关系和分布", 
    best_for = "变量相关性分析、数据分布探索", 
    columns = "x(数值), y(数值), group(分组，可选)", 
    sample_data = structure(list(x = c(1, 2, 3, 4, 5, 6, 7, 8, 
    9, 10, 11, 12), y = c(2.1, 4, 3.2, 5.9, 5.1, 6.8, 7.3, 8.1, 
    8.7, 9.2, 10.5, 11.1), group = c("类别A", "类别B", "类别A", 
    "类别B", "类别A", "类别B", "类别A", "类别B", "类别A", 
    "类别B", "类别A", "类别B")), class = "data.frame", row.names = c(NA, 
    -12L)), options_def = list(list(id = "point_size", label = "点大小", 
        type = "slider", group = "basic", min = 0.5, max = 10, 
        step = 0.5, default = 3), list(id = "alpha", label = "点透明度", 
        type = "slider", group = "basic", min = 0.1, max = 1, 
        step = 0.05, default = 0.8), list(id = "show_smooth", 
        label = "添加趋势线", type = "checkbox", group = "basic", 
        default = FALSE), list(id = "smooth_method", label = "趋势线方法", 
        type = "select", group = "basic", choices = c(线性 = "lm", 
        局部回归 = "loess", GAM = "gam"), default = "loess", 
        show_when = "show_smooth"), list(id = "ellipse", label = "绘制置信椭圆", 
        type = "checkbox", group = "advanced", default = FALSE), 
        list(id = "show_jitter", label = "添加数据抖动", 
            type = "checkbox", group = "advanced", default = FALSE)), 
    code_template = function (options) 
    {
        pt <- options$point_size %||% 3
        al <- options$alpha %||% 0.8
        sm <- isTRUE(options$show_smooth)
        smm <- options$smooth_method %||% "loess"
        el <- isTRUE(options$ellipse)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  x     = c(1,2,3,4,5,6,7,8,9,10),\n  y     = c(2.1,4.0,3.2,5.9,5.1,6.8,7.3,8.1,8.7,9.2),\n  group = rep(c(\"类别A\",\"类别B\"), 5)\n)\n\np <- ggplot(data, aes(x=x, y=y, color=group)) +\n  geom_point(size=", 
            pt, ", alpha=", al, ")", if (sm) 
                paste0(" +\n  geom_smooth(method=\"", smm, "\", se=TRUE)")
            else "", if (el) 
                " +\n  stat_ellipse()"
            else "", "  +\n  scale_color_brewer(palette=\"Set1\") +\n  theme_minimal() +\n  labs(title=\"散点图\", x=\"X轴\", y=\"Y轴\")\n\nprint(p)")
    })

