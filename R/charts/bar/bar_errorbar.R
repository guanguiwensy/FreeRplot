# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "bar_errorbar", name = "误差线柱状图", name_en = "Bar Chart with Error Bars", 
    plot_fn = function (data, options = list()) 
    {
        x_col <- names(data)[1]
        y_col <- if (ncol(data) >= 2) 
            names(data)[2]
        else names(data)[1]
        g_col <- if (ncol(data) >= 3 && !names(data)[3] %in% 
            c("ymin", "ymax", "sd", "se")) 
            names(data)[3]
        else NULL
        pal_name <- options$color_palette %||% options$palette %||% 
            "默认"
        orient <- options$orientation %||% "vertical"
        cap_width <- as.numeric(options$cap_width %||% 0.2)
        bw <- as.numeric(options$bar_width %||% 0.6)
        alp <- as.numeric(options$alpha %||% 0.8)
        lbls <- isTRUE(options$show_labels)
        df <- data.frame(x = as.character(data[[x_col]]), ymid = as.numeric(data[[y_col]]), 
            stringsAsFactors = FALSE)
        if (!is.null(g_col)) 
            df$group <- as.character(data[[g_col]])
        if (has_col(data, "ymin") && has_col(data, "ymax")) {
            df$ylo <- as.numeric(data$ymin)
            df$yhi <- as.numeric(data$ymax)
        }
        else if (has_col(data, "sd")) {
            df$ylo <- df$ymid - as.numeric(data$sd)
            df$yhi <- df$ymid + as.numeric(data$sd)
        }
        else if (has_col(data, "se")) {
            df$ylo <- df$ymid - as.numeric(data$se)
            df$yhi <- df$ymid + as.numeric(data$se)
        }
        else {
            df$ylo <- df$ymid * 0.9
            df$yhi <- df$ymid * 1.1
        }
        df <- df[!is.na(df$ymid), ]
        n_grp <- if (!is.null(g_col)) 
            length(unique(df$group))
        else 1
        pal <- get_palette(pal_name, max(n_grp, 1))
        lp <- .bar_label_params(orient)
        if (!is.null(g_col) && "group" %in% names(df)) {
            dw <- 0.75
            p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = ymid, 
                fill = group)) + ggplot2::geom_col(position = ggplot2::position_dodge(dw), 
                width = bw * dw, alpha = alp, color = NA) + ggplot2::geom_errorbar(ggplot2::aes(ymin = ylo, 
                ymax = yhi, group = group), position = ggplot2::position_dodge(dw), 
                width = cap_width, linewidth = 0.7, color = "#333333") + 
                ggplot2::scale_fill_manual(values = pal, name = g_col)
        }
        else {
            p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = ymid)) + 
                ggplot2::geom_col(fill = pal[1], alpha = alp, 
                  width = bw, color = NA) + ggplot2::geom_errorbar(ggplot2::aes(ymin = ylo, 
                ymax = yhi), width = cap_width, linewidth = 0.7, 
                color = "#333333")
        }
        if (lbls) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = round(ymid, 
                1), y = ymid), vjust = lp$vjust + 1.8, hjust = lp$hjust, 
                size = 3, color = "#333333")
        }
        p <- .bar_orient(p, orient)
        apply_theme(p + ggplot2::labs(x = x_col, y = y_col), 
            options)
    }, category = "柱图家族", description = "柱图叠加误差线，展示均值与不确定性（SD/SE/CI）", 
    best_for = "科研组间对比、均值置信区间展示", 
    columns = "x(组别), y(均值), sd(标准差，可选) 或 ymin+ymax(误差区间)", 
    sample_data = structure(list(group = c("对照组", "处理A", 
    "处理B"), mean = c(45.2, 62.8, 55.1), sd = c(8.3, 9.1, 
    7.5)), class = "data.frame", row.names = c(NA, -3L)), options_def = list(
        list(id = "color_palette", label = "配色", type = "select", 
            group = "basic", choices = c(默认 = "默认", 商务蓝 = "商务蓝", 
            自然绿 = "自然绿", 活力橙 = "活力橙", 
            粉紫系 = "粉紫系"), default = "默认"), list(
            id = "orientation", label = "方向", type = "select", 
            group = "basic", choices = c(纵向 = "vertical", 
            横向 = "horizontal"), default = "vertical"), list(
            id = "show_labels", label = "显示均值标签", 
            type = "checkbox", group = "basic", default = FALSE), 
        list(id = "cap_width", label = "误差帽宽", type = "slider", 
            group = "advanced", min = 0.05, max = 0.5, step = 0.05, 
            default = 0.2), list(id = "bar_width", label = "柱宽", 
            type = "slider", group = "advanced", min = 0.2, max = 1, 
            step = 0.05, default = 0.6), list(id = "alpha", label = "透明度", 
            type = "slider", group = "advanced", min = 0.1, max = 1, 
            step = 0.05, default = 0.8)), code_template = function (options) 
    {
        orient <- options$orientation %||% "vertical"
        cw <- options$cap_width %||% 0.2
        bw <- options$bar_width %||% 0.6
        alp <- options$alpha %||% 0.8
        lbls <- isTRUE(options$show_labels)
        paste0("library(ggplot2)\n\ndata <- data.frame(\n  group = c(\"对照组\",\"处理A\",\"处理B\"),\n  mean  = c(45.2, 62.8, 55.1),\n  sd    = c( 8.3,  9.1,  7.5)\n)\n\np <- ggplot(data, aes(x = group, y = mean, fill = group)) +\n  geom_col(alpha = ", 
            alp, ", width = ", bw, ", color = NA) +\n  geom_errorbar(aes(ymin = mean - sd, ymax = mean + sd),\n                width = ", 
            cw, ", linewidth = 0.8, color = \"#333333\") +\n  scale_fill_brewer(palette = \"Set2\", guide = \"none\")", 
            if (lbls) 
                " +\n  geom_text(aes(label = round(mean, 1)), vjust = -2.2, size = 3.5)"
            else "", if (orient == "horizontal") 
                " +\n  coord_flip()"
            else "", " +\n  labs(x = NULL, y = \"均值 ± SD\") +\n  theme_minimal()\n\nprint(p)")
    })

