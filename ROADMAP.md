# R 智能绘图助手 — 图表深度扩展路线图

> 目标：将每张图从「固定参数」升级为「可深度配置 + 可生成代码 + 可保存预设」的专业绘图工具。

---

## 现状分析

```
当前架构（扁平化）：
  用户 → 固定控件（调色板/主题/标题/X轴/Y轴）
       → options{} 字典（所有图通用）
       → generate_plot(chart_id, data, options)
       → plot_xxx(data, options)   ← 内部参数硬编码，用户无法触达

问题：
  1. scatter 和 circos 面板完全相同，毫无个性
  2. 点大小、透明度、趋势线等核心参数用户无法调节
  3. 新增图表时无法声明自己需要什么控件
  4. 没有学习价值（不展示对应 R 代码）
  5. 好的配置无法保存复用
```

---

## 升级后架构（目标）

```
chart_registry.R
  每个图额外定义：
    options_def     → 声明有哪些控件（类型/默认值/分组/依赖关系）
    code_template   → 函数，接收 options 返回等效 R 代码字符串

R/ui_helpers.R（新文件）
  build_controls()  → 遍历 options_def，生成对应 Shiny 控件
  collect_options() → 从 input$opt_* 收集当前选项值

app.R
  options 面板 → renderUI，根据当前图的 options_def 动态生成
  新增「R 代码」标签页 → 展示 code_template 输出，可复制
  新增「预设」面板 → 保存/加载命名配置

plot_generator.R
  各 plot_xxx() 函数 → 读取 options 里的细粒度参数
```

---

## 阶段一：options_def 注册制 + 动态控件面板

> **这是所有后续阶段的基础，必须最先完成。**

### 1.1 设计 options_def 数据结构

确定每个控件描述对象的字段规范：

```r
list(
  id       = "point_size",       # 唯一标识，对应 options$point_size
  label    = "点大小",           # 界面显示名称
  type     = "slider",           # 控件类型：slider/checkbox/select/color/numeric/text
  group    = "basic",            # "basic"=常显 | "advanced"=折叠在「高级设置」里
  default  = 3,                  # 默认值
  # slider 专属
  min = 0.5, max = 10, step = 0.5,
  # select 专属
  choices  = c("线性"="lm", "局部回归"="loess"),
  # 条件显示（Phase 3 实现，Phase 1 先忽略）
  show_when = "show_smooth==TRUE"
)
```

**涉及文件：** 仅文档/注释，无代码改动
**验收：** 写出完整字段说明，各图表设计者有据可查

---

### 1.2 新建 `R/ui_helpers.R`

实现两个核心函数：

```r
# 将 options_def 列表转为 Shiny 控件标签列表
build_controls <- function(defs, ns = identity) { ... }

# 从 input 对象中收集所有 opt_* 前缀的值，返回命名列表
collect_options <- function(input) { ... }
```

`build_controls` 按 `type` 分支：
- `slider`   → `sliderInput("opt_{id}", ...)`
- `checkbox`  → `checkboxInput("opt_{id}", ...)`
- `select`   → `selectInput("opt_{id}", ...)`
- `color`    → `colourpicker::colourInput("opt_{id}", ...)`（需安装 colourpicker）
- `numeric`  → `numericInput("opt_{id}", ...)`
- `text`     → `textInput("opt_{id}", ...)`

**涉及文件：** `R/ui_helpers.R`（新建），`global.R`（source 新文件）
**验收：** 单独 source 后无报错；传入示例 def 能生成正确控件

---

### 1.3 为全部 20 个图表添加 `options_def`

按图表类型逐一设计，优先级从高到低：

| 图表 | 关键新增参数 |
|------|-------------|
| scatter（散点图）| 点大小、透明度、趋势线开关+方法、置信椭圆、抖动 |
| bar（柱状图）| 方向（横/竖）、柱宽、显示数值标签、堆叠/并列 |
| line（折线图）| 线宽、点大小、显示点开关、线型、平滑开关 |
| boxplot（箱线图）| 显示原始点、notch 开关、箱宽 |
| violin（小提琴图）| 内嵌箱线图开关、trim、scale 方式 |
| histogram（直方图）| 分箱数、显示密度曲线、填充透明度 |
| heatmap（热图）| 聚类开关（行/列）、显示数值、色阶选择 |
| pie（饼图）| 标签类型（百分比/数量/名称）、甜甜圈内径 |
| bubble（气泡图）| 最小/最大气泡尺寸、显示标签开关 |
| density（密度图）| 带宽、透明度、显示地毯图 |
| area（面积图）| 透明度、显示点开关 |
| lollipop（棒棒糖图）| 点大小、水平/垂直方向 |
| correlation（相关图）| 方法（pearson/spearman）、显示数值、显著性标记 |
| ridgeline（脊线图）| 带宽、填充透明度、重叠比例 |
| stacked_area（堆叠面积）| 透明度、显示点 |
| radar（雷达图）| 透明度、轴范围（自动/手动）、填充开关 |
| treemap（树图）| 边框宽度、标签大小 |
| circos（弦图）| 透明度、扇区间距、起始角度、链接排序 |
| dna_single（单序列）| 每行碱基数、配色方案 |
| dna_many（多序列）| 配色方案 |
| dna_methylation（甲基化）| 低值颜色、高值颜色 |

**涉及文件：** `R/chart_registry.R`
**验收：** 每个 CHARTS 条目都有 `options_def` 字段，共 20 个图均完成

---

### 1.4 更新 `app.R` — 动态渲染控件面板

将右侧面板中的静态控件区替换为 `renderUI`：

```r
output$chart_options_ui <- renderUI({
  chart <- CHARTS[[input$chart_type_select]]
  defs  <- chart$options_def %||% list()

  basic_defs <- Filter(function(d) (d$group %||% "basic") == "basic",  defs)
  adv_defs   <- Filter(function(d) (d$group %||% "basic") == "advanced", defs)

  tagList(
    # 公共控件（调色板、主题、标题等）保留不变
    build_controls(basic_defs),
    if (length(adv_defs) > 0)
      bslib::accordion(
        open = FALSE,
        bslib::accordion_panel("⚙️ 高级设置", build_controls(adv_defs))
      )
  )
})
```

在「生成图表」按钮的 `observeEvent` 里替换 options 收集逻辑：

```r
options <- c(
  list(
    palette = input$palette,
    theme   = input$theme,
    title   = input$chart_title,
    x_label = input$x_label,
    y_label = input$y_label
  ),
  collect_options(input)   # 自动收集所有 opt_* 输入
)
```

**涉及文件：** `app.R`
**验收：** 切换图表类型时，选项面板实时变化；生成图表时 options 包含动态参数

---

### 1.5 更新各 `plot_xxx()` 函数使用细粒度参数

以 `plot_scatter` 为例：

```r
plot_scatter <- function(data, options) {
  pt_size  <- as.numeric(options$point_size %||% 3)
  pt_alpha <- as.numeric(options$alpha      %||% 0.8)

  p <- ggplot2::ggplot(data, ...) +
    ggplot2::geom_point(size = pt_size, alpha = pt_alpha)

  if (isTRUE(options$show_smooth)) {
    p <- p + ggplot2::geom_smooth(method = options$smooth_method %||% "loess")
  }
  if (isTRUE(options$ellipse)) {
    p <- p + ggplot2::stat_ellipse()
  }
  apply_theme(p, options)
}
```

全部 20 个 plot 函数均需对应更新。

**涉及文件：** `R/plot_generator.R`
**验收：** 调节控件后点击「生成图表」，图表随参数变化

---

## 阶段二：R 代码生成面板

> 依赖：阶段一完成（options 体系稳定后才能生成准确代码）

### 2.1 为每个图表添加 `code_template` 函数

在 `chart_registry.R` 每个图表定义里加入：

```r
code_template = function(options, data_name = "data") {
  glue::glue('
library(ggplot2)

# 您的数据需包含列：x, y, group
ggplot({data_name}, aes(x = x, y = y, color = group)) +
  geom_point(size = {options$point_size %||% 3},
             alpha = {options$alpha %||% 0.8}) +
  scale_color_manual(values = c(...)) +
  theme_minimal()
  ')
}
```

**涉及文件：** `R/chart_registry.R`
**验收：** 调用 `CHARTS[["scatter"]]$code_template(list(point_size=4))` 返回合法 R 代码字符串

---

### 2.2 在 UI 新增「R 代码」标签页

在图表区域右侧（或下方）的 tabset 里加第三个 Tab：

```r
nav_panel("{ } R 代码",
  div(style = "position:relative",
    verbatimTextOutput("r_code_output"),        # 等宽字体代码块
    actionButton("copy_code_btn", "📋 复制",    # 右上角悬浮复制按钮
                 style = "position:absolute; top:8px; right:8px;")
  )
)
```

Server 端：

```r
output$r_code_output <- renderText({
  req(input$chart_type_select)
  chart <- CHARTS[[input$chart_type_select]]
  req(chart$code_template)
  chart$code_template(collect_options(input))
})
```

复制按钮用 `shinyjs::runjs` 或自定义 JS 实现 clipboard 写入。

**涉及文件：** `app.R`
**验收：** 切换图表并调节参数后，代码面板实时更新且内容准确

---

### 2.3 安装 `colourpicker` 包（color 类型控件依赖）

```r
install.packages("colourpicker")
```

在 `global.R` 加载，为 heatmap、circos 等提供颜色选择器。

**涉及文件：** `global.R`
**验收：** `library(colourpicker)` 无报错

---

## 阶段三：条件显示控件（show_when）

> 依赖：阶段一完成。此阶段让控件面板更简洁，减少无关噪音。

### 3.1 解析 `show_when` 并注入 JS 逻辑

在 `build_controls()` 里，对每个有 `show_when` 的控件包裹一层 `div`，并生成对应的 Shiny observe：

```r
# show_when = "show_smooth==TRUE"
# 解析为：监听 opt_show_smooth，若为 TRUE 则显示该控件 div，否则隐藏

shinyjs::hidden(
  div(id = paste0("wrap_opt_", d$id),
    # 控件本体
  )
)
```

Server 端注册观察者（对每个 show_when 控件动态生成）：

```r
observe({
  dep_val <- input[[paste0("opt_", dep_id)]]
  if (isTRUE(dep_val)) shinyjs::show(paste0("wrap_opt_", d$id))
  else                  shinyjs::hide(paste0("wrap_opt_", d$id))
})
```

**涉及文件：** `R/ui_helpers.R`，`app.R`（加载 shinyjs），`global.R`
**验收：** scatter 里勾选「显示趋势线」后，「趋势线方法」下拉框才出现

---

### 3.2 为所有图补充 `show_when` 关系

梳理哪些参数存在依赖关系，在 `chart_registry.R` 的 `options_def` 里补充 `show_when` 字段：

| 控件 | 依赖于 |
|------|--------|
| smooth_method（趋势线方法）| show_smooth == TRUE |
| donut_ratio（甜甜圈内径）| pie_style == "donut" |
| axis_min / axis_max（雷达轴范围）| axis_manual == TRUE |
| cluster_method（聚类方法）| cluster_rows 或 cluster_cols == TRUE |
| jitter_width（抖动宽度）| show_jitter == TRUE |

**涉及文件：** `R/chart_registry.R`
**验收：** 上述所有条件控件均能正确联动显示/隐藏

---

## 阶段四：配置预设保存与加载

> 依赖：阶段一、三完成。

### 4.1 设计预设存储格式

每条预设保存为 JSON，存入 `presets/` 目录（按图表 id 分文件）：

```json
{
  "name": "Nature 发表风格",
  "chart_id": "scatter",
  "created_at": "2026-03-26",
  "options": {
    "palette": "商务蓝",
    "theme": "简洁白",
    "point_size": 2.5,
    "alpha": 0.75,
    "show_smooth": true,
    "smooth_method": "lm",
    "ellipse": true
  }
}
```

**涉及文件：** 新建 `presets/` 目录，新建 `R/preset_manager.R`
**验收：** 格式文档确定，`save_preset()` 和 `load_presets()` 函数签名设计完毕

---

### 4.2 实现 `R/preset_manager.R`

```r
# 保存当前 options 为命名预设
save_preset <- function(chart_id, name, options) {
  dir.create("presets", showWarnings = FALSE)
  path <- file.path("presets", paste0(chart_id, ".json"))
  existing <- if (file.exists(path)) jsonlite::read_json(path) else list()
  existing[[name]] <- list(name=name, chart_id=chart_id,
                            created_at=Sys.Date(), options=options)
  jsonlite::write_json(existing, path, pretty=TRUE, auto_unbox=TRUE)
}

# 读取某图表的所有预设
load_presets <- function(chart_id) {
  path <- file.path("presets", paste0(chart_id, ".json"))
  if (!file.exists(path)) return(list())
  jsonlite::read_json(path, simplifyVector=FALSE)
}

# 删除预设
delete_preset <- function(chart_id, name) { ... }
```

**涉及文件：** `R/preset_manager.R`（新建），`global.R`（source）
**验收：** 单测通过：保存→读取→内容一致；删除后读取为空

---

### 4.3 在 UI 添加预设面板

在选项面板顶部加预设操作区：

```
[选择预设 ▼]  [加载]  |  [预设名称输入框]  [保存当前配置]  [删除]
```

```r
fluidRow(
  column(5, selectInput("preset_select", NULL,
                        choices = c("-- 选择预设 --"), width="100%")),
  column(2, actionButton("load_preset_btn",   "加载", class="btn-sm btn-outline-primary")),
  column(3, textInput("preset_name", NULL, placeholder="预设名称")),
  column(2, actionButton("save_preset_btn",   "保存", class="btn-sm btn-success"))
)
```

Server 端响应：
- 切换图表时刷新 `preset_select` 的 choices
- 点「保存」→ `save_preset()`，刷新下拉列表
- 点「加载」→ 读取 options，`updateSliderInput` / `updateSelectInput` 等批量更新控件

**涉及文件：** `app.R`，`R/preset_manager.R`
**验收：** 保存一个预设 → 重新打开 App → 加载该预设 → 控件恢复到保存时状态

---

## 依赖关系总览

```
阶段 1.1 设计 schema
    ↓
阶段 1.2 build_controls()      阶段 2.3 安装 colourpicker
    ↓                                  ↓（颜色控件依赖）
阶段 1.3 给 20 图写 options_def ←──────┘
    ↓
阶段 1.4 app.R 动态面板
    ↓
阶段 1.5 plot_xxx() 使用新参数
    ↓                    ↓
阶段 2.1 code_template   阶段 3.1 show_when JS逻辑
    ↓                         ↓
阶段 2.2 代码面板 UI      阶段 3.2 补充所有 show_when
                               ↓
                          阶段 4.1 预设格式设计
                               ↓
                          阶段 4.2 preset_manager.R
                               ↓
                          阶段 4.3 预设 UI
```

---

## 任务清单（按实施顺序）

### Phase 1 — options_def 注册制

- [ ] **1.1** 在 ROADMAP.md 中确认 options_def 字段规范（本文档）
- [ ] **1.2** 新建 `R/ui_helpers.R`，实现 `build_controls()` 和 `collect_options()`
- [ ] **1.3** 安装 `colourpicker`，更新 `global.R`
- [ ] **1.4** 为 scatter/bar/line/boxplot/violin 添加 `options_def`（第一批，高频图）
- [ ] **1.5** 为其余 15 个图表添加 `options_def`（第二批）
- [ ] **1.6** 更新 `app.R` 替换静态控件为 `renderUI` + `collect_options`
- [ ] **1.7** 更新 `plot_scatter` / `plot_bar` / `plot_line` 使用细粒度参数（第一批）
- [ ] **1.8** 更新其余 17 个 plot 函数（第二批）
- [ ] **1.9** 端到端测试：20 个图表，调节控件后生成图表符合预期

### Phase 2 — R 代码生成

- [ ] **2.1** 为 scatter/bar/line 添加 `code_template`（第一批验证可行性）
- [ ] **2.2** 在 `app.R` 新增「R 代码」Tab + `renderText` + 复制按钮
- [ ] **2.3** 为其余 17 个图表补充 `code_template`
- [ ] **2.4** 测试：每种图表代码可直接在 RStudio 运行出图

### Phase 3 — 条件控件

- [ ] **3.1** 安装 `shinyjs`，在 `ui_helpers.R` 实现 `show_when` 解析
- [ ] **3.2** 在 `app.R` 注册条件观察者（`shinyjs::show/hide`）
- [ ] **3.3** 为所有有依赖关系的控件补充 `show_when` 字段

### Phase 4 — 预设系统

- [ ] **4.1** 新建 `R/preset_manager.R`，实现 `save/load/delete_preset`
- [ ] **4.2** 在 `app.R` 添加预设选择/保存/删除 UI
- [ ] **4.3** Server 端实现批量 `update*Input` 恢复预设
- [ ] **4.4** 测试：跨会话持久化（关闭重开 App 后预设仍在）

---

## 里程碑

| 完成阶段 | 用户能做到的事 |
|----------|---------------|
| Phase 1 完成 | 每张图有专属控件面板，参数实时影响图表 |
| Phase 2 完成 | 一键看到当前设置对应的 R 代码，可复制到 RStudio |
| Phase 3 完成 | 界面干净，无关控件自动隐藏 |
| Phase 4 完成 | 好的配置存为预设，下次直接加载 |

---

*最后更新：2026-03-26*
