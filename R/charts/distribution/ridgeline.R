# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "ridgeline", name = "山脊图", category = "通用图表", 
    name_en = "Ridgeline Plot", plot_fn = function (data, options) 
    {
        pal <- get_palette(options$palette, length(unique(data$group)))
        fill_alpha <- as.numeric(options$fill_alpha %||% 0.7)
        overlap <- as.numeric(options$overlap %||% 0.8)
        bw_adjust <- as.numeric(options$bw_adjust %||% 1)
        show_points <- isTRUE(options$show_points)
        data$group <- factor(data$group, levels = rev(unique(data$group)))
        if (show_points) {
            p <- ggplot2::ggplot(data, ggplot2::aes(x = value, 
                y = group, fill = group)) + ggridges::geom_density_ridges(alpha = fill_alpha, 
                scale = overlap, quantile_lines = TRUE, quantiles = 2, 
                color = "white", linewidth = 0.5, jittered_points = TRUE, 
                point_alpha = 0.3, point_size = 0.5)
        }
        else {
            p <- ggplot2::ggplot(data, ggplot2::aes(x = value, 
                y = group, fill = group)) + ggridges::geom_density_ridges(alpha = fill_alpha, 
                scale = overlap, quantile_lines = TRUE, quantiles = 2, 
                color = "white", linewidth = 0.5, bandwidth = bw_adjust)
        }
        p <- p + ggplot2::scale_fill_manual(values = pal, guide = "none") + 
            ggridges::theme_ridges(grid = FALSE) + ggplot2::labs(title = options$title %||% 
            NULL, x = options$x_label %||% "数值", y = options$y_label %||% 
            NULL) + ggplot2::theme(plot.title = ggplot2::element_text(size = 14, 
            face = "bold", hjust = 0.5))
        p
    }, description = "多组水平密度曲线叠放，直观比较各组分布形状与峰值位置", 
    best_for = "多组/多时段分布对比、展示分布随类别的变化规律", 
    columns = "group(分组), value(数值)", options_def = list(list(id = "fill_alpha", label = "填充透明度", 
        type = "slider", group = "basic", min = 0.1, max = 1, 
        step = 0.05, default = 0.7), list(id = "overlap", label = "曲线重叠度", 
        type = "slider", group = "basic", min = 0.1, max = 3, 
        step = 0.1, default = 0.8), list(id = "bw_adjust", label = "带宽调整", 
        type = "slider", group = "advanced", min = 0.2, max = 3, 
        step = 0.1, default = 1), list(id = "show_points", label = "显示数据点", 
        type = "checkbox", group = "advanced", default = FALSE)), 
    code_template = function (options) 
    {
        fa <- options$fill_alpha %||% 0.7
        ov <- options$overlap %||% 0.8
        bwa <- options$bw_adjust %||% 1
        sp <- isTRUE(options$show_points)
        paste0("library(ggplot2)\nlibrary(ggridges)\n\nset.seed(42)\ndata <- data.frame(\n  group = rep(c(\"一月\",\"二月\",\"三月\",\"四月\",\"五月\"), each=30),\n  value = c(rnorm(30,5,1.5), rnorm(30,8,2), rnorm(30,12,2.5),\n            rnorm(30,15,2),  rnorm(30,18,1.8))\n)\n\np <- ggplot(data, aes(x=value, y=group, fill=group)) +\n  geom_density_ridges(alpha=", 
            fa, ", scale=", ov, ",\n                      bandwidth=", 
            bwa * 0.5, ",\n                      jittered_points=", 
            sp, ", point_alpha=0.3, point_size=0.5) +\n  scale_fill_brewer(palette=\"RdYlBu\") +\n  theme_ridges() +\n  labs(title=\"山脊图\", x=\"数值\", y=\"月份\")\n\nprint(p)")
    })

