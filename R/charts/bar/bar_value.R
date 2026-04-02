# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_value", name = "数值柱状图", name_en = "Bar Chart (Value)", 
    plot_fn = function (data, options = list()) 
    {
        x_col <- names(data)[1]
        y_col <- if (ncol(data) >= 2) 
            names(data)[2]
        else names(data)[1]
        fcol <- options$fill_color %||% "#45B7D1"
        orient <- options$orientation %||% "vertical"
        sortit <- options$sort_bars %||% "none"
        bw <- as.numeric(options$bar_width %||% 0.7)
        alp <- as.numeric(options$alpha %||% 0.9)
        lbls <- isTRUE(options$show_labels)
        lsz <- as.numeric(options$label_size %||% 3.5)
        df <- data.frame(x = as.character(data[[x_col]]), y = as.numeric(data[[y_col]]), 
            stringsAsFactors = FALSE)
        df <- df[!is.na(df$y), ]
        if (sortit == "asc") 
            df$x <- reorder(df$x, df$y)
        if (sortit == "desc") 
            df$x <- reorder(df$x, -df$y)
        lp <- .bar_label_params(orient)
        p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) + 
            ggplot2::geom_col(fill = fcol, alpha = alp, width = bw, 
                color = NA)
        if (lbls) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = round(y, 
                1)), vjust = lp$vjust, hjust = lp$hjust, size = lsz, 
                color = "#333333")
        }
        p <- .bar_orient(p, orient)
        apply_theme(p + ggplot2::labs(x = x_col, y = y_col), 
            options)
    }, category = "柱图家族", description = "使用已汇总的数值数据绘制柱图，支持排序与标签", 
    best_for = "已统计好的类别数值对比、KPI 展示", 
    columns = "x(类别), y(数值)", options_def = list(list(id = "fill_color", label = "填充颜色", 
        type = "color", group = "basic", default = "#45B7D1"), 
        list(id = "orientation", label = "方向", type = "select", 
            group = "basic", choices = c(纵向 = "vertical", 
            横向 = "horizontal"), default = "vertical"), list(
            id = "sort_bars", label = "排序方式", type = "select", 
            group = "basic", choices = c(不排序 = "none", 
            升序 = "asc", 降序 = "desc"), default = "none"), 
        list(id = "show_labels", label = "显示数值标签", 
            type = "checkbox", group = "basic", default = FALSE), 
        list(id = "label_size", label = "标签字号", type = "slider", 
            group = "basic", min = 2, max = 7, step = 0.5, default = 3.5, 
            show_when = "show_labels"), list(id = "bar_width", 
            label = "柱宽", type = "slider", group = "advanced", 
            min = 0.2, max = 1, step = 0.05, default = 0.7), 
        list(id = "alpha", label = "透明度", type = "slider", 
            group = "advanced", min = 0.1, max = 1, step = 0.05, 
            default = 0.9)), code_template = function (options) 
    {
        fcol <- options$fill_color %||% "#45B7D1"
        orient <- options$orientation %||% "vertical"
        sortit <- options$sort_bars %||% "none"
        bw <- options$bar_width %||% 0.7
        alp <- options$alpha %||% 0.9
        lbls <- isTRUE(options$show_labels)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  city = c(\"北京\",\"上海\",\"广州\",\"深圳\",\"成都\",\"武汉\",\"杭州\"),\n  gdp  = c(42.6, 44.4, 28.8, 32.4, 22.1, 18.9, 18.9)\n)\n", 
            if (sortit == "desc") 
                "data$city <- reorder(data$city, -data$gdp)\n"
            else if (sortit == "asc") 
                "data$city <- reorder(data$city,  data$gdp)\n"
            else "", "\np <- ggplot(data, aes(x = city, y = gdp)) +\n  geom_col(fill = \"", 
            fcol, "\", alpha = ", alp, ", width = ", bw, ")", 
            if (lbls) 
                " +\n  geom_text(aes(label = round(gdp, 1)), vjust = -0.4, size = 3.5)"
            else "", if (orient == "horizontal") 
                " +\n  coord_flip()"
            else "", " +\n  labs(x = \"城市\", y = \"GDP（千亿元）\") +\n  theme_minimal()\n\nprint(p)")
    })

