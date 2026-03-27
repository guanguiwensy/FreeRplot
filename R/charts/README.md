# Charts Directory

This folder stores **one chart definition per file**.

## Structure

- `basic/` core charts
- `bar/` bar-family charts
- `distribution/` distribution charts
- `proportion/` proportion/composition charts
- `relationship/` relationship charts
- `flow/` flow charts
- `genomics/` DNA/genomics charts

## File Contract

Each `*.R` file must define exactly one object:

```r
chart_def <- list(
  id = "chart_id",
  name = "中文名",
  name_en = "English Name",
  category = "分类",
  plot_fn = function(data, options) { ... },
  description = "...",
  best_for = "...",
  columns = "...",
  sample_data = data.frame(...),
  options_def = list(...),
  code_template = function(options) { ... }
)
```

The loader in `R/chart_registry.R` recursively discovers these files and
builds `CHARTS`/`CHART_IDS`.

## Notes

- Keep `plot_fn` self-contained (no dependency on `plot_xxx` globals).
- Shared helpers should come from `R/plot_core.R`.
