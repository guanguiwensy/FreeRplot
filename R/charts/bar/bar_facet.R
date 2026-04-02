# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_facet", name = "分面柱状图", name_en = "Faceted Bar Chart", 
    plot_fn = function (data, options = list()) 
    {
        x_col <- names(data)[1]
        y_col <- if (ncol(data) >= 2) 
            names(data)[2]
        else names(data)[1]
        g_col <- if (ncol(data) >= 3) 
            names(data)[3]
        else NULL
        pal_name <- options$color_palette %||% options$palette %||% 
            "默认"
        ncol_fac <- as.integer(options$facet_ncol %||% 2)
        free_y <- isTRUE(options$free_y_scale)
        orient <- options$orientation %||% "vertical"
        bw <- as.numeric(options$bar_width %||% 0.7)
        alp <- as.numeric(options$alpha %||% 0.9)
        lbls <- isTRUE(options$show_labels)
        df <- data.frame(x = as.character(data[[x_col]]), y = as.numeric(data[[y_col]]), 
            stringsAsFactors = FALSE)
        df$facet <- if (!is.null(g_col)) 
            as.character(data[[g_col]])
        else x_col
        df <- df[!is.na(df$y), ]
        x_levels <- unique(df$x)
        pal <- palette_values_for_column(df, "x", options, levels = x_levels, 
            palette_name = pal_name)
        lp <- .bar_label_params(orient)
        scales <- if (free_y) 
            "free_y"
        else "fixed"
        p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = x)) + 
            ggplot2::geom_col(alpha = alp, width = bw, color = NA) + 
            ggplot2::scale_fill_manual(values = pal, guide = "none") + 
            ggplot2::facet_wrap(~facet, ncol = ncol_fac, scales = scales)
        if (lbls) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = round(y, 
                1)), vjust = lp$vjust, hjust = lp$hjust, size = 3, 
                color = "#333333")
        }
        p <- .bar_orient(p, orient)
        apply_theme(p + ggplot2::labs(x = NULL, y = y_col), options)
    }, category = "柱图家族", description = "按分组变量拆分成多个小图，每个子图独立展示柱图", 
    best_for = "多组横向对比、避免单图过于拥挤", 
    columns = "x(类别), y(数值), group(分面变量)", options_def = list(list(id = "color_palette", label = "配色", 
        type = "select", group = "basic", choices = c(默认 = "默认", 
        商务蓝 = "商务蓝", 自然绿 = "自然绿", 活力橙 = "活力橙", 
        粉紫系 = "粉紫系"), default = "默认"), list(id = "orientation", 
        label = "方向", type = "select", group = "basic", choices = c(纵向 = "vertical", 
        横向 = "horizontal"), default = "vertical"), list(id = "facet_ncol", 
        label = "分面列数", type = "numeric", group = "basic", 
        default = 2, min = 1, max = 6, step = 1), list(id = "free_y_scale", 
        label = "各面独立Y轴", type = "checkbox", group = "basic", 
        default = FALSE), list(id = "show_labels", label = "显示数值标签", 
        type = "checkbox", group = "basic", default = FALSE), 
        list(id = "bar_width", label = "柱宽", type = "slider", 
            group = "advanced", min = 0.2, max = 1, step = 0.05, 
            default = 0.7), list(id = "alpha", label = "透明度", 
            type = "slider", group = "advanced", min = 0.1, max = 1, 
            step = 0.05, default = 0.9)), code_template = function (options) 
    {
        orient <- options$orientation %||% "vertical"
        ncolf <- options$facet_ncol %||% 2
        freey <- isTRUE(options$free_y_scale)
        lbls <- isTRUE(options$show_labels)
        bw <- options$bar_width %||% 0.7
        alp <- options$alpha %||% 0.9
        scales <- if (freey) 
            "\"free_y\""
        else "\"fixed\""
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  quarter = rep(c(\"Q1\",\"Q2\",\"Q3\",\"Q4\"), 3),\n  sales   = c(85, 92, 78, 105,  70, 88, 95, 82,  55, 62, 70, 78),\n  product = rep(c(\"产品A\",\"产品B\",\"产品C\"), each = 4)\n)\n\np <- ggplot(data, aes(x = quarter, y = sales, fill = quarter)) +\n  geom_col(alpha = ", 
            alp, ", width = ", bw, ", color = NA) +\n  scale_fill_brewer(palette = \"Set2\", guide = \"none\") +\n  facet_wrap(~ product, ncol = ", 
            ncolf, ", scales = ", scales, ")", if (lbls) 
                " +\n  geom_text(aes(label = round(sales, 0)), vjust = -0.4, size = 3)"
            else "", if (orient == "horizontal") 
                " +\n  coord_flip()"
            else "", " +\n  labs(x = NULL, y = \"销售额\") +\n  theme_minimal()\n\nprint(p)")
    })

