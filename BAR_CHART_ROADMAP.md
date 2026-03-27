# 柱图系统（Bar Chart System）实现路线图

> 核心思想：把「柱状图」从一个参数面板升级成一个**柱图系统**。
> 先选数据模式 → 再选布局模式 → 最后才是样式参数。

---

## 一、架构设计：三层模型

```
第一层：图形模式（先选，不是参数）
  └─ 决定图表 ID（bar_count / bar_value / bar_grouped / ...）

第二层：数据模式（决定用户要填哪些字段）
  └─ 自动计数（只要 x）
  └─ 已汇总数值（x + y）
  └─ 分组比较（x + y + group）
  └─ 误差展示（x + y + error_low/error_high）

第三层：样式与高级控制（最后再展开，不能一上来全暴露）
  └─ 基础：颜色、方向、排序
  └─ 高级：柱宽、透明度、标签格式、图例等
```

---

## 二、12 种子类型总览

| # | ID | 中文名 | 数据模式 | ggplot2 核心 | 优先级 |
|---|----|----|----|----|---|
| 1 | `bar_count` | 计数柱状图 | 自动计数 | `geom_bar(stat="count")` | ⭐⭐⭐ P1 |
| 2 | `bar_value` | 数值柱状图 | 已汇总 | `geom_col()` | ⭐⭐⭐ P1 |
| 3 | `bar_grouped` | 分组柱状图 | 分组比较 | `position_dodge()` | ⭐⭐⭐ P1 |
| 4 | `bar_stacked` | 堆叠柱状图 | 分组比较 | `position_stack()` | ⭐⭐⭐ P1 |
| 5 | `bar_filled` | 百分比堆叠柱状图 | 分组比较 | `position_fill()` | ⭐⭐⭐ P1 |
| 6 | `bar_horizontal` | 横向排序柱状图 | 已汇总 | `geom_col() + coord_flip()` | ⭐⭐ P2 |
| 7 | `bar_sorted` | 排序柱状图 | 已汇总 | `reorder() + geom_col()` | ⭐⭐ P2 |
| 8 | `bar_diverging` | 发散柱状图（正负值）| 已汇总 | `geom_col() + 正负色` | ⭐⭐ P2 |
| 9 | `bar_errorbar` | 误差线柱状图 | 误差展示 | `geom_col() + geom_errorbar()` | ⭐⭐ P2 |
| 10 | `bar_dotplot` | 柱叠加散点 | 分组比较 | `geom_col() + geom_jitter()` | ⭐ P2 |
| 11 | `bar_facet` | 分面柱状图 | 分组比较 | `facet_wrap()` | ⭐ P2 |
| 12 | `bar_grouped_stacked` | 分组堆叠柱状图 | 多分组 | `position_stack() + facet` | ⭐ P2 |

---

## 三、6 组参数设计（每种图都参考此框架）

### Group 1：数据映射（核心）
- x（类别轴）
- y（数值轴）
- group / fill（分组变量）
- facet_col（分面变量，高级）
- label（标签列，高级）
- error_low / error_high（误差列，仅 bar_errorbar）

### Group 2：排列布局（重点）
- 布局模式：单柱 / 并列 / 堆叠 / 百分比堆叠 / 覆盖
- 方向：纵向 / 横向
- 排序：不排序 / 升序 / 降序
- 柱宽（bar_width）
- 组间距（dodge_width）
- 类别间距

### Group 3：统计与汇总（可选）
- 汇总函数：count / sum / mean / median
- 误差类型：SD / SE / 95% CI
- 百分比基准：全体 / 组内 / 分面内

### Group 4：标注与读数
- 显示数值标签（show_labels）
- 标签内容：y值 / 百分比 / n
- 标签位置：柱内居中 / 柱顶 / 柱外
- 标签格式：整数 / 小数1位 / 百分比

### Group 5：视觉样式
- 填充颜色 / 调色板
- 透明度（alpha）
- 边框颜色 / 边框粗细
- 图表主题

### Group 6：交互与导出
- 下载 PNG / SVG
- 导出 R 代码
- 保存预设

---

## 四、智能限制规则（Phase B3）

| 触发条件 | 限制行为 |
|---------|---------|
| 选择 `bar_count` | 禁用 y 字段输入，显示「自动计数」提示 |
| 无 group 列 | 隐藏 stack / dodge / fill 相关高级参数 |
| 类别数 > 15 | 弹出建议：切换横向或 TopN 截取 |
| y 存在负值 | 自动推荐切换到 `bar_diverging` |
| 选择 `bar_errorbar` | 显示误差列选择器 |
| `show_labels=FALSE` | 隐藏标签格式、位置等子选项 |

---

## 五、实现进度

### Phase B1：前5种核心柱图（最常用）
- [x] `bar_count`   — 计数柱状图
- [x] `bar_value`   — 数值柱状图
- [x] `bar_grouped` — 分组柱状图
- [x] `bar_stacked` — 堆叠柱状图
- [x] `bar_filled`  — 百分比堆叠柱状图

### Phase B2：后7种扩展柱图
- [ ] `bar_horizontal`     — 横向排序柱状图
- [ ] `bar_sorted`         — 排序柱状图（TopN）
- [ ] `bar_diverging`      — 发散柱状图（正负值）
- [ ] `bar_errorbar`       — 误差线柱状图
- [ ] `bar_dotplot`        — 柱叠加原始散点
- [ ] `bar_facet`          — 分面小多图柱状图
- [ ] `bar_grouped_stacked`— 分组堆叠柱状图

### Phase B3：智能限制系统
- [ ] `show_when` 联动（标签子选项）
- [ ] 数据模式感知（自动计数 vs 已汇总）
- [ ] 负值检测 → 推荐发散模式
- [ ] 类别过多警告

### Phase B4：场景预设模板
- [ ] 基础柱状图（科研风）
- [ ] 横向 TopN 排名图
- [ ] 均值 ± 误差线（科研对比）
- [ ] 组成结构分析（100% 堆叠）
- [ ] log2FC 正负变化图
- [ ] 富集分析 Top20

---

## 六、产品路线（总体节奏）

```
现在   → Phase B1: 5 种核心柱图，覆盖 80% 使用场景
近期   → Phase B2: 7 种扩展柱图，科研 / 分析场景全覆盖
中期   → Phase B3: 智能限制，提升易用性
远期   → Phase B4: 场景预设，从「参数面板」升级为「图形生成器」
```
