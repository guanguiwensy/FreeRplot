# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_horizontal", name = "横向排序柱状图", name_en = "Horizontal Bar Chart", 
    plot_fn = function (data, options = list()) 
    {
        x_col <- names(data)[1]
        y_col <- if (ncol(data) >= 2) 
            names(data)[2]
        else names(data)[1]
        fcol <- options$fill_color %||% "#FF6B6B"
        topn <- as.integer(options$top_n %||% 0)
        sortit <- options$sort_bars %||% "desc"
        bw <- as.numeric(options$bar_width %||% 0.7)
        alp <- as.numeric(options$alpha %||% 0.9)
        lbls <- isTRUE(options$show_labels)
        lsz <- as.numeric(options$label_size %||% 3.5)
        df <- data.frame(x = as.character(data[[x_col]]), y = as.numeric(data[[y_col]]), 
            stringsAsFactors = FALSE)
        df <- df[!is.na(df$y), ]
        if (sortit == "desc") 
            df <- df[order(-df$y), ]
        if (sortit == "asc") 
            df <- df[order(df$y), ]
        if (topn > 0 && topn < nrow(df)) 
            df <- df[seq_len(topn), ]
        df$x <- factor(df$x, levels = rev(df$x))
        p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) + 
            ggplot2::geom_col(fill = fcol, alpha = alp, width = bw, 
                color = NA) + ggplot2::coord_flip()
        if (lbls) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = round(y, 
                1)), hjust = -0.2, size = lsz, color = "#333333") + 
                ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 
                  0.15)))
        }
        apply_theme(p + ggplot2::labs(x = x_col, y = y_col), 
            options)
    }, category = "柱图家族", description = "横向排列柱图，适合长标签和 TopN 排名展示", 
    best_for = "排名对比、长标签类别、富集分析结果", 
    columns = "x(类别), y(数值)", options_def = list(list(id = "fill_color", label = "填充颜色", 
        type = "color", group = "basic", default = "#FF6B6B"), 
        list(id = "top_n", label = "显示前N条(0=全部)", 
            type = "numeric", group = "basic", default = 0, min = 0, 
            max = 50, step = 1), list(id = "sort_bars", label = "排序方式", 
            type = "select", group = "basic", choices = c(降序 = "desc", 
            升序 = "asc", 不排序 = "none"), default = "desc"), 
        list(id = "show_labels", label = "显示数值标签", 
            type = "checkbox", group = "basic", default = TRUE), 
        list(id = "label_size", label = "标签字号", type = "slider", 
            group = "basic", min = 2, max = 7, step = 0.5, default = 3.5, 
            show_when = "show_labels"), list(id = "bar_width", 
            label = "柱宽", type = "slider", group = "advanced", 
            min = 0.2, max = 1, step = 0.05, default = 0.7), 
        list(id = "alpha", label = "透明度", type = "slider", 
            group = "advanced", min = 0.1, max = 1, step = 0.05, 
            default = 0.9)), code_template = function (options) 
    {
        fcol <- options$fill_color %||% "#FF6B6B"
        topn <- as.integer(options$top_n %||% 0)
        sortit <- options$sort_bars %||% "desc"
        bw <- options$bar_width %||% 0.7
        alp <- options$alpha %||% 0.9
        lbls <- isTRUE(options$show_labels)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  city  = c(\"北京\",\"上海\",\"广州\",\"深圳\",\"成都\",\"武汉\",\"杭州\",\"重庆\",\"西安\",\"南京\"),\n  value = c(42.6, 44.4, 28.8, 32.4, 22.1, 18.9, 18.9, 29.1, 10.7, 16.4)\n)\n\n# 排序并取 TopN\ndata <- data[order(-data$value), ]", 
            if (topn > 0) 
                paste0("\ndata <- head(data, ", topn, ")")
            else "", "\ndata$city <- factor(data$city, levels = rev(data$city))\n\np <- ggplot(data, aes(x = city, y = value)) +\n  geom_col(fill = \"", 
            fcol, "\", alpha = ", alp, ", width = ", bw, ") +\n  coord_flip()", 
            if (lbls) 
                " +\n  geom_text(aes(label = round(value, 1)), hjust = -0.2, size = 3.5)"
            else "", " +\n  labs(x = \"城市\", y = \"GDP（千亿元）\") +\n  theme_minimal()\n\nprint(p)")
    })

