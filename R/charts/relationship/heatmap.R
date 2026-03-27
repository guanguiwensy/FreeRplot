# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "heatmap", name = "热力图", category = "通用图表", 
    name_en = "Heatmap", plot_fn = function (data, options) 
    {
        show_values <- if (is.null(options$show_values)) 
            TRUE
        else isTRUE(options$show_values)
        value_size <- as.numeric(options$value_size %||% 8)
        color_low <- as.character(options$color_low %||% "#DEEBF7")
        color_high <- as.character(options$color_high %||% "#08519C")
        p <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y, 
            fill = value)) + ggplot2::geom_tile(color = "white", 
            linewidth = 0.6) + ggplot2::scale_fill_gradient(low = color_low, 
            high = color_high, name = "数值") + ggplot2::coord_fixed()
        if (show_values) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = round(value, 
                1)), size = value_size/3, color = "gray20")
        }
        apply_theme(p, options)
    }, description = "用颜色深浅展示矩阵数据的大小", 
    best_for = "相关性矩阵、时间-类别数据对比", 
    columns = "x(X轴类别), y(Y轴类别), value(数值)", 
    sample_data = structure(list(x = c("一月", "二月", "三月", 
    "四月", "一月", "二月", "三月", "四月", "一月", 
    "二月", "三月", "四月", "一月", "二月", "三月", 
    "四月"), y = c("产品A", "产品A", "产品A", "产品A", 
    "产品B", "产品B", "产品B", "产品B", "产品C", "产品C", 
    "产品C", "产品C", "产品D", "产品D", "产品D", "产品D"
    ), value = c(10, 15, 8, 12, 20, 25, 18, 22, 5, 8, 12, 6, 
    15, 18, 20, 25)), class = "data.frame", row.names = c(NA, 
    -16L)), options_def = list(list(id = "show_values", label = "显示数值", 
        type = "checkbox", group = "basic", default = TRUE), 
        list(id = "value_size", label = "数值字体大小", 
            type = "slider", group = "basic", min = 3, max = 14, 
            step = 0.5, default = 8), list(id = "color_low", 
            label = "低值颜色", type = "color", group = "advanced", 
            default = "#DEEBF7"), list(id = "color_high", label = "高值颜色", 
            type = "color", group = "advanced", default = "#08519C")), 
    code_template = function (options) 
    {
        sv <- isTRUE(options$show_values %||% TRUE)
        vs <- options$value_size %||% 8
        cl <- options$color_low %||% "#DEEBF7"
        ch <- options$color_high %||% "#08519C"
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  x     = rep(c(\"一月\",\"二月\",\"三月\",\"四月\"), 4),\n  y     = rep(c(\"产品A\",\"产品B\",\"产品C\",\"产品D\"), each=4),\n  value = c(10,15,8,12, 20,25,18,22, 5,8,12,6, 15,18,20,25)\n)\n\np <- ggplot(data, aes(x=x, y=y, fill=value)) +\n  geom_tile(color=\"white\", linewidth=0.5)", 
            if (sv) 
                paste0(" +\n  geom_text(aes(label=value), size=", 
                  vs/3.5, ", color=\"white\", fontface=\"bold\")")
            else "", "  +\n  scale_fill_gradient(low=\"", cl, 
            "\", high=\"", ch, "\") +\n  theme_minimal() +\n  labs(title=\"热力图\", x=\"月份\", y=\"产品\", fill=\"销量\")\n\nprint(p)")
    })

