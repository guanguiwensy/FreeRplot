# 模块化重构规划

> 当前代码量：app.R 984行 / chart_registry.R 1703行 / plot_generator.R 1460行 / 合计 ~5000行
> 目标：每新增一种图表，只需新建/修改 **1 个文件**，不触碰核心框架

---

## 一、现状诊断

### 核心痛点

| 问题 | 现状 | 风险 |
|------|------|------|
| **中心化注册** | 所有33个图表挤在 `chart_registry.R` 一个文件 | 每次加图都要改这个大文件，冲突概率高 |
| **中心化绘图** | 所有33个 `plot_*()` 函数在 `plot_generator.R` | 同上，且函数间互相干扰 |
| **switch 分发** | `app.R` 里有手写 switch 分配到各 plot 函数 | 每加图都要改 app.R，容易漏 |
| **app.R 臃肿** | UI + Server 混在 984 行一个文件 | 找代码困难，逻辑耦合，调试代价高 |
| **全局副作用** | global.R source 顺序敏感（见 BAR_FAMILY_IDS 问题） | 顺序错误导致神秘报错 |

### 当前文件依赖图

```
global.R
  ├── ui_helpers.R        (CHART_MENU_GROUPS)
  ├── chart_registry.R    (CHARTS) ← 依赖 ui_helpers.R 里的 %||%
  ├── plot_generator.R    (generate_plot) ← 依赖 chart_registry.R 里的 CHARTS
  ├── bar_scene_presets.R ← 依赖 ui_helpers.R 里的 CHART_MENU_GROUPS
  ├── kimi_api.R
  └── preset_manager.R

app.R
  ├── source("global.R")
  ├── UI  (page_fillable → 嵌套标签页 → uiOutput × 5)
  └── Server (29 个 observe/render，手写 switch 分发绘图)
```

---

## 二、目标架构

### 核心原则

1. **自注册（Self-Registering）**：每个图表是独立文件，框架自动发现并合并
2. **零 switch**：分发完全靠 `CHARTS[[id]]$plot_fn(data, opts)` 动态调用
3. **UI / Server 分离**：`app.R` 只剩入口，逻辑拆进 Shiny modules
4. **单一修改点**：增删一个图表只动它自己的文件

### 目标目录结构

```
r-plot-ai/
│
├── app.R              ← 极简入口（只调用 shinyApp(ui, server)，<50行）
├── global.R           ← 只做包加载 + source("R/core/loader.R")
│
├── R/
│   ├── core/                      ← 框架层（稳定，几乎不改）
│   │   ├── loader.R               # 自动发现并合并所有图表模块
│   │   ├── ui_helpers.R           # build_controls / collect_options 等
│   │   ├── preset_manager.R       # 预设存取
│   │   ├── kimi_api.R             # AI 接口
│   │   └── utils.R                # %||% 等通用工具
│   │
│   ├── charts/                    ← 图表层（高频变动，每图一文件）
│   │   ├── basic/
│   │   │   ├── scatter.R          # 定义 + plot_fn，约80行
│   │   │   ├── line.R
│   │   │   ├── area.R
│   │   │   └── ...
│   │   ├── bar/
│   │   │   ├── bar_value.R
│   │   │   ├── bar_grouped.R
│   │   │   ├── bar_stacked.R
│   │   │   └── ...（13个bar文件）
│   │   ├── distribution/
│   │   │   ├── boxplot.R
│   │   │   ├── violin.R
│   │   │   └── ...
│   │   ├── proportion/
│   │   │   ├── pie.R
│   │   │   └── treemap.R
│   │   ├── relationship/
│   │   │   ├── heatmap.R
│   │   │   ├── correlation.R
│   │   │   └── radar.R
│   │   ├── flow/
│   │   │   └── circos.R
│   │   └── genomics/
│   │       ├── dna_single.R
│   │       ├── dna_many.R
│   │       └── dna_methylation.R
│   │
│   └── modules/                   ← Shiny 模块层（UI/Server分块）
│       ├── mod_data.R             # 数据面板 module
│       ├── mod_settings.R         # 设置面板 module
│       ├── mod_plot.R             # 图表预览 module
│       ├── mod_code.R             # R代码面板 module
│       ├── mod_gallery.R          # 图表库 module
│       └── mod_ai_chat.R          # AI对话 module
│
└── www/
    └── styles.css
```

### 图表文件格式（单文件自包含）

每个图表文件 export 一个 `chart_def` 列表，框架自动 source 并注册：

```r
# R/charts/bar/bar_value.R

chart_def <- list(
  id       = "bar_value",
  name     = "数值柱状图",
  name_en  = "Bar Chart (Value)",
  category = "bar",          # 用于 CHART_MENU_GROUPS 分组

  sample_data = data.frame(
    城市 = c("北京","上海","广州","深圳","成都"),
    GDP  = c(42.5, 38.1, 25.7, 28.2, 20.1)
  ),

  options_def = list(
    list(id="fill_color",  label="填充颜色", type="color",    group="basic",    default="#45B7D1"),
    list(id="show_labels", label="显示标签", type="checkbox", group="basic",    default=FALSE),
    list(id="label_size",  label="标签字号", type="slider",   group="basic",
         min=2, max=7, step=0.5, default=3.5, show_when="show_labels"),
    list(id="bar_width",   label="柱宽",     type="slider",   group="advanced",
         min=0.2, max=1.0, step=0.05, default=0.7)
  ),

  # plot_fn 直接内联，不再需要 plot_generator.R
  plot_fn = function(data, options = list()) {
    # ... 绘图代码 ...
  },

  code_template = function(options) {
    # ... 返回 R 代码字符串 ...
  }
)
```

### 自注册加载器（loader.R）

```r
# R/core/loader.R

load_charts <- function(charts_dir = "R/charts") {
  files <- list.files(charts_dir, pattern = "\\.R$",
                      full.names = TRUE, recursive = TRUE)
  charts <- list()
  for (f in files) {
    env <- new.env(parent = globalenv())
    source(f, local = env)
    if (exists("chart_def", envir = env)) {
      def <- env$chart_def
      charts[[def$id]] <- def
    }
  }
  charts
}

CHARTS <- load_charts()
```

### 零 switch 分发器

```r
# generate_plot 变成两行
generate_plot <- function(chart_id, data, options) {
  fn <- CHARTS[[chart_id]]$plot_fn
  if (is.null(fn)) stop("未注册的图表类型: ", chart_id)
  fn(data, options)
}
```

---

## 三、迁移路径（渐进式，不中断功能）

### 阶段 0：准备工作（不改任何现有功能）
- [ ] 建立 `R/charts/` 目录结构
- [ ] 写 `R/core/loader.R`（自注册器）
- [ ] 写测试：`loader.R` 加载空目录不报错

### 阶段 1：消灭 switch（最高优先级，风险低）
- [ ] 在 `chart_registry.R` 每个 chart 定义里加 `plot_fn = plot_xxx` 字段
- [ ] `generate_plot()` 改为动态调用 `CHARTS[[id]]$plot_fn`
- [ ] 删除 app.R 里的 `switch()` 语句
- [ ] 验证：所有现有33个图表仍可正常生成

### 阶段 2：拆分 app.R（中优先级，风险中）
- [ ] 新建 `R/modules/mod_plot.R`（renderPlot + download）
- [ ] 新建 `R/modules/mod_data.R`（数据表 + 上传）
- [ ] 新建 `R/modules/mod_settings.R`（设置面板 + 场景模板）
- [ ] 新建 `R/modules/mod_ai_chat.R`（Kimi 对话）
- [ ] 新建 `ui.R` 和 `server.R`，把 app.R 内容拆进去
- [ ] 验证：功能等价

### 阶段 3：拆分 chart_registry.R（较高优先级，风险低）
- [ ] 以图表家族为单位，把注册定义迁移到 `R/charts/*/` 文件里
- [ ] 每次迁移一个家族，迁移后运行全量验证
- [ ] 迁完后删除 chart_registry.R

### 阶段 4：拆分 plot_generator.R（与阶段3并行）
- [ ] 把 `plot_xxx()` 函数内联到对应的 chart 文件里
- [ ] 迁完后删除 plot_generator.R

### 阶段 5：Shiny 模块化（低优先级，风险最高，最后做）
- [ ] 把各 module 改造为标准 `moduleUI` / `moduleServer`
- [ ] 主 server 变成模块组合器

---

## 四、迁移优先级与理由

| 优先级 | 任务 | 理由 |
|--------|------|------|
| ⭐⭐⭐ | 阶段1：消灭 switch | 改动最小、收益最大；每加图不需动 app.R |
| ⭐⭐⭐ | 阶段3：拆分 chart_registry.R | 文件太大，已经很难找代码 |
| ⭐⭐ | 阶段2：拆分 app.R | UI/Server 分离，减少调试成本 |
| ⭐⭐ | 阶段4：plot_fn 内联 | 和阶段3并行做，一个图表一个文件 |
| ⭐ | 阶段5：Shiny 模块 | 目前规模还能接受，优先级最低 |

---

## 五、新增一个图表的流程对比

### 现在（改3个文件）
1. `chart_registry.R` → 添加 chart 定义（options_def + code_template）
2. `plot_generator.R` → 添加 plot_xxx() 函数
3. `app.R` → 在 switch 语句里加一个 case

### 重构后（改1个文件）
1. 新建 `R/charts/xxx/my_chart.R` → 写 `chart_def` 列表（包含 plot_fn）
2. loader.R 自动发现并注册，无需改其他任何文件

---

## 六、建议从阶段1开始

阶段1改动范围：
- `chart_registry.R`：每个 chart 加一行 `plot_fn = plot_xxx`（33个）
- `plot_generator.R`：`generate_plot()` 改为2行
- `app.R`：删除 switch 块（约30行）
- **0个新文件，0个功能变化，风险极低**

完成后立刻受益：新加图表只需改 chart_registry.R + plot_generator.R，不动 app.R。
