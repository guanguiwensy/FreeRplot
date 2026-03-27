# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "lollipop", name = "棒棒糖图", category = "通用图表", 
    name_en = "Lollipop Chart", plot_fn = function (data, options) 
    {
        pal <- get_palette(options$palette, nrow(data))
        point_size <- as.numeric(options$point_size %||% 5)
        line_width <- as.numeric(options$line_width %||% 1)
        horizontal <- isTRUE(options$horizontal)
        show_values <- isTRUE(options$show_values)
        data <- data[order(data$value), ]
        data$category <- factor(data$category, levels = data$category)
        if (horizontal) {
            p <- ggplot2::ggplot(data, ggplot2::aes(x = value, 
                y = category)) + ggplot2::geom_segment(ggplot2::aes(x = 0, 
                xend = value, y = category, yend = category), 
                color = "gray70", linewidth = line_width) + ggplot2::geom_point(ggplot2::aes(color = category), 
                size = point_size, show.legend = FALSE) + ggplot2::scale_color_manual(values = pal)
            if (show_values) {
                p <- p + ggplot2::geom_text(ggplot2::aes(label = round(value, 
                  1)), hjust = -0.2, size = 3.5)
            }
        }
        else {
            p <- ggplot2::ggplot(data, ggplot2::aes(x = category, 
                y = value)) + ggplot2::geom_segment(ggplot2::aes(x = category, 
                xend = category, y = 0, yend = value), color = "gray70", 
                linewidth = line_width) + ggplot2::geom_point(ggplot2::aes(color = category), 
                size = point_size, show.legend = FALSE) + ggplot2::scale_color_manual(values = pal) + 
                ggplot2::coord_flip()
            if (show_values) {
                p <- p + ggplot2::geom_text(ggplot2::aes(label = round(value, 
                  1)), hjust = -0.2, size = 3.5)
            }
        }
        apply_theme(p, c(options, list(y_label = options$y_label %||% 
            "数值")))
    }, description = "柱状图变体，更简洁地展示排名和比较", 
    best_for = "排名展示、类别比较", columns = "category(类别), value(数值)", 
    sample_data = structure(list(category = c("数学", "语文", 
    "英语", "物理", "化学", "生物", "历史", "地理"
    ), value = c(88, 92, 76, 85, 90, 78, 82, 88)), class = "data.frame", row.names = c(NA, 
    -8L)), options_def = list(list(id = "point_size", label = "端点大小", 
        type = "slider", group = "basic", min = 1, max = 12, 
        step = 0.5, default = 5), list(id = "line_width", label = "杆宽", 
        type = "slider", group = "basic", min = 0.3, max = 3, 
        step = 0.1, default = 1), list(id = "horizontal", label = "横向布局", 
        type = "checkbox", group = "basic", default = FALSE), 
        list(id = "show_values", label = "显示数值", type = "checkbox", 
            group = "advanced", default = FALSE)), code_template = function (options) 
    {
        ps <- options$point_size %||% 5
        lw <- options$line_width %||% 1
        hz <- isTRUE(options$horizontal)
        sv <- isTRUE(options$show_values)
        if (hz) {
            paste0("library(ggplot2)\n\ndata <- data.frame(\n  category = c(\"数学\",\"语文\",\"英语\",\"物理\",\"化学\",\"生物\",\"历史\",\"地理\"),\n  value    = c(88,92,76,85,90,78,82,88)\n)\n\np <- ggplot(data, aes(x=value, y=reorder(category,value))) +\n  geom_segment(aes(x=0, xend=value, yend=category), linewidth=", 
                lw, ") +\n  geom_point(size=", ps, ", color=\"#2c7be5\")", 
                if (sv) 
                  " +\n  geom_text(aes(label=value), hjust=-0.3, size=3.5)"
                else "", "  +\n  theme_minimal() +\n  labs(title=\"棒棒糖图\", x=\"分数\", y=\"科目\")\n\nprint(p)")
        }
        else {
            paste0("library(ggplot2)\n\ndata <- data.frame(\n  category = c(\"数学\",\"语文\",\"英语\",\"物理\",\"化学\",\"生物\",\"历史\",\"地理\"),\n  value    = c(88,92,76,85,90,78,82,88)\n)\n\np <- ggplot(data, aes(x=reorder(category,-value), y=value)) +\n  geom_segment(aes(xend=category, y=0, yend=value), linewidth=", 
                lw, ") +\n  geom_point(size=", ps, ", color=\"#2c7be5\")", 
                if (sv) 
                  " +\n  geom_text(aes(label=value), vjust=-0.8, size=3.5)"
                else "", "  +\n  theme_minimal() +\n  labs(title=\"棒棒糖图\", x=\"科目\", y=\"分数\")\n\nprint(p)")
        }
    })

