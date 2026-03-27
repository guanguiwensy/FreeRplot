# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "circos", name = "弦图", name_en = "Chord Diagram (Circos)", 
    category = "通用图表", plot_fn = function (data, options) 
    {
        if (!all(c("from", "to", "value") %in% names(data))) 
            stop("弦图需要 from、to、value 三列数据。")
        df <- data[!is.na(data$from) & !is.na(data$to) & !is.na(data$value), 
            ]
        df$value <- as.numeric(df$value)
        if (nrow(df) == 0) 
            stop("弦图数据行均为空，请检查数据。")
        all_sectors <- unique(c(df$from, df$to))
        n_sec <- length(all_sectors)
        pal_name <- options$palette %||% "默认"
        pal <- get_palette(pal_name, n_sec)
        grid_col <- setNames(pal[seq_len(n_sec)], all_sectors)
        title_text <- options$title %||% ""
        transp <- as.numeric(options$circos_transparency %||% 
            0.25)
        gap_size <- as.numeric(options$gap_size %||% 3)
        start_degree <- as.numeric(options$start_degree %||% 
            90)
        link_sort <- if (is.null(options$link_sort)) 
            TRUE
        else isTRUE(options$link_sort)
        draw_fn <- function() {
            circlize::circos.clear()
            old_par <- graphics::par(no.readonly = TRUE)
            on.exit({
                circlize::circos.clear()
                graphics::par(old_par)
            }, add = TRUE)
            circlize::circos.par(start.degree = start_degree, 
                clock.wise = TRUE, gap.after = rep(gap_size, 
                  n_sec), message = FALSE)
            circlize::chordDiagram(df, grid.col = grid_col, transparency = transp, 
                annotationTrack = c("name", "grid"), annotationTrackHeight = c(0.03, 
                  0.05), link.sort = link_sort, link.decreasing = TRUE, 
                self.link = 1)
            if (nchar(title_text) > 0) 
                graphics::title(main = title_text, cex.main = 1.3, 
                  font.main = 2, line = -1)
        }
        structure(list(draw = draw_fn), class = "circos_plot")
    }, description = "用弧线连接环形扇区，直观展示类别之间的流向与关联强度，哈佛 Nature 风格", 
    best_for = "群体间基因共享、物种迁移流向、模块间交互强度、相关矩阵可视化", 
    columns = "from(来源分组), to(目标分组), value(流量/权重，数值)", 
    sample_data = structure(list(from = c("免疫细胞", "免疫细胞", 
    "免疫细胞", "肿瘤细胞", "肿瘤细胞", "基质细胞", 
    "基质细胞", "内皮细胞", "内皮细胞", "神经元", 
    "神经元"), to = c("肿瘤细胞", "基质细胞", "内皮细胞", 
    "基质细胞", "神经元", "内皮细胞", "神经元", 
    "神经元", "免疫细胞", "免疫细胞", "肿瘤细胞"
    ), value = c(35, 20, 15, 28, 12, 18, 10, 22, 16, 14, 25)), class = "data.frame", row.names = c(NA, 
    -11L)), options_def = list(list(id = "circos_transparency", 
        label = "连接透明度", type = "slider", group = "basic", 
        min = 0, max = 0.8, step = 0.05, default = 0.25), list(
        id = "gap_size", label = "扇区间距", type = "slider", 
        group = "basic", min = 1, max = 15, step = 0.5, default = 3), 
        list(id = "start_degree", label = "起始角度", type = "slider", 
            group = "advanced", min = 0, max = 360, step = 10, 
            default = 90), list(id = "link_sort", label = "连接排序", 
            type = "checkbox", group = "advanced", default = TRUE)), 
    code_template = function (options) 
    {
        tr <- options$circos_transparency %||% 0.25
        gs <- options$gap_size %||% 3
        sd <- options$start_degree %||% 90
        ls <- isTRUE(options$link_sort %||% TRUE)
        paste0("library(circlize)\n\ndata <- data.frame(\n  from  = c(\"免疫细胞\",\"免疫细胞\",\"肿瘤细胞\",\"肿瘤细胞\",\"基质细胞\",\"内皮细胞\"),\n  to    = c(\"肿瘤细胞\",\"基质细胞\",\"基质细胞\",\"神经元\",  \"内皮细胞\",\"神经元\"),\n  value = c(35,20,28,12,18,22)\n)\n\nsectors <- unique(c(data$from, data$to))\npal     <- setNames(RColorBrewer::brewer.pal(length(sectors),\"Set2\"), sectors)\n\ncircos.clear()\ncircos.par(start.degree=", 
            sd, ", clock.wise=TRUE,\n           gap.after=rep(", 
            gs, ", length(sectors)), message=FALSE)\n\nchordDiagram(data, grid.col=pal, transparency=", 
            tr, ",\n             annotationTrack=c(\"name\",\"grid\"),\n             link.sort=", 
            ls, ", link.decreasing=TRUE, self.link=1)\n\ncircos.clear()")
    })

