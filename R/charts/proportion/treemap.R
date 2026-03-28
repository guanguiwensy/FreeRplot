# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "treemap", name = "树状图", category = "通用图表", 
    name_en = "Treemap", plot_fn = function (data, options) 
    {
        target_col <- if ("parent" %in% names(data) && any(nchar(data$parent) > 
            0)) "parent" else "label"
        target_levels <- unique(as.character(data[[target_col]]))
        pal <- palette_values_for_column(data, target_col, options, 
            levels = target_levels, palette_name = options$palette)
        border_width <- as.numeric(options$border_width %||% 
            1.5)
        label_size <- as.numeric(options$label_size %||% 11)
        label_place <- as.character(options$label_place %||% 
            "centre")
        leaf <- data[data$value > 0, ]
        if (nrow(leaf) == 0) 
            stop("treemap 数据中 value 列需要有大于0的数值。")
        has_parent <- "parent" %in% names(leaf) && any(nchar(leaf$parent) > 
            0)
        p <- ggplot2::ggplot(leaf, ggplot2::aes(area = value, 
            fill = if (has_parent) 
                parent
            else label, label = label, subgroup = if (has_parent) 
                parent
            else label)) + treemapify::geom_treemap(color = "white", 
            size = border_width * 0.5, alpha = 0.9) + treemapify::geom_treemap_text(color = "white", 
            place = label_place, size = label_size, fontface = "bold", 
            reflow = TRUE) + ggplot2::scale_fill_manual(values = pal, 
            name = if (has_parent) 
                "分组"
            else "类别")
        if (has_parent) {
            p <- p + treemapify::geom_treemap_subgroup_border(color = "white", 
                size = 1.5) + treemapify::geom_treemap_subgroup_text(color = "white", 
                alpha = 0.4, fontface = "italic", place = "topleft", 
                size = 13)
        }
        p <- p + ggplot2::labs(title = options$title %||% NULL) + 
            ggplot2::theme_void() + ggplot2::theme(plot.title = ggplot2::element_text(size = 14, 
            face = "bold", hjust = 0.5, margin = ggplot2::margin(b = 8)), 
            legend.position = "bottom", plot.margin = ggplot2::margin(10, 
                10, 10, 10))
        p
    }, description = "用大小不等的矩形展示层级数据的占比关系", 
    best_for = "层级结构占比、大量类别的比例可视化", 
    columns = "label(类别名称), parent(父级，无父级留空), value(数值)", 
    sample_data = structure(list(label = c("华东", "华南", 
    "华北", "西部", "上海", "江苏", "浙江", "广东", 
    "广西", "北京", "天津", "四川", "云南"), parent = c("", 
    "", "", "", "华东", "华东", "华东", "华南", "华南", 
    "华北", "华北", "西部", "西部"), value = c(0, 0, 
    0, 0, 150, 120, 100, 180, 80, 140, 90, 110, 70)), class = "data.frame", row.names = c(NA, 
    -13L)), options_def = list(list(id = "border_width", label = "边框宽度", 
        type = "slider", group = "basic", min = 0, max = 5, step = 0.25, 
        default = 1.5), list(id = "label_size", label = "标签字体大小", 
        type = "slider", group = "basic", min = 6, max = 22, 
        step = 1, default = 11), list(id = "label_place", label = "标签位置", 
        type = "select", group = "advanced", choices = c(居中 = "centre", 
        左上 = "topleft", 右下 = "bottomright"), default = "centre")), 
    code_template = function (options) 
    {
        bw <- options$border_width %||% 1.5
        ls <- options$label_size %||% 11
        lp <- options$label_place %||% "centre"
        paste0("library(ggplot2)\nlibrary(treemapify)\n\ndata <- data.frame(\n  label  = c(\"上海\",\"江苏\",\"浙江\",\"广东\",\"广西\",\"北京\",\"天津\",\"四川\",\"云南\"),\n  parent = c(\"华东\",\"华东\",\"华东\",\"华南\",\"华南\",\"华北\",\"华北\",\"西部\",\"西部\"),\n  value  = c(150,120,100, 180,80, 140,90, 110,70)\n)\n\np <- ggplot(data, aes(area=value, fill=parent, label=label, subgroup=parent)) +\n  geom_treemap(color=\"white\", size=", 
            bw * 0.5, ") +\n  geom_treemap_text(color=\"white\", place=\"", 
            lp, "\", size=", ls, ", fontface=\"bold\", reflow=TRUE) +\n  geom_treemap_subgroup_border(color=\"white\", size=1.5) +\n  geom_treemap_subgroup_text(color=\"white\", alpha=0.4, fontface=\"italic\",\n                             place=\"topleft\", size=13) +\n  scale_fill_brewer(palette=\"Set2\") +\n  theme_void() +\n  labs(title=\"树状图\")\n\nprint(p)")
    })

