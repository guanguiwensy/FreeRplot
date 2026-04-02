# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "correlation", name = "相关矩阵图", category = "通用图表", 
    name_en = "Correlation Matrix", plot_fn = function (data, 
        options) 
    {
        num_data <- data[, sapply(data, is.numeric), drop = FALSE]
        if (ncol(num_data) < 2) 
            stop("相关矩阵图需要至少两列数值变量。")
        method <- as.character(options$method %||% "pearson")
        show_values <- if (is.null(options$show_values)) 
            TRUE
        else isTRUE(options$show_values)
        value_size <- as.numeric(options$value_size %||% 4)
        show_signif <- isTRUE(options$show_signif)
        cor_mat <- cor(num_data, use = "complete.obs", method = method)
        cor_df <- as.data.frame(as.table(cor_mat))
        names(cor_df) <- c("Var1", "Var2", "r")
        if (show_signif) {
            n_obs <- nrow(num_data)
            t_stat <- cor_df$r * sqrt((n_obs - 2)/(1 - cor_df$r^2))
            p_val <- 2 * pt(-abs(t_stat), df = n_obs - 2)
            cor_df$stars <- dplyr::case_when(p_val < 0.01 ~ "**", 
                p_val < 0.05 ~ "*", TRUE ~ "")
            cor_df$label_text <- paste0(round(cor_df$r, 2), cor_df$stars)
        }
        else {
            cor_df$label_text <- as.character(round(cor_df$r, 
                2))
        }
        p <- ggplot2::ggplot(cor_df, ggplot2::aes(x = Var1, y = Var2, 
            fill = r)) + ggplot2::geom_tile(color = "white", 
            linewidth = 0.5) + ggplot2::scale_fill_gradient2(low = "#d73027", 
            mid = "white", high = "#4575b4", midpoint = 0, limit = c(-1, 
                1), name = "相关系数") + ggplot2::coord_fixed() + 
            ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, 
                hjust = 1))
        if (show_values) {
            p <- p + ggplot2::geom_text(ggplot2::aes(label = label_text), 
                size = value_size)
        }
        apply_theme(p, c(options, list(x_label = "", y_label = "")))
    }, description = "展示多个数值变量之间的两两相关系数", 
    best_for = "多变量相关性分析、特征探索", columns = "多列数值变量（各列为一个变量，每行为一个观测）", options_def = list(list(id = "method", label = "相关系数方法", 
        type = "select", group = "basic", choices = c(Pearson = "pearson", 
        Spearman = "spearman", Kendall = "kendall"), default = "pearson"), 
        list(id = "show_values", label = "显示相关系数", 
            type = "checkbox", group = "basic", default = TRUE), 
        list(id = "value_size", label = "数值字体大小", 
            type = "slider", group = "basic", min = 2, max = 10, 
            step = 0.5, default = 4), list(id = "show_signif", 
            label = "标记显著性(*)", type = "checkbox", 
            group = "advanced", default = FALSE)), code_template = function (options) 
    {
        mth <- options$method %||% "pearson"
        sv <- isTRUE(options$show_values %||% TRUE)
        vs <- options$value_size %||% 4
        paste0("library(ggplot2)\nlibrary(dplyr)\nlibrary(tidyr)\n\nset.seed(42)\ndata <- data.frame(\n  身高 = rnorm(50,170,8), 体重 = rnorm(50,65,12),\n  年龄 = rnorm(50,35,10), 收入 = rnorm(50,8000,2000)\n)\n\ncor_mat <- cor(data, method=\"", 
            mth, "\")\ncor_df  <- as.data.frame(as.table(cor_mat)) |>\n  rename(x=Var1, y=Var2, r=Freq)\n\np <- ggplot(cor_df, aes(x=x, y=y, fill=r)) +\n  geom_tile(color=\"white\", linewidth=0.5)", 
            if (sv) 
                paste0(" +\n  geom_text(aes(label=round(r,2)), size=", 
                  vs, ")")
            else "", "  +\n  scale_fill_gradient2(low=\"#d73027\", mid=\"white\", high=\"#1a9850\",\n                       midpoint=0, limits=c(-1,1)) +\n  theme_minimal() +\n  labs(title=\"相关矩阵图\", fill=\"相关系数\")\n\nprint(p)")
    })

