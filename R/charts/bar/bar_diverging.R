# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_diverging", name = "发散柱状图", name_en = "Diverging Bar Chart", 
    plot_fn = function (data, options = list()) 
    {
        x_col <- names(data)[1]
        y_col <- if (ncol(data) >= 2) 
            names(data)[2]
        else names(data)[1]
        col_pos <- options$color_pos %||% "#E74C3C"
        col_neg <- options$color_neg %||% "#3498DB"
        orient <- options$orientation %||% "horizontal"
        sortit <- options$sort_bars %||% "desc"
        bw <- as.numeric(options$bar_width %||% 0.7)
        alp <- as.numeric(options$alpha %||% 0.9)
        lbls <- isTRUE(options$show_labels)
        df <- data.frame(x = as.character(data[[x_col]]), y = as.numeric(data[[y_col]]), 
            stringsAsFactors = FALSE)
        df <- df[!is.na(df$y), ]
        df$direction <- ifelse(df$y >= 0, "pos", "neg")
        if (sortit == "desc") 
            df$x <- reorder(df$x, -df$y)
        if (sortit == "asc") 
            df$x <- reorder(df$x, df$y)
        lp <- .bar_label_params(orient)
        p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = direction)) + 
            ggplot2::geom_col(alpha = alp, width = bw, color = NA) + 
            ggplot2::scale_fill_manual(values = c(pos = col_pos, 
                neg = col_neg), labels = c(pos = "正向", neg = "负向"), 
                name = NULL) + ggplot2::geom_hline(yintercept = 0, 
            linewidth = 0.5, color = "#555555")
        if (lbls) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = round(y, 
                2)), vjust = lp$vjust, hjust = lp$hjust, size = 3.2, 
                color = "#333333")
        }
        p <- .bar_orient(p, orient)
        apply_theme(p + ggplot2::labs(x = x_col, y = y_col), 
            options)
    }, category = "柱图家族", description = "正负值分别向两侧延伸，突出对比与变化方向", 
    best_for = "log2FC、盈亏对比、前后变化、问卷净推荐值", 
    columns = "x(类别), y(含正负的数值)", sample_data = structure(list(
        gene = c("GeneA", "GeneB", "GeneC", "GeneD", "GeneE", 
        "GeneF", "GeneG", "GeneH", "GeneI", "GeneJ"), log2fc = c(2.3, 
        -1.8, 1.1, -0.5, 3.1, -2.6, 0.8, -1.2, 1.7, -0.9)), class = "data.frame", row.names = c(NA, 
    -10L)), options_def = list(list(id = "color_pos", label = "正值颜色", 
        type = "color", group = "basic", default = "#E74C3C"), 
        list(id = "color_neg", label = "负值颜色", type = "color", 
            group = "basic", default = "#3498DB"), list(id = "orientation", 
            label = "方向", type = "select", group = "basic", 
            choices = c(横向 = "horizontal", 纵向 = "vertical"
            ), default = "horizontal"), list(id = "sort_bars", 
            label = "排序方式", type = "select", group = "basic", 
            choices = c(降序 = "desc", 升序 = "asc", 不排序 = "none"
            ), default = "desc"), list(id = "show_labels", label = "显示数值标签", 
            type = "checkbox", group = "basic", default = FALSE), 
        list(id = "bar_width", label = "柱宽", type = "slider", 
            group = "advanced", min = 0.2, max = 1, step = 0.05, 
            default = 0.7), list(id = "alpha", label = "透明度", 
            type = "slider", group = "advanced", min = 0.1, max = 1, 
            step = 0.05, default = 0.9)), code_template = function (options) 
    {
        cp <- options$color_pos %||% "#E74C3C"
        cn <- options$color_neg %||% "#3498DB"
        orient <- options$orientation %||% "horizontal"
        sortit <- options$sort_bars %||% "desc"
        bw <- options$bar_width %||% 0.7
        alp <- options$alpha %||% 0.9
        lbls <- isTRUE(options$show_labels)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  gene   = paste0(\"Gene\", LETTERS[1:10]),\n  log2fc = c(2.3, -1.8, 1.1, -0.5, 3.1, -2.6, 0.8, -1.2, 1.7, -0.9)\n)\ndata$direction <- ifelse(data$log2fc >= 0, \"up\", \"down\")\n", 
            if (sortit == "desc") 
                "data$gene <- reorder(data$gene, -data$log2fc)\n"
            else if (sortit == "asc") 
                "data$gene <- reorder(data$gene,  data$log2fc)\n"
            else "", "\np <- ggplot(data, aes(x = gene, y = log2fc, fill = direction)) +\n  geom_col(alpha = ", 
            alp, ", width = ", bw, ") +\n  scale_fill_manual(values = c(\"up\" = \"", 
            cp, "\", \"down\" = \"", cn, "\"),\n                    labels = c(\"up\" = \"上调\", \"down\" = \"下调\"), name = NULL) +\n  geom_hline(yintercept = 0, linewidth = 0.5)", 
            if (lbls) 
                " +\n  geom_text(aes(label = round(log2fc, 2)), hjust = ifelse(data$log2fc >= 0, -0.2, 1.2), size = 3)"
            else "", if (orient == "horizontal") 
                " +\n  coord_flip()"
            else "", " +\n  labs(x = NULL, y = \"log2 Fold Change\") +\n  theme_minimal()\n\nprint(p)")
    })

