# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "pie", name = "饼图", category = "通用图表", 
    name_en = "Pie Chart", plot_fn = function (data, options) 
    {
        label_levels <- unique(as.character(data$label))
        pal <- palette_values_for_column(data, "label", options, 
            levels = label_levels, palette_name = options$palette)
        label_type <- as.character(options$label_type %||% "percent")
        donut_ratio <- as.numeric(options$donut_ratio %||% 0)
        label_size <- as.numeric(options$label_size %||% 5)
        show_legend <- if (is.null(options$show_legend)) 
            TRUE
        else isTRUE(options$show_legend)
        data <- dplyr::mutate(data, pct = value/sum(value))
        data$pie_label <- if (label_type == "count") {
            as.character(data$value)
        }
        else if (label_type == "both") {
            paste0(data$label, "\n", sprintf("%.1f%%", data$pct * 
                100))
        }
        else {
            sprintf("%.1f%%", data$pct * 100)
        }
        p <- ggplot2::ggplot(data, ggplot2::aes(x = "", y = value, 
            fill = label)) + ggplot2::geom_col(width = 1, color = "white", 
            linewidth = 0.5) + ggplot2::geom_text(ggplot2::aes(label = pie_label), 
            position = ggplot2::position_stack(vjust = 0.5), 
            size = label_size, color = "white", fontface = "bold") + 
            ggplot2::scale_fill_manual(values = pal, name = "类别") + 
            ggplot2::theme_void() + ggplot2::labs(title = options$title %||% 
            NULL) + ggplot2::theme(plot.title = ggplot2::element_text(size = 14, 
            face = "bold", hjust = 0.5), legend.position = if (show_legend) 
            "right"
        else "none")
        if (donut_ratio > 0) {
            p <- p + ggplot2::coord_polar("y") + ggplot2::xlim(c(donut_ratio - 
                0.5, 2.5))
        }
        else {
            p <- p + ggplot2::coord_polar(theta = "y", start = 0)
        }
        p
    }, description = "展示各部分占总体的比例", best_for = "比例关系展示，类别不超过7个", 
    columns = "label(标签), value(数值)", options_def = list(list(id = "label_type", label = "标签类型", 
        type = "select", group = "basic", choices = c(百分比 = "percent", 
        数量 = "count", `名称+百分比` = "both"), default = "percent"), 
        list(id = "donut_ratio", label = "甜甜圈内径(0=实心)", 
            type = "slider", group = "basic", min = 0, max = 0.8, 
            step = 0.05, default = 0), list(id = "label_size", 
            label = "标签字体大小", type = "slider", group = "advanced", 
            min = 3, max = 10, step = 0.5, default = 5), list(
            id = "show_legend", label = "显示图例", type = "checkbox", 
            group = "advanced", default = TRUE)), code_template = function (options) 
    {
        lt <- options$label_type %||% "percent"
        dr <- as.numeric(options$donut_ratio %||% 0)
        ls <- options$label_size %||% 5
        paste0("library(ggplot2)\nlibrary(dplyr)\n\ndata <- data.frame(\n  label = c(\"直接访问\",\"搜索引擎\",\"邮件营销\",\"联盟广告\",\"视频广告\"),\n  value = c(335, 310, 234, 135, 148)\n) |> mutate(pct = value / sum(value),\n            lbl = ", 
            switch(lt, count = "as.character(value)", both = "paste0(label, \"\\n\", sprintf(\"%.1f%%\", pct*100))", 
                "sprintf(\"%.1f%%\", pct*100)"), ")\n\np <- ggplot(data, aes(x=\"\", y=value, fill=label)) +\n  geom_col(width=1, color=\"white\") +\n  geom_text(aes(label=lbl), position=position_stack(vjust=0.5),\n            size=", 
            ls, ", color=\"white\", fontface=\"bold\") +\n  coord_polar(\"y\") +\n  scale_fill_brewer(palette=\"Set3\") +\n  theme_void() +\n  labs(title=\"饼图\")", 
            if (dr > 0) 
                paste0(" +\n  xlim(c(", dr - 0.5, ", 2.5))")
            else "", "\n\nprint(p)")
    })

