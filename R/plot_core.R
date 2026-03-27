# R/plot_core.R
# Shared plotting core used by per-chart inlined plot_fn implementations.

COLOR_PALETTES <- list(
  "\u9ed8\u8ba4"   = c("#4ECDC4", "#FF6B6B", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F", "#C3A6FF"),
  "\u5546\u52a1\u84dd" = c("#003f5c", "#2f4b7c", "#665191", "#a05195", "#d45087", "#f95d6a", "#ff7c43"),
  "\u81ea\u7136\u7eff" = c("#264653", "#2a9d8f", "#57cc99", "#80b918", "#e9c46a", "#f4a261", "#e76f51"),
  "\u6d3b\u529b\u6a59" = c("#d62828", "#e85d04", "#f48c06", "#faa307", "#ffba08", "#e9c46a", "#a8dadc"),
  "\u7c89\u7d2b\u7cfb" = c("#7b2d8b", "#9b5de5", "#f15bb5", "#fee440", "#00bbf9", "#00f5d4", "#fb5607")
)

CHART_THEMES <- list(
  "\u7b80\u6d01\u767d" = ggplot2::theme_minimal,
  "\u7ecf\u5178"       = ggplot2::theme_classic,
  "\u7070\u8272"       = ggplot2::theme_gray,
  "\u9ed1\u767d"       = ggplot2::theme_bw
)

get_palette <- function(name, n = 7) {
  pal <- COLOR_PALETTES[[name %||% "\u9ed8\u8ba4"]]
  if (is.null(pal)) pal <- COLOR_PALETTES[["\u9ed8\u8ba4"]]
  if (n <= length(pal)) pal[seq_len(n)] else grDevices::colorRampPalette(pal)(n)
}

safe_limits <- function(min_v, max_v) {
  if (is.null(min_v) || is.null(max_v)) return(NULL)
  min_v <- suppressWarnings(as.numeric(min_v))
  max_v <- suppressWarnings(as.numeric(max_v))
  if (is.na(min_v) || is.na(max_v)) return(NULL)
  if (!is.finite(min_v) || !is.finite(max_v)) return(NULL)
  if (max_v <= min_v) return(NULL)
  c(min_v, max_v)
}

apply_axis_limits <- function(p, options) {
  xlim <- NULL
  ylim <- NULL

  if (identical(options$x_range_mode %||% "auto", "manual") && isTRUE(options$x_is_numeric)) {
    xlim <- safe_limits(options$x_min, options$x_max)
  }
  if (identical(options$y_range_mode %||% "auto", "manual") && isTRUE(options$y_is_numeric)) {
    ylim <- safe_limits(options$y_min, options$y_max)
  }

  if (is.null(xlim) && is.null(ylim)) return(p)
  p + ggplot2::coord_cartesian(xlim = xlim, ylim = ylim)
}

apply_theme <- function(p, options) {
  theme_fn <- CHART_THEMES[[options$theme %||% "\u7b80\u6d01\u767d"]]
  if (is.null(theme_fn)) theme_fn <- ggplot2::theme_minimal

  p <- apply_axis_limits(p, options)

  p +
    theme_fn() +
    ggplot2::labs(
      title = options$title   %||% NULL,
      x     = options$x_label %||% NULL,
      y     = options$y_label %||% NULL
    ) +
    ggplot2::theme(
      plot.title      = ggplot2::element_text(size = 14, face = "bold",
                                              hjust = 0.5, margin = ggplot2::margin(b = 10)),
      axis.title      = ggplot2::element_text(size = 11),
      legend.position = "bottom",
      plot.margin     = ggplot2::margin(15, 15, 15, 15)
    )
}

has_col <- function(data, col) col %in% names(data) && !all(is.na(data[[col]]))

.bar_orient <- function(p, orient) {
  if (identical(orient, "horizontal")) p + ggplot2::coord_flip() else p
}

.bar_label_params <- function(orient) {
  if (identical(orient, "horizontal")) {
    list(vjust = 0.5, hjust = -0.2)
  } else {
    list(vjust = -0.4, hjust = 0.5)
  }
}

generate_plot <- function(chart_id, data, options = list()) {
  if (is.null(data) || nrow(data) == 0) stop("\u6570\u636e\u4e3a\u7a7a\uff0c\u8bf7\u5148\u5f55\u5165\u6570\u636e\u3002")
  fn <- CHARTS[[chart_id]]$plot_fn
  if (!is.function(fn)) stop(paste("\u672a\u6ce8\u518c\u7684\u56fe\u8868\u7c7b\u578b:", chart_id))
  fn(data, options)
}
