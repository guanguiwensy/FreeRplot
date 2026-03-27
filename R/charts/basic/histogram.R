# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "histogram", name = "直方图", category = "通用图表", 
    name_en = "Histogram", plot_fn = function (data, options) 
    {
        pal <- get_palette(options$palette, 7)
        bins <- suppressWarnings(as.integer(options$bins %||% 
            30))
        if (is.na(bins) || bins < 1) 
            bins <- 30
        fill_alpha <- as.numeric(options$fill_alpha %||% 0.85)
        show_density <- isTRUE(options$show_density)
        show_rug <- isTRUE(options$show_rug)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = value))
        if (has_col(data, "group")) {
            p <- p + ggplot2::geom_histogram(ggplot2::aes(fill = factor(group)), 
                bins = bins, alpha = fill_alpha, position = "identity", 
                color = "white") + ggplot2::scale_fill_manual(values = pal, 
                name = "分组")
        }
        else {
            p <- p + ggplot2::geom_histogram(bins = bins, fill = pal[1], 
                color = "white", alpha = fill_alpha)
        }
        if (show_density) {
            if (has_col(data, "group")) {
                p <- p + ggplot2::geom_density(ggplot2::aes(y = ggplot2::after_stat(count), 
                  color = factor(group)), linewidth = 1, show.legend = FALSE) + 
                  ggplot2::scale_color_manual(values = pal)
            }
            else {
                p <- p + ggplot2::geom_density(ggplot2::aes(y = ggplot2::after_stat(count)), 
                  color = pal[2], linewidth = 1)
            }
        }
        if (show_rug) {
            p <- p + ggplot2::geom_rug(alpha = 0.3)
        }
        apply_theme(p, c(options, list(x_label = options$x_label %||% 
            "数值", y_label = options$y_label %||% "频数")))
    }, description = "展示单个连续变量的分布情况", 
    best_for = "数据分布分析、频率统计", columns = "value(数值), group(分组，可选)", 
    sample_data = structure(list(value = c(180.967667577173, 
    165.482414628831, 172.905027290699, 175.062900839688, 173.234146585128, 
    169.151003871268, 182.092175979512, 169.242727692695, 186.147389711016, 
    169.498287207581, 180.438957233788, 188.293163141609, 158.889114391101, 
    167.769689865461, 168.933429308851, 175.087603184561, 167.725976628671, 
    148.748356632762, 150.476264571396, 180.560906765842, 167.546891247372, 
    155.74953252816, 168.624661153923, 179.717397593381, 185.16154769012, 
    166.55624694715, 167.941844937849, 155.894695318442, 173.68077883865, 
    164.880040992319, 173.64360098593, 175.638698697831, 178.280828175759, 
    165.128588996742, 174.039640986384, 156.263930567413, 163.724327932964, 
    163.192739246588, 150.686338800427, 170.288980855138, 171.647988801602, 
    167.111541611611, 176.065305885596, 164.186361383387, 159.053751644646, 
    173.46254420711, 163.508854590507, 181.55281009377, 166.548430379093, 
    175.245183067218, 164.253476856428, 156.513127413837, 173.030092638544, 
    166.500295140021, 162.628324526197, 163.93585523104, 166.755021712387, 
    162.628830206054, 141.048369417929, 163.994180674715, 159.429357500813, 
    163.296613954059, 166.072766091559, 171.798157791049, 156.908955583679, 
    171.117798424309, 164.350936838265, 169.269542690883, 168.445099978035, 
    167.046147140068, 154.698167430025, 161.368695293725, 166.364627133997, 
    155.325336495594, 158.200198297983, 166.066975483772, 167.377251164842, 
    165.246373119781, 155.799565918132, 154.301533709465, 172.588949068634, 
    163.805450062724, 162.619081604117, 161.153724237226, 153.639697733876, 
    166.283978286283, 160.480021079774, 160.720703055677, 168.533424299998, 
    167.752411773558, 171.74481463154, 158.666782538617, 166.552439925084, 
    171.73777319473, 154.224477843865, 155.974451891855, 154.077829234024, 
    151.785502003483, 162.559877872688, 166.572430377544), group = c("男", 
    "男", "男", "男", "男", "男", "男", "男", "男", "男", 
    "男", "男", "男", "男", "男", "男", "男", "男", "男", 
    "男", "男", "男", "男", "男", "男", "男", "男", "男", 
    "男", "男", "男", "男", "男", "男", "男", "男", "男", 
    "男", "男", "男", "男", "男", "男", "男", "男", "男", 
    "男", "男", "男", "男", "女", "女", "女", "女", "女", 
    "女", "女", "女", "女", "女", "女", "女", "女", "女", 
    "女", "女", "女", "女", "女", "女", "女", "女", "女", 
    "女", "女", "女", "女", "女", "女", "女", "女", "女", 
    "女", "女", "女", "女", "女", "女", "女", "女", "女", 
    "女", "女", "女", "女", "女", "女", "女", "女", "女"
    )), class = "data.frame", row.names = c(NA, -100L)), options_def = list(
        list(id = "bins", label = "分箱数", type = "slider", 
            group = "basic", min = 5, max = 100, step = 1, default = 30), 
        list(id = "fill_alpha", label = "填充透明度", type = "slider", 
            group = "basic", min = 0.1, max = 1, step = 0.05, 
            default = 0.85), list(id = "show_density", label = "叠加密度曲线", 
            type = "checkbox", group = "advanced", default = FALSE), 
        list(id = "show_rug", label = "显示地毯图", type = "checkbox", 
            group = "advanced", default = FALSE)), code_template = function (options) 
    {
        bn <- as.integer(options$bins %||% 30)
        fa <- options$fill_alpha %||% 0.85
        sd_ <- isTRUE(options$show_density)
        sr <- isTRUE(options$show_rug)
        paste0("library(ggplot2)\n\nset.seed(42)\ndata <- data.frame(\n  value = c(rnorm(50, 170, 8), rnorm(50, 162, 7)),\n  group = rep(c(\"男\",\"女\"), each=50)\n)\n\np <- ggplot(data, aes(x=value, fill=group)) +\n  geom_histogram(bins=", 
            bn, ", alpha=", fa, ", position=\"identity\")", if (sd_) 
                " +\n  geom_density(aes(y=after_stat(count)), color=\"black\", linewidth=0.8)"
            else "", if (sr) 
                " +\n  geom_rug(alpha=0.3)"
            else "", "  +\n  scale_fill_brewer(palette=\"Set1\") +\n  theme_minimal() +\n  labs(title=\"直方图\", x=\"数值\", y=\"频数\")\n\nprint(p)")
    })

