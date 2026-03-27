# 图表设置增强 TODO（已完成）

## 目标
- [x] 增加可配置的图片长宽。
- [x] 增加可配置的坐标轴范围（X/Y 最小值、最大值）。
- [x] 增加 PDF 下载能力。
- [x] 修复 “R代码” 面板不随设置与数据变更同步的问题。

## Phase 1：公共参数与 UI 接入
- [x] 设置面板新增画布与导出参数：`plot_width_in` / `plot_height_in` / `plot_dpi`
- [x] 设置面板新增坐标轴范围参数：`x_range_mode/x_min/x_max`、`y_range_mode/y_min/y_max`
- [x] 图表预览区域新增 PDF 下载入口：`download_plot_pdf`

## Phase 2：绘图与下载后端改造
- [x] 在 `mod_plot` 抽出统一数据来源（`active_data()`）
- [x] 在 `mod_plot` 抽出统一选项来源（`build_plot_options()`）
- [x] 公共设置并入 `options` 传递到绘图核心
- [x] 在 `plot_core` 增加轴范围应用逻辑（`apply_axis_limits()`）
- [x] PNG 下载改为使用用户设定的宽/高/DPI
- [x] 新增 PDF 下载 handler，使用用户设定宽/高
- [x] `circos_plot` 分别支持 PNG/PDF 设备导出

## Phase 3：R 代码同步修复
- [x] `r_code_output` 改为依赖统一数据源与统一设置源
- [x] 设置变化可实时反映到 R 代码输出
- [x] 数据表变化可实时反映到 R 代码输出
- [x] 新增 `data_to_r_code()`，输出当前数据代码（超长自动截断并注释）
- [x] 兼容 `code_template(options)` 与 `code_template(options, data)` 两种签名

## Phase 4：验证与回归
- [x] `source('app.R')` 冒烟通过
- [x] 典型图表在手动轴范围下可生成（scatter/bar/line/histogram）
- [x] 模块级加载通过（`global/ui/server`）

## 实际改动文件
- [x] `D:/coding/r-plot-ai/ui.R`
- [x] `D:/coding/r-plot-ai/R/modules/mod_plot.R`
- [x] `D:/coding/r-plot-ai/R/modules/mod_settings.R`
- [x] `D:/coding/r-plot-ai/R/plot_core.R`
- [x] `D:/coding/r-plot-ai/R/preset_manager.R`