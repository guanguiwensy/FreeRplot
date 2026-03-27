# R/scatter_scene_presets.R
# Built-in scene templates for scatter family charts.

SCATTER_SCENE_PRESETS <- list(

  list(
    id         = "corr_basic",
    name       = "相关性基础",
    icon       = "·",
    desc       = "基础散点 + 轻量趋势线",
    chart_type = "scatter_basic",
    options    = list(
      point_size    = 3,
      alpha         = 0.75,
      point_shape   = "16",
      show_smooth   = TRUE,
      smooth_method = "loess",
      show_ci       = TRUE,
      show_ellipse  = FALSE
    )
  ),

  list(
    id         = "group_compare",
    name       = "分组比较",
    icon       = "·",
    desc       = "按 group 着色并显示分组椭圆",
    chart_type = "scatter_grouped",
    options    = list(
      point_size    = 3,
      alpha         = 0.78,
      shape_by_group = FALSE,
      show_ellipse  = TRUE,
      show_centroid = TRUE
    )
  ),

  list(
    id         = "regression_ci",
    name       = "回归拟合",
    icon       = "·",
    desc       = "线性回归 + 置信区间",
    chart_type = "scatter_regression",
    options    = list(
      point_size    = 2.8,
      alpha         = 0.72,
      smooth_method = "lm",
      show_ci       = TRUE,
      fit_by_group  = FALSE,
      show_equation = TRUE
    )
  ),

  list(
    id         = "bubble_impact",
    name       = "气泡影响力",
    icon       = "·",
    desc       = "x/y + size 的三变量散点",
    chart_type = "scatter_bubble",
    options    = list(
      size_min    = 3,
      size_max    = 18,
      alpha       = 0.65,
      show_labels = FALSE,
      stroke_width = 0.4
    )
  ),

  list(
    id         = "outlier_label",
    name       = "离群点标注",
    icon       = "·",
    desc       = "自动标注远离中心的 TopN 点",
    chart_type = "scatter_basic",
    options    = list(
      point_size    = 3,
      alpha         = 0.7,
      show_smooth   = FALSE,
      show_ellipse  = FALSE,
      show_labels   = TRUE,
      label_top_n   = 8
    )
  )
)

# IDs of all scatter-family chart types, resolved in global.R after CHART_MENU_GROUPS loads.
.scatter_family_key <- "\U0001f3af \u6563\u70b9\u56fe\u5bb6\u65cf" # "🎯 散点图家族"
SCATTER_FAMILY_IDS <- character(0)
