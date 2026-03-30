# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_filled", name = "百分比堆叠柱状图", name_en = "100% Stacked Bar Chart", 
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
        bw <- as.numeric(options$bar_width %||% 0.7)
        alp <- as.numeric(options$alpha %||% 0.9)
        lbls <- isTRUE(options$show_labels)
        lsz <- as.numeric(options$label_size %||% 3)
        df <- data.frame(x = as.character(data[[x_col]]), y = as.numeric(data[[y_col]]), 
            stringsAsFactors = FALSE)
        df$group <- if (!is.null(g_col)) 
            as.character(data[[g_col]])
        else "全部"
        df <- df[!is.na(df$y), ]
        df$pct <- ave(df$y, df$x, FUN = function(v) v/sum(v))
        n_grp <- length(unique(df$group))
        group_levels <- unique(df$group)
        pal <- palette_values_for_column(df, "group", options, 
            levels = group_levels, palette_name = pal_name)
        p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = group)) + 
            ggplot2::geom_col(position = "fill", width = bw, 
                alpha = alp, color = NA) + ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) + 
            ggplot2::scale_fill_manual(values = pal, name = if (!is.null(g_col)) 
                g_col
            else NULL)
        if (lbls) {
            df_lbl <- df[df$pct >= 0.05, ]
            if (nrow(df_lbl) > 0) {
                p <- p + ggplot2::geom_text(data = df_lbl, ggplot2::aes(label = scales::percent(pct, 
                  accuracy = 1), group = group), position = ggplot2::position_fill(vjust = 0.5), 
                  size = lsz, color = "white")
            }
        }
        p <- .bar_orient(p, orient)
        apply_theme(p + ggplot2::labs(x = x_col, y = "比例"), 
            options)
    }, category = "柱图家族", description = "每柱归一化为 100%，专注各组的占比结构变化", 
    best_for = "比例变化趋势、构成对比、问卷选项分布", 
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
        label = "显示百分比标签", type = "checkbox", group = "basic", 
        default = FALSE), list(id = "label_size", label = "标签字号", 
        type = "slider", group = "basic", min = 2, max = 7, step = 0.5, 
        default = 3, show_when = "show_labels"), list(id = "bar_width", 
        label = "柱宽", type = "slider", group = "advanced", 
        min = 0.2, max = 1, step = 0.05, default = 0.7), list(
        id = "alpha", label = "透明度", type = "slider", group = "advanced", 
        min = 0.1, max = 1, step = 0.05, default = 0.9)), code_template = function (options) 
    {
        orient <- options$orientation %||% "vertical"
        bw <- options$bar_width %||% 0.7
        alp <- options$alpha %||% 0.9
        lbls <- isTRUE(options$show_labels)
        paste0("library(ggplot2)\nlibrary(scales)\n\ndata <- data.frame(\n  quarter = rep(c(\"Q1\",\"Q2\",\"Q3\",\"Q4\"), 3),\n  sales   = c(85, 92, 78, 105,  70, 88, 95, 82,  55, 62, 70, 78),\n  product = rep(c(\"产品A\",\"产品B\",\"产品C\"), each = 4)\n)\n", 
            if (lbls) 
                "\n# 计算各组在每个 x 内的占比\nlibrary(dplyr)\ndata <- data |>\n  group_by(quarter) |>\n  mutate(pct = sales / sum(sales)) |>\n  ungroup()\n"
            else "", "\np <- ggplot(data, aes(x = quarter, y = sales, fill = product)) +\n  geom_col(position = \"fill\", width = ", 
            bw, ", alpha = ", alp, ") +\n  scale_y_continuous(labels = scales::percent_format())", 
            if (lbls) 
                " +\n  geom_text(aes(label = scales::percent(pct, accuracy = 1), group = product),\n            position = position_fill(vjust = 0.5), size = 3, color = \"white\")"
            else "", if (orient == "horizontal") 
                " +\n  coord_flip()"
            else "", " +\n  scale_fill_brewer(palette = \"Set2\") +\n  labs(x = \"季度\", y = \"占比\", fill = \"产品\") +\n  theme_minimal()\n\nprint(p)")
    })

