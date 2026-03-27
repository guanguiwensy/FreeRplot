# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_count", name = "计数柱状图", name_en = "Bar Chart (Count)", 
    plot_fn = function (data, options = list()) 
    {
        x_col <- names(data)[1]
        fcol <- options$fill_color %||% "#4ECDC4"
        orient <- options$orientation %||% "vertical"
        sortit <- isTRUE(options$sort_bars)
        bw <- as.numeric(options$bar_width %||% 0.7)
        alp <- as.numeric(options$alpha %||% 0.9)
        lbls <- isTRUE(options$show_labels)
        df <- data.frame(x = as.character(data[[x_col]]), stringsAsFactors = FALSE)
        if (sortit) {
            freq <- sort(table(df$x), decreasing = TRUE)
            df$x <- factor(df$x, levels = names(freq))
        }
        lp <- .bar_label_params(orient)
        p <- ggplot2::ggplot(df, ggplot2::aes(x = x)) + ggplot2::geom_bar(fill = fcol, 
            alpha = alp, width = bw, color = NA)
        if (lbls) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = ggplot2::after_stat(count)), 
                stat = "count", vjust = lp$vjust, hjust = lp$hjust, 
                size = 3.5, color = "#333333")
        }
        p <- .bar_orient(p, orient)
        apply_theme(p + ggplot2::labs(x = x_col, y = "计数"), 
            options)
    }, category = "柱图家族", description = "自动统计各类别出现次数并绘制柱图，无需预先汇总", 
    best_for = "类别频率分布、问卷统计、样本构成", 
    columns = "category(类别列，自动计数)", sample_data = structure(list(
        education = c("研究生", "本科生", "研究生", 
        "专科生", "本科生", "高中", "研究生", "本科生", 
        "专科生", "本科生", "研究生", "高中", "专科生", 
        "本科生", "研究生", "本科生", "研究生", "专科生"
        )), class = "data.frame", row.names = c(NA, -18L)), options_def = list(
        list(id = "fill_color", label = "填充颜色", type = "color", 
            group = "basic", default = "#4ECDC4"), list(id = "orientation", 
            label = "方向", type = "select", group = "basic", 
            choices = c(纵向 = "vertical", 横向 = "horizontal"
            ), default = "vertical"), list(id = "sort_bars", 
            label = "按频率降序排列", type = "checkbox", 
            group = "basic", default = FALSE), list(id = "show_labels", 
            label = "显示计数标签", type = "checkbox", 
            group = "basic", default = FALSE), list(id = "bar_width", 
            label = "柱宽", type = "slider", group = "advanced", 
            min = 0.2, max = 1, step = 0.05, default = 0.7), 
        list(id = "alpha", label = "透明度", type = "slider", 
            group = "advanced", min = 0.1, max = 1, step = 0.05, 
            default = 0.9)), code_template = function (options) 
    {
        fcol <- options$fill_color %||% "#4ECDC4"
        orient <- options$orientation %||% "vertical"
        sortit <- isTRUE(options$sort_bars)
        bw <- options$bar_width %||% 0.7
        alp <- options$alpha %||% 0.9
        lbls <- isTRUE(options$show_labels)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  education = c(\"研究生\",\"本科生\",\"研究生\",\"专科生\",\"本科生\",\"高中\",\n                \"研究生\",\"本科生\",\"专科生\",\"本科生\",\"研究生\",\"高中\",\n                \"专科生\",\"本科生\",\"研究生\",\"本科生\",\"研究生\",\"专科生\")\n)\n", 
            if (sortit) 
                "\n# 按频率排序\nfreq <- sort(table(data$education), decreasing = TRUE)\ndata$education <- factor(data$education, levels = names(freq))\n"
            else "", "\np <- ggplot(data, aes(x = education)) +\n  geom_bar(fill = \"", 
            fcol, "\", alpha = ", alp, ", width = ", bw, ")", 
            if (lbls) 
                " +\n  geom_text(aes(label = after_stat(count)), stat = \"count\", vjust = -0.4, size = 3.5)"
            else "", if (orient == "horizontal") 
                " +\n  coord_flip()"
            else "", " +\n  labs(x = \"学历\", y = \"人数\") +\n  theme_minimal()\n\nprint(p)")
    })

