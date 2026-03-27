# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_grouped", name = "分组柱状图", name_en = "Grouped Bar Chart", 
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
        orient <- options$orientation %||% "vertical"
        dw <- as.numeric(options$dodge_width %||% 0.8)
        bw <- as.numeric(options$bar_width %||% 0.7)
        alp <- as.numeric(options$alpha %||% 0.9)
        lbls <- isTRUE(options$show_labels)
        lsz <- as.numeric(options$label_size %||% 3.5)
        df <- data.frame(x = as.character(data[[x_col]]), y = as.numeric(data[[y_col]]), 
            stringsAsFactors = FALSE)
        df$group <- if (!is.null(g_col)) 
            as.character(data[[g_col]])
        else "全部"
        df <- df[!is.na(df$y), ]
        n_grp <- length(unique(df$group))
        pal <- get_palette(pal_name, n_grp)
        lp <- .bar_label_params(orient)
        p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = group)) + 
            ggplot2::geom_col(position = ggplot2::position_dodge(width = dw), 
                width = bw * dw, alpha = alp, color = NA) + ggplot2::scale_fill_manual(values = pal, 
            name = if (!is.null(g_col)) 
                g_col
            else NULL)
        if (lbls) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = round(y, 
                1), group = group), position = ggplot2::position_dodge(width = dw), 
                vjust = lp$vjust, hjust = lp$hjust, size = lsz, 
                color = "#333333")
        }
        p <- .bar_orient(p, orient)
        apply_theme(p + ggplot2::labs(x = x_col, y = y_col), 
            options)
    }, category = "柱图家族", description = "多组数据并列展示，便于同一类别下不同组的直接对比", 
    best_for = "多组对比、产品/时间/地区并列比较", 
    columns = "x(类别), y(数值), group(分组变量)", sample_data = structure(list(
        quarter = c("Q1", "Q2", "Q3", "Q4", "Q1", "Q2", "Q3", 
        "Q4", "Q1", "Q2", "Q3", "Q4"), sales = c(85, 92, 78, 
        105, 70, 88, 95, 82, 55, 62, 70, 78), product = c("产品A", 
        "产品A", "产品A", "产品A", "产品B", "产品B", 
        "产品B", "产品B", "产品C", "产品C", "产品C", 
        "产品C")), class = "data.frame", row.names = c(NA, 
    -12L)), options_def = list(list(id = "color_palette", label = "配色方案", 
        type = "select", group = "basic", choices = c(默认 = "默认", 
        商务蓝 = "商务蓝", 自然绿 = "自然绿", 活力橙 = "活力橙", 
        粉紫系 = "粉紫系"), default = "默认"), list(id = "orientation", 
        label = "方向", type = "select", group = "basic", choices = c(纵向 = "vertical", 
        横向 = "horizontal"), default = "vertical"), list(id = "show_labels", 
        label = "显示数值标签", type = "checkbox", group = "basic", 
        default = FALSE), list(id = "label_size", label = "标签字号", 
        type = "slider", group = "basic", min = 2, max = 7, step = 0.5, 
        default = 3.5, show_when = "show_labels"), list(id = "dodge_width", 
        label = "组间距", type = "slider", group = "advanced", 
        min = 0.4, max = 1, step = 0.05, default = 0.8), list(
        id = "bar_width", label = "柱宽系数", type = "slider", 
        group = "advanced", min = 0.4, max = 1, step = 0.05, 
        default = 0.7), list(id = "alpha", label = "透明度", 
        type = "slider", group = "advanced", min = 0.1, max = 1, 
        step = 0.05, default = 0.9)), code_template = function (options) 
    {
        pal <- options$color_palette %||% "Set2"
        orient <- options$orientation %||% "vertical"
        dw <- options$dodge_width %||% 0.8
        bw <- options$bar_width %||% 0.7
        alp <- options$alpha %||% 0.9
        lbls <- isTRUE(options$show_labels)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  quarter = rep(c(\"Q1\",\"Q2\",\"Q3\",\"Q4\"), 3),\n  sales   = c(85, 92, 78, 105,  70, 88, 95, 82,  55, 62, 70, 78),\n  product = rep(c(\"产品A\",\"产品B\",\"产品C\"), each = 4)\n)\n\np <- ggplot(data, aes(x = quarter, y = sales, fill = product)) +\n  geom_col(position = position_dodge(width = ", 
            dw, "),\n           width = ", bw * dw, ", alpha = ", 
            alp, ")", if (lbls) 
                paste0(" +\n  geom_text(aes(label = round(sales, 0), group = product),\n            position = position_dodge(width = ", 
                  dw, "), vjust = -0.4, size = 3)")
            else "", if (orient == "horizontal") 
                " +\n  coord_flip()"
            else "", " +\n  scale_fill_brewer(palette = \"Set2\") +\n  labs(x = \"季度\", y = \"销售额\", fill = \"产品\") +\n  theme_minimal()\n\nprint(p)")
    })

