# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "violin", name = "小提琴图", category = "通用图表", 
    name_en = "Violin Plot", plot_fn = function (data, options) 
    {
        group_levels <- unique(as.character(data$group))
        pal <- palette_values_for_column(data, "group", options, 
            levels = group_levels, palette_name = options$palette)
        show_boxplot <- if (is.null(options$show_boxplot)) 
            TRUE
        else isTRUE(options$show_boxplot)
        trim <- isTRUE(options$trim)
        fill_alpha <- as.numeric(options$fill_alpha %||% 0.7)
        scale_type <- as.character(options$scale_type %||% "area")
        bw_adjust <- as.numeric(options$bw_adjust %||% 1)
        p <- ggplot2::ggplot(data, ggplot2::aes(x = factor(group), 
            y = value, fill = factor(group))) + ggplot2::geom_violin(alpha = fill_alpha, 
            trim = trim, scale = scale_type, adjust = bw_adjust) + 
            ggplot2::scale_fill_manual(values = pal) + ggplot2::theme(legend.position = "none")
        if (show_boxplot) {
            p <- p + ggplot2::geom_boxplot(width = 0.12, fill = "white", 
                outlier.shape = NA)
        }
        apply_theme(p, c(options, list(x_label = options$x_label %||% 
            "分组", y_label = options$y_label %||% "数值")))
    }, description = "展示数据分布密度，结合箱线图优点", 
    best_for = "多组数据分布形状比较", columns = "group(分组), value(数值)", 
    sample_data = structure(list(group = c("处理A", "处理A", 
    "处理A", "处理A", "处理A", "处理A", "处理A", "处理A", 
    "处理A", "处理A", "处理A", "处理A", "处理A", "处理A", 
    "处理A", "处理A", "处理A", "处理A", "处理A", "处理A", 
    "处理A", "处理A", "处理A", "处理A", "处理A", "处理A", 
    "处理A", "处理A", "处理A", "处理A", "处理B", "处理B", 
    "处理B", "处理B", "处理B", "处理B", "处理B", "处理B", 
    "处理B", "处理B", "处理B", "处理B", "处理B", "处理B", 
    "处理B", "处理B", "处理B", "处理B", "处理B", "处理B", 
    "处理B", "处理B", "处理B", "处理B", "处理B", "处理B", 
    "处理B", "处理B", "处理B", "处理B", "处理C", "处理C", 
    "处理C", "处理C", "处理C", "处理C", "处理C", "处理C", 
    "处理C", "处理C", "处理C", "处理C", "处理C", "处理C", 
    "处理C", "处理C", "处理C", "处理C", "处理C", "处理C", 
    "处理C", "处理C", "处理C", "处理C", "处理C", "处理C", 
    "处理C", "处理C", "处理C", "处理C"), value = c(4.82447412975787, 
    3.92821761584932, 5.16320688246738, 4.63726158437205, 5.59001354798734, 
    6.43242192773099, 4.00730748889051, 5.45465029758028, 5.08489805867849, 
    5.89556558226454, 4.77022186105373, 5.83661906846061, 3.25494413866331, 
    6.68945892131337, 5.86477797851858, 4.84922401111425, 3.55099286986083, 
    5.64300870004198, 5.48319386381477, 4.99364437357861, 5.15145589286242, 
    4.4158910296502, 5.36880673263024, 5.29465433971952, 4.72074062665742, 
    3.66376334510685, 5.70074881844003, 5.55419662227403, 4.16369340719858, 
    3.40541183799376, 7.40991716117527, 6.30982404405422, 7.50522340672891, 
    4.41199506903089, 5.08165911123927, 9.1715497073598, 7.80754980943143, 
    8.1729750734386, 10.6304568923079, 7.25764285720477, 2.99814152453698, 
    7.66755439486714, 9.34265025471759, 11.1190784845986, 4.24627680351896, 
    4.69828886874579, 5.58835721047976, 4.89188843584562, 5.70851255371502, 
    6.62924406464699, 4.59755589852003, 11.0739443339663, 7.21554948977109, 
    6.83178379898884, 7.99123928320919, 7.07483037223593, 6.73582392608818, 
    9.95357484710419, 6.56593957981579, 4.43279559181555, 4.1928339452217, 
    3.82424356323545, 3.73910195332187, 3.46593439965641, 4.21418295163335, 
    3.9129908827865, 4.25783386432401, 3.88281736134704, 3.67074828708911, 
    4.62511830203936, 3.8641181424443, 4.4739759979376, 3.39920878494553, 
    3.76694195181225, 3.86532430242341, 7.80451729593457, 8.67435350599586, 
    7.98861764935079, 8.12211292555173, 7.52881414606804, 7.63539136174521, 
    8.49903445427742, 8.62924083229778, 8.62443184440505, 7.30968147523734, 
    9.0249803468182, 8.50843641489977, 7.98664126793087, 8.35180388939913, 
    7.51430738542407)), class = "data.frame", row.names = c(NA, 
    -90L)), options_def = list(list(id = "show_boxplot", label = "内嵌箱线图", 
        type = "checkbox", group = "basic", default = TRUE), 
        list(id = "trim", label = "裁剪尾端", type = "checkbox", 
            group = "basic", default = FALSE), list(id = "fill_alpha", 
            label = "填充透明度", type = "slider", group = "basic", 
            min = 0.1, max = 1, step = 0.05, default = 0.7), 
        list(id = "scale_type", label = "缩放方式", type = "select", 
            group = "advanced", choices = c(面积相等 = "area", 
            按计数 = "count", 宽度相等 = "width"), default = "area"), 
        list(id = "bw_adjust", label = "带宽调整", type = "slider", 
            group = "advanced", min = 0.3, max = 3, step = 0.1, 
            default = 1)), code_template = function (options) 
    {
        sbp <- isTRUE(options$show_boxplot %||% TRUE)
        tr <- isTRUE(options$trim)
        fa <- options$fill_alpha %||% 0.7
        sc <- options$scale_type %||% "area"
        bwa <- options$bw_adjust %||% 1
        paste0("library(ggplot2)\n\nset.seed(42)\ndata <- data.frame(\n  group = rep(c(\"处理A\",\"处理B\",\"处理C\"), each=30),\n  value = c(rnorm(30,5,1), rnorm(30,7,2), c(rnorm(15,4,0.5), rnorm(15,8,0.5)))\n)\n\np <- ggplot(data, aes(x=group, y=value, fill=group)) +\n  geom_violin(trim=", 
            tr, ", alpha=", fa, ", scale=\"", sc, "\", adjust=", 
            bwa, ")", if (sbp) 
                " +\n  geom_boxplot(width=0.12, fill=\"white\", outlier.shape=NA)"
            else "", "  +\n  scale_fill_brewer(palette=\"Set2\") +\n  theme_minimal() +\n  labs(title=\"小提琴图\", x=\"处理组\", y=\"数值\")\n\nprint(p)")
    })

