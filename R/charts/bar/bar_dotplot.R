# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_dotplot", name = "柱叠加散点图", name_en = "Bar + Dot Plot", 
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
        pt_size <- as.numeric(options$point_size %||% 2.5)
        pt_jitter <- as.numeric(options$jitter_w %||% 0.15)
        bw <- as.numeric(options$bar_width %||% 0.6)
        bar_alp <- as.numeric(options$bar_alpha %||% 0.5)
        df <- data.frame(x = as.character(data[[x_col]]), y = as.numeric(data[[y_col]]), 
            stringsAsFactors = FALSE)
        if (!is.null(g_col)) 
            df$group <- as.character(data[[g_col]])
        df <- df[!is.na(df$y), ]
        n_grp <- if (!is.null(g_col)) 
            length(unique(df$group))
        else 1
        pal <- get_palette(pal_name, max(n_grp, 1))
        if (!is.null(g_col) && "group" %in% names(df)) {
            p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, 
                fill = group, color = group)) + ggplot2::stat_summary(fun = mean, 
                geom = "bar", position = ggplot2::position_dodge(0.75), 
                width = bw * 0.75, alpha = bar_alp, color = NA) + 
                ggplot2::geom_point(position = ggplot2::position_jitterdodge(jitter.width = pt_jitter, 
                  dodge.width = 0.75), size = pt_size, alpha = 0.8) + 
                ggplot2::scale_fill_manual(values = pal, name = g_col) + 
                ggplot2::scale_color_manual(values = pal, name = g_col)
        }
        else {
            p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) + 
                ggplot2::stat_summary(fun = mean, geom = "bar", 
                  fill = pal[1], alpha = bar_alp, width = bw, 
                  color = NA) + ggplot2::geom_jitter(width = pt_jitter, 
                size = pt_size, alpha = 0.75, color = pal[1])
        }
        if (isTRUE(options$show_mean_line)) {
            p <- p + ggplot2::stat_summary(fun = mean, geom = "crossbar", 
                width = bw * 0.6, linewidth = 0.6, color = "#333333", 
                fatten = 2)
        }
        p <- .bar_orient(p, orient)
        apply_theme(p + ggplot2::labs(x = x_col, y = y_col), 
            options)
    }, category = "柱图家族", description = "均值柱图叠加原始数据点，兼顾汇总与分布信息", 
    best_for = "科研数据展示、小样本量原始点可见化", 
    columns = "x(组别), y(数值), group(分组，可选)", 
    sample_data = structure(list(group = c("对照", "对照", 
    "对照", "对照", "对照", "对照", "对照", "对照", 
    "低剂量", "低剂量", "低剂量", "低剂量", "低剂量", 
    "低剂量", "低剂量", "低剂量", "高剂量", "高剂量", 
    "高剂量", "高剂量", "高剂量", "高剂量", "高剂量", 
    "高剂量"), value = c(50.5104620187365, 50.8006641413989, 
    46.7390416875127, 43.386746147053, 34.0744811152905, 42.5284991305827, 
    41.3767769077022, 50.3058331561583, 75.086295367487, 67.010403098945, 
    50.7171146480263, 78.7099730539817, 72.1035303245212, 64.2352121587446, 
    39.9351540679038, 52.4541438144684, 54.3828423951079, 61.8517531140874, 
    44.3808622003754, 83.9007906109056, 32.0155763414426, 52.8765944559934, 
    52.6639362106471, 49.0296977504273)), class = "data.frame", row.names = c(NA, 
    -24L)), options_def = list(list(id = "color_palette", label = "配色", 
        type = "select", group = "basic", choices = c(默认 = "默认", 
        商务蓝 = "商务蓝", 自然绿 = "自然绿", 活力橙 = "活力橙", 
        粉紫系 = "粉紫系"), default = "默认"), list(id = "orientation", 
        label = "方向", type = "select", group = "basic", choices = c(纵向 = "vertical", 
        横向 = "horizontal"), default = "vertical"), list(id = "show_mean_line", 
        label = "显示均值标注", type = "checkbox", group = "basic", 
        default = TRUE), list(id = "point_size", label = "散点大小", 
        type = "slider", group = "advanced", min = 0.5, max = 6, 
        step = 0.5, default = 2.5), list(id = "jitter_w", label = "抖动宽度", 
        type = "slider", group = "advanced", min = 0, max = 0.5, 
        step = 0.05, default = 0.15), list(id = "bar_alpha", 
        label = "柱透明度", type = "slider", group = "advanced", 
        min = 0.1, max = 1, step = 0.05, default = 0.5), list(
        id = "bar_width", label = "柱宽", type = "slider", 
        group = "advanced", min = 0.2, max = 1, step = 0.05, 
        default = 0.6)), code_template = function (options) 
    {
        orient <- options$orientation %||% "vertical"
        sml <- isTRUE(options$show_mean_line)
        ps <- options$point_size %||% 2.5
        jw <- options$jitter_w %||% 0.15
        balp <- options$bar_alpha %||% 0.5
        bw <- options$bar_width %||% 0.6
        paste0("library(ggplot2)\nset.seed(42)\ndata <- data.frame(\n  group = rep(c(\"对照\",\"低剂量\",\"高剂量\"), each = 8),\n  value = c(rnorm(8, 45, 8), rnorm(8, 62, 10), rnorm(8, 55, 9))\n)\n\np <- ggplot(data, aes(x = group, y = value, fill = group, color = group)) +\n  stat_summary(fun = mean, geom = \"bar\",\n               alpha = ", 
            balp, ", width = ", bw, ", color = NA) +\n  geom_jitter(width = ", 
            jw, ", size = ", ps, ", alpha = 0.75)", if (sml) 
                " +\n  stat_summary(fun = mean, geom = \"crossbar\",\n               width = 0.35, linewidth = 0.7, color = \"#333\", fatten = 2)"
            else "", " +\n  scale_fill_brewer(palette = \"Set2\", guide = \"none\") +\n  scale_color_brewer(palette = \"Set2\", guide = \"none\")", 
            if (orient == "horizontal") 
                " +\n  coord_flip()"
            else "", " +\n  labs(x = NULL, y = \"数值\") +\n  theme_minimal()\n\nprint(p)")
    })

