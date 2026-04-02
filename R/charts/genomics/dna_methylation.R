# Auto-generated in phase-4: chart metadata + inlined plot_fn implementation

chart_def <- list(id = "dna_methylation", name = "甲基化修饰图", name_en = "DNA Methylation", 
    plot_fn = function (data, options) 
    {
        seqs <- as.character(data$sequence)
        mod_locs <- as.character(data$mod_positions)
        mod_probs <- as.character(data$mod_probs)
        ok <- !is.na(seqs) & nchar(seqs) > 0 & !is.na(mod_locs) & 
            nchar(mod_locs) > 0 & !is.na(mod_probs) & nchar(mod_probs) > 
            0
        seqs <- seqs[ok]
        mod_locs <- mod_locs[ok]
        mod_probs <- mod_probs[ok]
        color_low <- as.character(options$color_low %||% "#DEEBF7")
        color_high <- as.character(options$color_high %||% "#08519C")
        ggDNAvis::visualise_methylation(modification_locations = mod_locs, 
            modification_probabilities = mod_probs, sequences = seqs, 
            outline_linewidth = 1, modified_bases_outline_linewidth = 1, 
            other_bases_outline_linewidth = 1, sequence_text_size = 0, 
            index_annotation_size = 9, pixels_per_base = 30, 
            low_colour = color_low, high_colour = color_high, 
            filename = tempfile(fileext = ".png"), return = TRUE)
    }, category = "基因序列", description = "在序列上叠加 CpG 甲基化概率热图，颜色深浅代表修饰程度", 
    best_for = "Nanopore 测序甲基化分析、表观遗传学可视化", 
    columns = "sequence(DNA序列), mod_positions(逗号分隔的修饰位置，如 3,6,9), mod_probs(逗号分隔的修饰概率 0-255，如 200,50,230)", options_def = list(
        list(id = "color_low", label = "低甲基化颜色", 
            type = "color", group = "basic", default = "#DEEBF7"), 
        list(id = "color_high", label = "高甲基化颜色", 
            type = "color", group = "basic", default = "#08306B")), 
    code_template = function (options) 
    {
        cl <- options$color_low %||% "#DEEBF7"
        ch <- options$color_high %||% "#08306B"
        paste0("library(ggDNAvis)\n\nsequences  <- ggDNAvis::example_many_sequences$sequence[1:4]\nmod_locs   <- ggDNAvis::example_many_sequences$methylation_locations[1:4]\nmod_probs  <- ggDNAvis::example_many_sequences$methylation_probabilities[1:4]\n\np <- visualise_methylation(\n  modification_locations   = mod_locs,\n  modification_probabilities = mod_probs,\n  sequences                = sequences,\n  low_colour               = \"", 
            cl, "\",\n  high_colour              = \"", ch, "\",\n  outline_linewidth        = 1,\n  sequence_text_size       = 0,\n  index_annotation_size    = 9,\n  pixels_per_base          = 30,\n  filename                 = tempfile(fileext=\".png\"),\n  return                   = TRUE\n)\n\nprint(p)")
    })

