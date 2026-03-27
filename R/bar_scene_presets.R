# R/bar_scene_presets.R
# Built-in scene templates for the bar chart family.
# Each entry specifies which bar_* chart type to switch to and what option
# values to pre-fill, so users can jump straight to a common use-case.

BAR_SCENE_PRESETS <- list(

  list(
    id         = "basic_compare",
    name       = "基础对比",
    icon       = "📊",
    desc       = "单色柱图，降序排列",
    chart_type = "bar_value",
    options    = list(
      fill_color  = "#4ECDC4",
      sort_bars   = "desc",
      show_labels = TRUE,
      label_size  = 3.5,
      orientation = "vertical"
    )
  ),

  list(
    id         = "hbar_topn",
    name       = "横向 TopN",
    icon       = "📈",
    desc       = "水平排名，适合长标签",
    chart_type = "bar_horizontal",
    options    = list(
      top_n       = 10,
      sort_bars   = "desc",
      fill_color  = "#FF6B6B",
      show_labels = TRUE,
      label_size  = 3.5
    )
  ),

  list(
    id         = "grouped_compare",
    name       = "分组对比",
    icon       = "🔀",
    desc       = "并列柱图，多组比较",
    chart_type = "bar_grouped",
    options    = list(
      color_palette = "商务蓝",
      orientation   = "vertical",
      show_labels   = FALSE
    )
  ),

  list(
    id         = "stacked_abs",
    name       = "堆叠构成",
    icon       = "📦",
    desc       = "绝对值堆叠，看总量与构成",
    chart_type = "bar_stacked",
    options    = list(
      color_palette = "自然绿",
      orientation   = "vertical",
      show_labels   = TRUE,
      label_size    = 3.0
    )
  ),

  list(
    id         = "stacked_pct",
    name       = "百分比构成",
    icon       = "🥧",
    desc       = "100% 堆叠，看比例结构",
    chart_type = "bar_filled",
    options    = list(
      color_palette = "粉紫系",
      orientation   = "vertical",
      show_labels   = TRUE,
      label_size    = 3.0
    )
  ),

  list(
    id         = "count_freq",
    name       = "频次统计",
    icon       = "🔢",
    desc       = "自动计数，无需 y 列",
    chart_type = "bar_count",
    options    = list(
      fill_color  = "#45B7D1",
      sort_bars   = TRUE,
      show_count  = TRUE
    )
  ),

  list(
    id         = "diverging",
    name       = "正负发散",
    icon       = "↕",
    desc       = "正负值分向，适合差值/FC",
    chart_type = "bar_diverging",
    options    = list(
      show_zero_line = TRUE,
      show_labels    = TRUE
    )
  ),

  list(
    id         = "errorbar_sci",
    name       = "科研误差线",
    icon       = "🔬",
    desc       = "均值 ± SE，适合统计比较",
    chart_type = "bar_errorbar",
    options    = list(
      show_points = TRUE,
      error_type  = "se"
    )
  )
)

# IDs of all bar-family chart types — computed lazily at server startup
# (depends on CHART_MENU_GROUPS from ui_helpers.R; resolved after all sources run)
.bar_family_key <- "\U0001f4c9 \u67f1\u56fe\u5bb6\u65cf"   # "📉 柱图家族"
BAR_FAMILY_IDS  <- character(0)   # filled in global.R after all sources complete
