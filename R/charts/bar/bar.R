# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar", name = "柱状图", category = "通用图表", 
    name_en = "Bar Chart", plot_fn = function (data, options) 
    {
        n_cat <- length(unique(data$category))
        target_col <- if (!is.null(g_col)) "group" else "x"
        target_levels <- if (!is.null(g_col)) unique(df$group) else unique(df$x)
        pal <- palette_values_for_column(df, target_col, options, 
            levels = target_levels, palette_name = options$palette)
        orientation <- as.character(options$orientation %||% 
            "vertical")
        show_value_labels <- isTRUE(options$show_value_labels)
        stack_mode <- as.character(options$stack_mode %||% "dodge")
        bar_alpha <- as.numeric(options$bar_alpha %||% 0.9)
        bar_width <- as.numeric(options$bar_width %||% 0.7)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = reorder(category, 
            -value), y = value))
        if (has_col(data, "group")) {
            p <- p + ggplot2::geom_col(ggplot2::aes(fill = factor(group)), 
                position = stack_mode, width = bar_width, alpha = bar_alpha) + 
                ggplot2::scale_fill_manual(values = pal, name = "分组")
        }
        else {
            p <- p + ggplot2::geom_col(ggplot2::aes(fill = category), 
                width = bar_width, alpha = bar_alpha, show.legend = FALSE) + 
                ggplot2::scale_fill_manual(values = pal)
        }
        if (show_value_labels) {
            if (orientation == "horizontal") {
                p <- p + ggplot2::geom_text(ggplot2::aes(label = value), 
                  hjust = -0.1, size = 3.5)
            }
            else {
                p <- p + ggplot2::geom_text(ggplot2::aes(label = value), 
                  vjust = -0.3, size = 3.5)
            }
        }
        if (orientation == "horizontal") {
            p <- p + ggplot2::coord_flip()
        }
        apply_theme(p, options)
    }, description = "比较不同类别的数值大小", best_for = "类别比较、排名展示", 
    columns = "category(类别), value(数值), group(分组，可选)", options_def = list(list(id = "orientation", label = "方向", 
        type = "select", group = "basic", choices = c(纵向 = "vertical", 
        横向 = "horizontal"), default = "vertical"), list(id = "show_value_labels", 
        label = "显示数值标签", type = "checkbox", group = "basic", 
        default = FALSE), list(id = "stack_mode", label = "分组模式", 
        type = "select", group = "basic", choices = c(并列 = "dodge", 
        堆叠 = "stack", 填充 = "fill"), default = "dodge"), 
        list(id = "bar_alpha", label = "填充透明度", type = "slider", 
            group = "advanced", min = 0.3, max = 1, step = 0.05, 
            default = 0.9), list(id = "bar_width", label = "柱宽", 
            type = "slider", group = "advanced", min = 0.2, max = 0.95, 
            step = 0.05, default = 0.7)), code_template = function (options) 
    {
        ori <- options$orientation %||% "vertical"
        slm <- options$stack_mode %||% "dodge"
        bw <- options$bar_width %||% 0.7
        ba <- options$bar_alpha %||% 0.9
        svl <- isTRUE(options$show_value_labels)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  category = c(\"北京\",\"上海\",\"广州\",\"深圳\",\"杭州\",\"成都\"),\n  value    = c(3.6, 3.8, 2.5, 2.8, 1.8, 2.1),\n  group    = c(\"一线\",\"一线\",\"新一线\",\"一线\",\"新一线\",\"新一线\")\n)\n\np <- ggplot(data, aes(x=category, y=value, fill=group)) +\n  geom_bar(stat=\"identity\", position=\"", 
            slm, "\",\n           width=", bw, ", alpha=", ba, 
            ")", if (svl) 
                " +\n  geom_text(aes(label=round(value,1)), vjust=-0.3, size=3.5)"
            else "", if (ori == "horizontal") 
                " +\n  coord_flip()"
            else "", "  +\n  scale_fill_brewer(palette=\"Set2\") +\n  theme_minimal() +\n  labs(title=\"柱状图\", x=\"城市\", y=\"GDP(万亿)\")\n\nprint(p)")
    })

