# 柱图系统重设计 TODO LIST
> 基于产品设计建议，将现有单一「柱状图」升级为「柱图系统」
> 核心思路：先选**数据模式** → 再选**布局模式** → 最后才是**样式参数**

---

## 总体原则

| 原则 | 说明 |
|------|------|
| 系统化而非参数化 | 柱图不是一个图，是 12 种模式的集合 |
| 三层递进 | 数据模式 → 布局模式 → 样式/高级 |
| 智能约束 | 用 show_when 和服务端逻辑限制不合理的参数组合 |
| 先覆盖后美化 | 结构模式 > 信息增强 > 美化，严格按优先级 |

---

## Phase B1：拆分 12 种柱图子类型（核心架构）

> 目标：在 `chart_registry.R` 中为柱图家族注册独立的子类型，每个有自己的 id、sample_data、options_def、code_template

### B1-1：第一优先级（最常用，必须先做）

- [ ] **bar_count** — 计数柱状图
  - 数据：只需 x 列（自动 `geom_bar(stat="count")`）
  - 禁用 y 输入（show_when 约束）
  - sample_data：单列类别数据

- [ ] **bar_value** — 数值柱状图
  - 数据：x + y（使用 `geom_col()`）
  - 可选 fill 颜色映射
  - sample_data：category + value 两列

- [ ] **bar_grouped** — 分组并列柱状图
  - 数据：x + y + group
  - position = "dodge"
  - sample_data：category + value + group 三列

- [ ] **bar_stacked** — 堆叠柱状图
  - 数据：x + y + group
  - position = "stack"
  - 自动加数值标签（柱内居中）

- [ ] **bar_filled** — 百分比堆叠柱状图
  - 数据：x + y + group
  - position = "fill"，y 轴自动改为百分比格式
  - sample_data 同 stacked

### B1-2：第二优先级（高价值，科研 / 分析场景）

- [ ] **bar_horizontal** — 横向柱状图
  - 数据：category + value（可选 group）
  - coord_flip() 或 x/y 对调
  - 自动适配长标签（hjust 调整）

- [ ] **bar_sorted** — 排序柱状图（TopN / 排名）
  - 数据：category + value
  - 可选：升序 / 降序 / 不排序
  - 横向展示，适合富集分析、排名类数据

- [ ] **bar_diverging** — 发散柱状图（正负值）
  - 数据：category + value（含负值，如 log2FC）
  - 正值填蓝/红，负值填对立色
  - 0 基线参考线，自动开放发散参数

- [ ] **bar_errorbar** — 误差线柱状图（科研高频）
  - 数据：x + mean + sd/se/ci（或 ymin/ymax）
  - 支持从原始数据自动计算 SD/SE/95%CI
  - stat_summary 或手动传入误差列两种模式

- [ ] **bar_dotplot** — 柱状图叠加原始散点
  - 数据：x + y（每行一个原始观测值）
  - geom_col（均值）+ geom_jitter / geom_beeswarm
  - 比纯均值柱图信息量更大

### B1-3：第三优先级（进阶 / 复杂场景）

- [ ] **bar_facet** — 分面小多图柱状图
  - 数据：x + y + facet 变量（可选 group）
  - facet_wrap 或 facet_grid
  - 适合多维比较、超过 20 类时自动建议

- [ ] **bar_grouped_stacked** — 分组堆叠柱状图
  - 数据：x + y + group + subgroup
  - 外层 dodge + 内层 stack
  - 最复杂，放最后

---

## Phase B2：三层选择 UI 流程设计

> 目标：将「选图表类型」变成「三步引导式选择」

### B2-1：第一层 — 图形模式选择器

- [ ] 在柱图家族顶部加「模式选择条」（单选按钮组，非下拉框）
  ```
  [计数] [数值] [分组] [堆叠] [百分比] [横向] [排序] [发散] [误差线] [+散点] [分面] [分组堆叠]
  ```
- [ ] 点击模式后自动切换 sample_data 和 options_def
- [ ] 高亮当前选中，灰色显示暂未实现的类型

### B2-2：第二层 — 数据模式提示

- [ ] 每个子类型显示「当前需要的列：x / x+y / x+y+group / …」
- [ ] 缺失必须列时，生成按钮禁用并给出提示
- [ ] 「加载示例数据」按钮随模式自动切换对应 sample_data

### B2-3：第三层 — 参数面板（6 分组）

- [ ] 参数面板按 6 组展示（见 Phase B3），默认只展开前 2 组

---

## Phase B3：6 组参数面板 options_def 设计

> 每种柱图子类型的 options_def 都按 6 大组组织

### B3-1：数据映射组（group = "mapping"）

每个子类型都需要实现：

| 参数 | 类型 | 说明 |
|------|------|------|
| x_col | select | 从数据列名中选 x 变量 |
| y_col | select | 从数据列名中选 y 变量（计数模式隐藏）|
| group_col | select | 分组变量（无分组时隐藏 stack/dodge 选项）|
| facet_col | select | 分面变量（可选）|
| label_col | select | 标签列（可选）|
| error_low / error_high | select | 误差下限/上限列（误差线模式专属）|

- [ ] 实现列名动态下拉（从 `rv$current_data` 读列名）
- [ ] 计数模式下用 show_when 隐藏 y_col

### B3-2：排列布局组（group = "layout"）— 最核心

| 参数 | 类型 | 默认 |
|------|------|------|
| position | radio/select | 单柱/并列/堆叠/百分比/覆盖 |
| orientation | radio | 纵向/横向 |
| sort_order | select | 不排序/升序/降序 |
| bar_width | slider | 0.7 |
| group_gap | slider | 0.2（并列模式专属）|
| diverging_baseline | numeric | 0（发散模式专属）|

- [ ] position 用单选按钮（radioButtons），不用下拉
- [ ] group_gap 用 show_when = "position_dodge"
- [ ] diverging_baseline 用 show_when = "has_negative"

### B3-3：统计与汇总组（group = "stat"）

| 参数 | 类型 | 说明 |
|------|------|------|
| stat_fun | select | count / mean / median / sum / proportion |
| error_type | select | SD / SE / 95%CI / 自定义（误差线模式）|
| pct_base | select | 整体 / x 组内 / facet 内（百分比模式）|
| show_n | checkbox | 是否显示样本量 n |
| remove_na | checkbox | 是否去除 NA |

- [ ] stat_fun ≠ count 时才显示 y_col（show_when）
- [ ] error_type 只在误差线子类型中出现

### B3-4：标注与读数组（group = "label"）

| 参数 | 类型 | 说明 |
|------|------|------|
| show_label | checkbox | 显示数值标签开关 |
| label_content | select | y 值 / 百分比 / n / 自定义（show_when = show_label）|
| label_position | select | 柱顶 / 柱内居中 / 外侧（show_when = show_label）|
| label_format | select | 整数 / 1位小数 / 百分比 / 科学计数（show_when）|
| label_size | slider | 字体大小（show_when = show_label）|

### B3-5：视觉样式组（group = "style"）

| 参数 | 类型 | 说明 |
|------|------|------|
| fill_color | color | 单色模式下的填充色 |
| palette | select | 分组配色方案 |
| alpha | slider | 透明度 |
| border_color | color | 边框色（默认 NA）|
| border_width | slider | 边框粗细（show_when = border_enabled）|
| bar_radius | slider | 圆角（0 = 直角，高级设置）|

### B3-6：参考线与增强组（group = "advanced"）

| 参数 | 类型 | 说明 |
|------|------|------|
| show_refline | checkbox | 显示参考线 |
| refline_value | numeric | 参考线位置（show_when = show_refline）|
| refline_label | text | 参考线标签（show_when = show_refline）|
| top_n | numeric | 只显示 Top N 类别（0 = 全部显示）|
| flip_if_long | checkbox | 类别名过长时自动横向 |

---

## Phase B4：智能约束系统（Smart Restrictions）

> 用 show_when + 服务端验证实现「智能限制」，避免不合理组合

- [ ] **计数模式 → 禁用 y_col**
  - show_when 控制 y_col 只在 stat ≠ "count" 时显示

- [ ] **无 group 列 → 隐藏 stack/dodge/fill 参数**
  - 检测 group_col 是否为空，是则隐藏 position 的高级选项

- [ ] **类别数 > 20 → 弹提示建议横向或 TopN**
  ```r
  if (n_unique(data[[x_col]]) > 20) {
    showNotification("类别数超过 20，建议使用横向排序图或设置 Top N", ...)
  }
  ```

- [ ] **y 列有负值 → 自动解锁发散模式**
  - 检测到负值时，在通知中提示用户切换到「发散柱状图」

- [ ] **选择误差线模式但无误差列 → 引导选择计算方式**
  - 检测 error_low/error_high 是否为空
  - 若为空，显示「从原始数据计算」选项（SD / SE / 95%CI）

- [ ] **百分比堆叠 → 强制 y 轴 0-100% 格式**
  - 后端自动 `scale_y_continuous(labels = scales::percent)`

- [ ] **排序模式 → 禁止分组（因为分组后排序语义不清）**
  - 选择 bar_sorted 时，group_col 自动禁用

---

## Phase B5：代码模板（code_template）

每种子类型需要独立的 code_template，能生成可直接运行的 R 代码：

- [ ] bar_count — `ggplot(data, aes(x=x)) + geom_bar()`
- [ ] bar_value — `ggplot(data, aes(x=x, y=y)) + geom_col()`
- [ ] bar_grouped — `... + geom_col(position="dodge")`
- [ ] bar_stacked — `... + geom_col(position="stack")`
- [ ] bar_filled — `... + geom_col(position="fill") + scale_y_percent()`
- [ ] bar_horizontal — `... + coord_flip()`
- [ ] bar_sorted — `aes(x=reorder(x, y), ...)  + coord_flip()`
- [ ] bar_diverging — `aes(fill=y>0) + geom_col() + geom_hline(yintercept=0)`
- [ ] bar_errorbar — `geom_col() + geom_errorbar(aes(ymin, ymax))`
- [ ] bar_dotplot — `stat_summary() + geom_jitter()`
- [ ] bar_facet — `... + facet_wrap(~facet_col)`
- [ ] bar_grouped_stacked — 复合 position

---

## Phase B6：UI 入口整合

- [ ] 在图表库的「通用图表」分类中，将 bar 替换为「柱图」分类组
- [ ] 柱图家族在图表选择下拉里显示为分组：
  ```
  ── 柱图家族 ──
    计数柱状图
    数值柱状图
    分组柱状图
    堆叠柱状图
    百分比堆叠
    ── 进阶 ──
    横向 / 排序 / 发散 / 误差线 / +散点 / 分面 / 分组堆叠
  ```
- [ ] 「图表库」Tab 中柱图家族单独成区，配图标和一句话描述

---

## 实施顺序建议

```
B1（前5种）→ B3（这5种的 options_def）→ B5（code_template）
     ↓
B4（智能约束）→ B2（UI 流程）→ B6（入口整合）
     ↓
B1（后7种）→ 循环 B3/B5/B4
```

## 时间估算

| Phase | 工作量 | 优先级 |
|-------|--------|--------|
| B1 前5种 | 中（每种约 30-50 行 plot 函数）| ⭐⭐⭐⭐⭐ |
| B3 前5种 options_def | 中（参数定义 + show_when）| ⭐⭐⭐⭐⭐ |
| B4 智能约束 | 小（observer + 服务端校验）| ⭐⭐⭐⭐ |
| B2 UI 三层流程 | 大（UI 结构改动较多）| ⭐⭐⭐ |
| B1 后7种 | 大 | ⭐⭐⭐ |
| B6 入口整合 | 小 | ⭐⭐ |
