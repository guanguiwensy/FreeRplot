# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_sorted", name = "排序柱状图", name_en = "Sorted Bar Chart", 
    plot_fn = function (data, options = list()) 
    {
        x_col <- names(data)[1]
        y_col <- if (ncol(data) >= 2) 
            names(data)[2]
        else names(data)[1]
        pal_name <- options$color_palette %||% options$palette %||% 
            "默认"
        sortit <- options$sort_bars %||% "desc"
        orient <- options$orientation %||% "vertical"
        use_color <- isTRUE(options$color_by_value)
        bw <- as.numeric(options$bar_width %||% 0.7)
        alp <- as.numeric(options$alpha %||% 0.9)
        lbls <- isTRUE(options$show_labels)
        df <- data.frame(x = as.character(data[[x_col]]), y = as.numeric(data[[y_col]]), 
            stringsAsFactors = FALSE)
        df <- df[!is.na(df$y), ]
        if (sortit == "desc") 
            df$x <- reorder(df$x, -df$y)
        if (sortit == "asc") 
            df$x <- reorder(df$x, df$y)
        pal <- get_palette(pal_name, nrow(df))
        lp <- .bar_label_params(orient)
        if (use_color) {
            p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, 
                fill = y)) + ggplot2::geom_col(alpha = alp, width = bw, 
                color = NA) + ggplot2::scale_fill_gradient(low = pal[1], 
                high = pal[min(length(pal), 5)], guide = "none")
        }
        else {
            p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) + 
                ggplot2::geom_col(fill = pal[1], alpha = alp, 
                  width = bw, color = NA)
        }
        if (lbls) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = round(y, 
                1)), vjust = lp$vjust, hjust = lp$hjust, size = 3.5, 
                color = "#333333")
        }
        p <- .bar_orient(p, orient)
        apply_theme(p + ggplot2::labs(x = x_col, y = y_col), 
            options)
    }, category = "柱图家族", description = "按数值大小排序的柱图，可选颜色随数值渐变", 
    best_for = "变量重要性排序、得分对比", columns = "x(类别), y(数值)", options_def = list(list(id = "color_palette", label = "配色", 
        type = "select", group = "basic", choices = c(默认 = "默认", 
        商务蓝 = "商务蓝", 自然绿 = "自然绿", 活力橙 = "活力橙", 
        粉紫系 = "粉紫系"), default = "默认"), list(id = "sort_bars", 
        label = "排序方式", type = "select", group = "basic", 
        choices = c(降序 = "desc", 升序 = "asc", 不排序 = "none"
        ), default = "desc"), list(id = "orientation", label = "方向", 
        type = "select", group = "basic", choices = c(纵向 = "vertical", 
        横向 = "horizontal"), default = "vertical"), list(id = "color_by_value", 
        label = "颜色映射数值", type = "checkbox", group = "basic", 
        default = FALSE), list(id = "show_labels", label = "显示数值标签", 
        type = "checkbox", group = "basic", default = FALSE), 
        list(id = "bar_width", label = "柱宽", type = "slider", 
            group = "advanced", min = 0.2, max = 1, step = 0.05, 
            default = 0.7), list(id = "alpha", label = "透明度", 
            type = "slider", group = "advanced", min = 0.1, max = 1, 
            step = 0.05, default = 0.9)), code_template = function (options) 
    {
        pal <- options$color_palette %||% "Set2"
        sortit <- options$sort_bars %||% "desc"
        orient <- options$orientation %||% "vertical"
        cbv <- isTRUE(options$color_by_value)
        bw <- options$bar_width %||% 0.7
        alp <- options$alpha %||% 0.9
        lbls <- isTRUE(options$show_labels)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  city  = c(\"北京\",\"上海\",\"广州\",\"深圳\",\"成都\",\"武汉\",\"杭州\",\"重庆\",\"西安\",\"南京\"),\n  value = c(42.6, 44.4, 28.8, 32.4, 22.1, 18.9, 18.9, 29.1, 10.7, 16.4)\n)\n", 
            if (sortit == "desc") 
                "data$city <- reorder(data$city, -data$value)\n"
            else if (sortit == "asc") 
                "data$city <- reorder(data$city,  data$value)\n"
            else "", if (cbv) {
                paste0("p <- ggplot(data, aes(x = city, y = value, fill = value)) +\n", 
                  "  geom_col(alpha = ", alp, ", width = ", bw, 
                  ") +\n", "  scale_fill_gradient(low = \"#fee8c8\", high = \"#e34a33\", guide = \"none\")")
            }
            else {
                paste0("p <- ggplot(data, aes(x = city, y = value)) +\n", 
                  "  geom_col(fill = \"#4ECDC4\", alpha = ", 
                  alp, ", width = ", bw, ")")
            }, if (lbls) 
                " +\n  geom_text(aes(label = round(value, 1)), vjust = -0.4, size = 3.5)"
            else "", if (orient == "horizontal") 
                " +\n  coord_flip()"
            else "", " +\n  labs(x = NULL, y = \"GDP（千亿元）\") +\n  theme_minimal()\n\nprint(p)")
    })

