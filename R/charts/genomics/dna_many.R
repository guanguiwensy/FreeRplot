# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "dna_many", name = "多序列比对图", name_en = "Multiple DNA/RNA Sequences", 
    plot_fn = function (data, options) 
    {
        seqs <- as.character(data$sequence)
        seqs <- seqs[!is.na(seqs) & nchar(seqs) > 0]
        pal_name <- if (!is.null(options$dna_palette) && nchar(options$dna_palette) > 
            0) 
            options$dna_palette
        else "bright_deep"
        pal <- ggDNAvis::sequence_colour_palettes[[pal_name]]
        if (is.null(pal)) 
            pal <- ggDNAvis::sequence_colour_palettes[["bright_deep"]]
        ggDNAvis::visualise_many_sequences(sequences_vector = seqs, 
            sequence_colours = pal, outline_linewidth = 1, sequence_text_size = 0, 
            index_annotation_size = 9, pixels_per_base = 30, 
            filename = tempfile(fileext = ".png"), return = TRUE)
    }, category = "基因序列", description = "多条 DNA/RNA 序列并排展示，直观比较不同读取间的碱基差异", 
    best_for = "多样本序列比对、reads 可视化、家系序列比较", 
    columns = "sequence(每行一条 DNA/RNA 序列字符串)", options_def = list(
        list(id = "dna_palette", label = "碱基配色", type = "select", 
            group = "basic", choices = c(高亮深色 = "bright_deep", 
            高亮浅色 = "bright_light", 柔和 = "pastel", 
            单色 = "monochrome"), default = "bright_deep")), 
    code_template = function (options) 
    {
        pal <- options$dna_palette %||% "bright_deep"
        paste0("library(ggDNAvis)\n\nsequences <- c(\n  \"GGCGGCGGCGGCGGCGGCGGCGGCGGCGGAGGAGGCGGCGGCGGAGGAGG\",\n  \"GGCGGCGGCGGCGGCGGCGGCGGCGGCGGCGGCGGAGGAGGCGGCGGCGG\",\n  \"GGCGGCGGCGGCGGCGGCGGCGGCGGCGGAGGAGGCGGCGGCGGAGGAGG\",\n  \"GGCGGCGGCGGCGGCGGCGGCGGCGGCGGCGGCGGCGGAGGAGGCGGCGG\"\n)\n\npal <- ggDNAvis::sequence_colour_palettes[[\"", 
            pal, "\"]]\n\np <- visualise_many_sequences(\n  sequences_vector   = sequences,\n  sequence_colours   = pal,\n  outline_linewidth  = 1,\n  sequence_text_size = 0,\n  index_annotation_size = 9,\n  pixels_per_base    = 30,\n  filename           = tempfile(fileext=\".png\"),\n  return             = TRUE\n)\n\nprint(p)")
    })

