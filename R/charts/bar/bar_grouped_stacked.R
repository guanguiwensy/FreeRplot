# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_grouped_stacked", name = "分组堆叠柱状图", 
    name_en = "Grouped Stacked Bar Chart", plot_fn = function (data, 
        options = list()) 
    {
        x_col <- names(data)[1]
        y_col <- if (ncol(data) >= 2) 
            names(data)[2]
        else names(data)[1]
        sub_col <- if (ncol(data) >= 3) 
            names(data)[3]
        else NULL
        fac_col <- if (ncol(data) >= 4) 
            names(data)[4]
        else NULL
        pal_name <- options$color_palette %||% options$palette %||% 
            "默认"
        ncol_fac <- as.integer(options$facet_ncol %||% 2)
        bw <- as.numeric(options$bar_width %||% 0.7)
        alp <- as.numeric(options$alpha %||% 0.9)
        lbls <- isTRUE(options$show_labels)
        orient <- options$orientation %||% "vertical"
        df <- data.frame(x = as.character(data[[x_col]]), y = as.numeric(data[[y_col]]), 
            stringsAsFactors = FALSE)
        df$sub <- if (!is.null(sub_col)) 
            as.character(data[[sub_col]])
        else "全部"
        df$facet <- if (!is.null(fac_col)) 
            as.character(data[[fac_col]])
        else df$x
        df <- df[!is.na(df$y), ]
        sub_levels <- unique(df$sub)
        pal <- palette_values_for_column(df, "sub", options, 
            levels = sub_levels, palette_name = pal_name)
        p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = sub)) + 
            ggplot2::geom_col(position = "stack", width = bw, 
                alpha = alp, color = NA) + ggplot2::scale_fill_manual(values = pal, 
            name = if (!is.null(sub_col)) 
                sub_col
            else NULL) + ggplot2::facet_wrap(~facet, ncol = ncol_fac, 
            scales = "free_x")
        if (lbls) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = round(y, 
                0), group = sub), position = ggplot2::position_stack(vjust = 0.5), 
                size = 2.8, color = "white")
        }
        p <- .bar_orient(p, orient)
        apply_theme(p + ggplot2::labs(x = x_col, y = y_col), 
            options)
    }, category = "柱图家族", description = "先按大类分面，每面内再堆叠子类，适合多层级分类对比", 
    best_for = "多维度构成分析、产品 × 渠道 × 季度", 
    columns = "x(主类别), y(数值), sub_group(堆叠子类), facet(分面大类，可选)", 
    sample_data = structure(list(quarter = c("Q1", "Q2", "Q1", 
    "Q2", "Q1", "Q2", "Q1", "Q2", "Q1", "Q2", "Q1", "Q2"), sales = c(30, 
    35, 20, 22, 15, 18, 25, 28, 18, 20, 12, 16), channel = c("线上", 
    "线上", "线下", "线下", "代理", "代理", "线上", 
    "线上", "线下", "线下", "代理", "代理"), product = c("产品A", 
    "产品A", "产品A", "产品A", "产品A", "产品A", "产品B", 
    "产品B", "产品B", "产品B", "产品B", "产品B")), class = "data.frame", row.names = c(NA, 
    -12L)), options_def = list(list(id = "color_palette", label = "配色", 
        type = "select", group = "basic", choices = c(默认 = "默认", 
        商务蓝 = "商务蓝", 自然绿 = "自然绿", 活力橙 = "活力橙", 
        粉紫系 = "粉紫系"), default = "默认"), list(id = "orientation", 
        label = "方向", type = "select", group = "basic", choices = c(纵向 = "vertical", 
        横向 = "horizontal"), default = "vertical"), list(id = "facet_ncol", 
        label = "分面列数", type = "numeric", group = "basic", 
        default = 2, min = 1, max = 6, step = 1), list(id = "show_labels", 
        label = "显示段落数值", type = "checkbox", group = "basic", 
        default = FALSE), list(id = "bar_width", label = "柱宽", 
        type = "slider", group = "advanced", min = 0.2, max = 1, 
        step = 0.05, default = 0.7), list(id = "alpha", label = "透明度", 
        type = "slider", group = "advanced", min = 0.1, max = 1, 
        step = 0.05, default = 0.9)), code_template = function (options) 
    {
        orient <- options$orientation %||% "vertical"
        ncolf <- options$facet_ncol %||% 2
        lbls <- isTRUE(options$show_labels)
        bw <- options$bar_width %||% 0.7
        alp <- options$alpha %||% 0.9
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  product = rep(c(\"产品A\",\"产品B\"), each = 6),\n  channel = rep(rep(c(\"线上\",\"线下\",\"代理\"), each = 2), 2),\n  quarter = rep(c(\"Q1\",\"Q2\"), 6),\n  sales   = c(30,35, 20,22, 15,18, 25,28, 18,20, 12,16)\n)\n\np <- ggplot(data, aes(x = quarter, y = sales, fill = channel)) +\n  geom_col(position = \"stack\", width = ", 
            bw, ", alpha = ", alp, ") +\n  scale_fill_brewer(palette = \"Set2\") +\n  facet_wrap(~ product, ncol = ", 
            ncolf, ", scales = \"free_x\")", if (lbls) 
                " +\n  geom_text(aes(label = round(sales, 0), group = channel),\n            position = position_stack(vjust = 0.5), size = 2.8, color = \"white\")"
            else "", if (orient == "horizontal") 
                " +\n  coord_flip()"
            else "", " +\n  labs(x = NULL, y = \"销售额\", fill = \"渠道\") +\n  theme_minimal()\n\nprint(p)")
    })

