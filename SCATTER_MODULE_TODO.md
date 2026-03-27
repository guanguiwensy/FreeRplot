# 散点图模块扩展 TODO

## 第一阶段（必须完成）
- [x] 新建散点家族模式文件（P1）
  - [x] `R/charts/scatter/scatter_basic.R`
  - [x] `R/charts/scatter/scatter_grouped.R`
  - [x] `R/charts/scatter/scatter_regression.R`
  - [x] `R/charts/scatter/scatter_jitter.R`
  - [x] `R/charts/scatter/scatter_bubble.R`

- [x] 更新图表菜单分组（新增“散点图家族”）
  - [x] `R/ui_helpers.R` 中加入散点家族分组与顺序

- [x] 新增散点场景模板机制
  - [x] 新建 `R/scatter_scene_presets.R`
  - [x] 在设置面板接入散点模板 UI 与应用逻辑
  - [x] `global.R` 增加散点模板 source 与家族 ID 解析

- [x] 首批内置模板（P1）
  - [x] `corr_basic`（基础相关性）
  - [x] `group_compare`（分组比较）
  - [x] `regression_ci`（回归+CI）
  - [x] `bubble_impact`（气泡影响力）
  - [x] `outlier_label`（离群点标注）

- [ ] 参数分组升级（数据映射/样式/拟合等更细粒度分组）
  - [ ] 现阶段仅支持 `basic/advanced`，下一步升级到多分组 UI

## 第二阶段（增强）
- [ ] 增加中高阶散点模式（P2）
  - [ ] `scatter_facet`
  - [ ] `scatter_label`
  - [ ] `scatter_path`
  - [ ] `scatter_density2d`
  - [ ] `scatter_hexbin`

- [ ] 接入散点智能建议规则
  - [ ] 点数过多建议 alpha
  - [ ] 超大规模建议 hexbin/density
  - [ ] 标签过多自动切换 TopN
  - [ ] 非数值 x/y 拦截并提示
  - [ ] 严重重叠建议 jitter
  - [ ] 映射冲突（size/color 同变量）提示

- [ ] 导出增强
  - [ ] 导出图像（PNG/SVG）
  - [ ] 导出当前映射配置

## 第三阶段（高级）
- [ ] 增加科研高级模式（P3）
  - [ ] `scatter_errorbar`
  - [ ] `scatter_paired`

- [ ] 统计增强
  - [ ] 离群检测与自动标注建议
  - [ ] 拟合方法自动推荐

- [ ] 交互增强
  - [ ] hover/tooltip 字段可配置
  - [ ] 高级布局与联动优化

## 工程与验证
- [ ] 元数据结构统一
  - [ ] 为散点家族定义统一 `mode + data_contract + options_def + smart_rules`
  - [ ] 保持与现有 `chart_def/options_def/show_when` 兼容

- [ ] 回归验证脚本
  - [ ] 新建 `test_scatter_family.R`
  - [ ] 覆盖全部散点模式 `generate_plot()` 冒烟测试
  - [ ] 覆盖典型模板一键应用测试
