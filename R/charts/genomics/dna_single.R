# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "dna_single", name = "单序列图", name_en = "Single DNA/RNA Sequence", 
    plot_fn = function (data, options) 
    {
        seq_str <- as.character(data$sequence[1])
        pal_name <- if (!is.null(options$dna_palette) && nchar(options$dna_palette) > 
            0) 
            options$dna_palette
        else "bright_deep"
        pal <- ggDNAvis::sequence_colour_palettes[[pal_name]]
        if (is.null(pal)) 
            pal <- ggDNAvis::sequence_colour_palettes[["bright_deep"]]
        wrap <- as.integer(options$line_wrap %||% 50L)
        ggDNAvis::visualise_single_sequence(sequence = seq_str, 
            sequence_colours = pal, line_wrapping = wrap, outline_linewidth = 1, 
            sequence_text_size = 0, index_annotation_size = 9, 
            pixels_per_base = 30, filename = tempfile(fileext = ".png"), 
            return = TRUE)
    }, category = "基因序列", description = "将单条 DNA/RNA 序列按行显示，A/T/C/G 碱基用不同颜色标注", 
    best_for = "展示单条基因序列结构、论文级别序列可视化", 
    columns = "sequence(单条 DNA/RNA 序列字符串，仅需一行)", 
    sample_data = structure(list(sequence = "GGCGGCGGCGGCGGCGGCGGCGGCGGCGGAGGAGGCGGCGGCGGAGGAGGCGGCGGCGGAGGAGGCGGCGGCGGAGGAGGCGGCGGCGGAGGAGGCGGCG"), class = "data.frame", row.names = c(NA, 
    -1L)), options_def = list(list(id = "line_wrap", label = "每行碱基数", 
        type = "slider", group = "basic", min = 10, max = 150, 
        step = 5, default = 50), list(id = "dna_palette", label = "碱基配色", 
        type = "select", group = "basic", choices = c(高亮深色 = "bright_deep", 
        高亮浅色 = "bright_light", 柔和 = "pastel", 单色 = "monochrome"
        ), default = "bright_deep")), code_template = function (options) 
    {
        lw <- as.integer(options$line_wrap %||% 50)
        pal <- options$dna_palette %||% "bright_deep"
        paste0("library(ggDNAvis)\n\nsequence <- paste0(\n  \"GGCGGCGGCGGCGGCGGCGGCGGCGGCGGAGGAGGCGGCGGCGGAGGAGG\",\n  \"CGGCGGCGGAGGAGGCGGCGGCGGAGGAGGCGGCGGCGGAGGAGGCGGCG\"\n)\n\npal <- ggDNAvis::sequence_colour_palettes[[\"", 
            pal, "\"]]\n\np <- visualise_single_sequence(\n  sequence         = sequence,\n  sequence_colours = pal,\n  line_wrapping    = ", 
            lw, ",\n  outline_linewidth  = 1,\n  sequence_text_size = 0,\n  index_annotation_size = 9,\n  pixels_per_base  = 30,\n  filename         = tempfile(fileext=\".png\"),\n  return           = TRUE\n)\n\nprint(p)")
    })

