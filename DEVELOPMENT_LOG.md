# R Intelligent Chart Assistant — Development Log

> This file consolidates all historical TODO and planning documents into a
> single chronological record.  It serves as a learning reference for new
> contributors, showing the architectural decisions, implementation order, and
> current state of each feature area.
>
> **Status legend:**  ✅ Completed  |  🔄 Partially done  |  ⏳ Not started

---

## Table of Contents

1. [Architecture Evolution](#1-architecture-evolution)
2. [Core Options System (Phase 1–4)](#2-core-options-system-phase-1-4)
3. [Plot Settings Enhancement](#3-plot-settings-enhancement)
4. [Bar Chart System (Phase B)](#4-bar-chart-system-phase-b)
5. [Scatter Chart Module](#5-scatter-chart-module)
6. [AI V1 Upgrade](#6-ai-v1-upgrade)
7. [AI Flex Intent Engine (Phase 1–7)](#7-ai-flex-intent-engine-phase-1-7)

---

## 1. Architecture Evolution

> **Source:** `MODULAR_PLAN.md`
> **Goal:** Go from a monolithic ~5000-line single-file app to a self-registering
> per-chart modular system where adding a new chart only touches **one file**.

### Problem (starting state)

| Issue | Detail |
|-------|--------|
| Centralised registry | All 33 charts crammed into `chart_registry.R` |
| Centralised plot fns | All `plot_*()` in `plot_generator.R` |
| Hard-coded switch | `app.R` had a manual `switch()` to dispatch chart types |
| Monolithic `app.R` | UI + Server mixed in 984 lines |
| Global side-effects | `global.R` source-order sensitive |

### Target architecture (achieved)

```
r-plot-ai/
  app.R          — shinyApp() entry only
  global.R       — packages + source order
  ui.R           — layout assembler (calls R/ui/panel_*.R)
  server.R       — rv creation + init_mod_*() calls
  R/
    utils/logger.R           — log_*, safe_run
    config_manager.R         — LLM_PROVIDERS, load/save_api_config
    ui_helpers.R             — CHART_MENU_GROUPS, build_controls, collect_options
    core/intent_engine.R     — 3-layer NLP intent engine
    chart_registry.R         — auto-discovers R/charts/**/*.R → CHARTS
    plot_core.R              — palettes, themes, generate_plot dispatcher
    kimi_api.R               — chat_with_llm (all providers)
    preset_manager.R         — JSON preset storage
    bar_scene_presets.R
    scatter_scene_presets.R
    ui/                      — panel_chat/plot/data/settings/code/gallery.R
    modules/                 — mod_ai_chat/data/plot/settings.R
    charts/
      basic/ bar/ scatter/ distribution/ proportion/ relationship/ flow/ genomics/
```

### Migration path (all completed ✅)

- ✅ **Stage 0** — Create `R/charts/` directory structure + auto-loader
- ✅ **Stage 1** — Eliminate `switch()`: each chart gets `plot_fn` field, dispatcher is 2 lines
- ✅ **Stage 2** — Split `app.R` into `ui.R` / `server.R` / `R/modules/mod_*.R`
- ✅ **Stage 3** — Migrate all chart definitions from `chart_registry.R` to individual files
- ✅ **Stage 4** — Inline `plot_*()` functions into their chart files (deleted `plot_generator.R`)
- ✅ **Stage 5** — UI sub-panels split into `R/ui/panel_*.R` files

### Adding a new chart: then vs now

**Before (3 files):**
1. `chart_registry.R` — add chart definition
2. `plot_generator.R` — add `plot_xxx()` function
3. `app.R` — add a case to the switch statement

**Now (1 file):**
1. Create `R/charts/{family}/{id}.R` with a `chart_def` list — loader auto-discovers it

---

## 2. Core Options System (Phase 1–4)

> **Source:** `ROADMAP.md`
> **Goal:** Upgrade every chart from fixed parameters to a fully configurable
> system with dynamic control panels, R code generation, and saveable presets.

### The problem this solved

```
Before:  user → fixed controls (palette/theme/title/axes)
         → hardcoded options{} dict
         → generate_plot()
         → plot_xxx()  ← internal params unreachable

After:   each chart declares its own options_def
         → build_controls() auto-generates the right widgets
         → collect_options() reads them all as a named list
         → plot_fn uses fine-grained params
         → code_template generates matching R code
```

### Phase 1 — options_def registry ✅

- ✅ **1.1** Define `options_def` field schema (type/default/group/show_when)
- ✅ **1.2** Create `R/ui_helpers.R` with `build_controls()` and `collect_options()`
- ✅ **1.3** Add `options_def` to all 45 chart types
- ✅ **1.4** Replace static controls in UI with `renderUI` driven by `options_def`
- ✅ **1.5** All `plot_fn` implementations consume fine-grained options

**options_def field reference:**
```r
list(
  id        = "alpha",
  label     = "Opacity",
  type      = "slider",        # slider | checkbox | select | color | numeric | text
  group     = "basic",         # "basic" (always shown) | "advanced" (in accordion)
  default   = 0.8,
  min = 0.1, max = 1, step = 0.05,        # slider only
  choices   = c("lm", "loess"),           # select only
  show_when = "show_smooth==TRUE"         # conditional visibility
)
```

### Phase 2 — R code generation ✅

- ✅ Every chart has a `code_template(options)` or `code_template(options, data)` function
- ✅ "R Code" tab in UI shows live reproducible code, updates on every parameter change
- ✅ Copy-to-clipboard button

### Phase 3 — Conditional controls (show_when) ✅

- ✅ Controls with `show_when` are wrapped in `shinyjs::hidden()` by `build_controls()`
- ✅ `build_show_when_map()` builds the trigger→target map
- ✅ `apply_show_when()` called from chart-switch and checkbox observers
- ✅ All dependent controls across all charts wired correctly

### Phase 4 — Preset system ✅

- ✅ `R/preset_manager.R` — `save/load/list/delete_preset()`, JSON storage in `presets/`
- ✅ Preset UI row in Settings tab (select + Load / Save / Delete)
- ✅ `restore_preset_inputs()` bulk-updates all widgets
- ✅ Cross-session persistence (close and reopen — presets survive)

---

## 3. Plot Settings Enhancement

> **Source:** `PLOT_SETTINGS_ENHANCEMENT_TODO.md`
> **Status:** ✅ All completed

### What was added

- ✅ Configurable export dimensions: `plot_width_in` / `plot_height_in` / `plot_dpi`
- ✅ Configurable axis ranges: `x/y_range_mode`, `x/y_min`, `x/y_max`
- ✅ PDF download handler
- ✅ `active_data()` reactive — single source of truth for live table data
- ✅ `build_plot_options()` reactive — single collector for all input widgets
- ✅ `apply_axis_limits()` in `plot_core.R`
- ✅ PNG/PDF download uses user-specified width/height/DPI
- ✅ circos chart supports both PNG and PDF device export
- ✅ R code output syncs with both data changes and settings changes
- ✅ `data_to_r_code()` helper — truncates at 200 rows with a comment

### Files changed
`ui.R`, `R/modules/mod_plot.R`, `R/modules/mod_settings.R`,
`R/plot_core.R`, `R/preset_manager.R`

---

## 4. Bar Chart System (Phase B)

> **Source:** `BAR_CHART_SYSTEM.md`, `BAR_CHART_ROADMAP.md`
> **Goal:** Upgrade "bar chart" from one chart type into a 12-subtype system.
> Core idea: choose **data mode** → **layout mode** → **style params**

### Design: 3-layer model

```
Layer 1: Chart mode   → selects the chart ID (bar_count / bar_value / ...)
Layer 2: Data mode    → determines which columns are needed
          auto-count (x only) | summarised (x+y) | grouped (x+y+group) | error bars
Layer 3: Style & advanced controls  (exposed last, not first)
```

### 12 subtypes

| ID | Name | Core ggplot2 | Priority |
|----|------|--------------|---------|
| `bar_count` | Count bar | `geom_bar(stat="count")` | P1 |
| `bar_value` | Value bar | `geom_col()` | P1 |
| `bar_grouped` | Grouped bar | `position_dodge()` | P1 |
| `bar_stacked` | Stacked bar | `position_stack()` | P1 |
| `bar_filled` | 100% stacked | `position_fill()` | P1 |
| `bar_horizontal` | Horizontal bar | `coord_flip()` | P2 |
| `bar_sorted` | Sorted / TopN | `reorder()` | P2 |
| `bar_diverging` | Diverging (±) | `geom_col() + hline(0)` | P2 |
| `bar_errorbar` | Error bar | `geom_errorbar()` | P2 |
| `bar_dotplot` | Bar + raw dots | `stat_summary() + geom_jitter()` | P2 |
| `bar_facet` | Faceted bar | `facet_wrap()` | P2 |
| `bar_grouped_stacked` | Grouped stacked | `position_stack() + facet` | P2 |

### Phase B1 — Chart implementations

- ✅ `bar_count`
- ✅ `bar_value`
- ✅ `bar_grouped`
- ✅ `bar_stacked`
- ✅ `bar_filled`
- ✅ `bar_horizontal`
- ✅ `bar_sorted`
- ✅ `bar_diverging`
- ✅ `bar_errorbar`
- ✅ `bar_dotplot`
- ✅ `bar_facet`
- ✅ `bar_grouped_stacked`

### Phase B2 — show_when for label sub-controls ✅

Controls under `show_labels` (label content / position / format / size) only
appear when `show_labels == TRUE`.

### Phase B3 — Smart notifications ✅

| Trigger | Behaviour |
|---------|-----------|
| `bar_count` selected | Info notification: only one category column needed |
| `bar_errorbar` selected | Info notification: expects mean + sd/se columns |
| y column has negative values | (in roadmap — not yet implemented) |
| Category count > 20 | (in roadmap — not yet implemented) |

### Phase B4 — Scene preset templates 🔄

- ✅ Infrastructure: `R/bar_scene_presets.R`, scene card UI, apply logic
- ✅ Templates implemented: Basic comparison, Horizontal TopN, Grouped, Stacked, 100% Stacked
- ⏳ Additional templates: Scientific error bar, log2FC diverging, Enrichment analysis Top20

### 6-group parameter design (reference for future bar options_def work)

| Group | Key params |
|-------|-----------|
| mapping | x_col, y_col, group_col, facet_col, error_low/high |
| layout | position, orientation, sort_order, bar_width, dodge_width |
| stat | stat_fun, error_type, pct_base, show_n |
| label | show_labels, label_content, label_position, label_format, label_size |
| style | fill_color, palette, alpha, border_color, bar_radius |
| advanced | show_refline, refline_value, top_n, flip_if_long |

---

## 5. Scatter Chart Module

> **Source:** `SCATTER_MODULE_TODO.md`

### Phase 1 — Core family ✅

- ✅ `scatter_basic.R`
- ✅ `scatter_grouped.R`
- ✅ `scatter_regression.R`
- ✅ `scatter_jitter.R`
- ✅ `scatter_bubble.R`
- ✅ `CHART_MENU_GROUPS` updated with "散点图家族" group
- ✅ `R/scatter_scene_presets.R` with 5 templates:
  - `corr_basic` — basic correlation
  - `group_compare` — grouped comparison
  - `regression_ci` — regression + CI
  - `bubble_impact` — bubble size as 3rd variable
  - `outlier_label` — outlier labelling

### Phase 2 — Advanced scatter types ⏳

- ⏳ `scatter_facet` — faceted scatter
- ⏳ `scatter_label` — labelled points
- ⏳ `scatter_path` — path / trajectory
- ⏳ `scatter_density2d` — 2D density contours
- ⏳ `scatter_hexbin` — hexbin for large datasets

### Phase 2 — Smart validation rules ⏳

- ⏳ Too many points → suggest reducing alpha
- ⏳ Very large dataset → suggest hexbin / density2d
- ⏳ Heavy overlap → suggest jitter
- ⏳ Non-numeric x/y → intercept with helpful message
- ⏳ Mapping conflict (size + color on same variable) → warning

### Phase 3 — Advanced modes ⏳

- ⏳ `scatter_errorbar` — scatter with error bars
- ⏳ `scatter_paired` — paired data scatter
- ⏳ Outlier detection + automatic label suggestions
- ⏳ Auto-recommend fit method

---

## 6. AI V1 Upgrade

> **Source:** `AI_V1_UPGRADE_TODO.md`
> **Status:** ✅ All completed

### What was built

**Phase A — Contract & Prompt** ✅
- Upgraded system prompt from single recommendation to structured multi-recommendation JSON
- Schema: `primary`, `recommendations[]`, `column_mapping`, `options_patch`, `warnings`
- Backward compatible with legacy `recommended_chart` format

**Phase B — Parsing & Normalization** ✅
- `normalize_recommendation_item()` — validates chart ID, confidence, mappings
- Supports up to 3 ranked recommendations
- `normalize_suggestion_payload()` — resolves primary recommendation index

**Phase C — Runtime context injection** ✅
- Data summary sent with each request: rows, columns, types, missing counts, sample values
- Injected as a transient system message per send (not stored in history)

**Phase D — Apply engine** ✅
- `apply_column_mapping()` — remaps data columns by semantic role (x/y/group/size/label)
- `apply_common_patch()` — updates global inputs (title, labels, palette, theme, ranges)
- `apply_chart_option_patch()` — type-aware widget updates (slider/checkbox/select/color)
- Apply summary notification shown after each operation

**Phase E — Suggestion UI** ✅
- Multi-option card with selection dropdown
- Per-recommendation reason and warnings
- Apply Selected + Dismiss buttons

### Files changed
`R/chart_registry.R`, `R/kimi_api.R`, `R/modules/mod_ai_chat.R`

---

## 7. AI Flex Intent Engine (Phase 1–7)

> **Source:** `AI_FLEX_INTENT_TODO.md`
> **Goal:** Replace hardcoded phrase matching with a proper NLP intent engine
> supporting natural language, synonyms, LLM fallback, confidence routing,
> preview cards, and undo.

### Design principles
- User should not need to memorise command templates
- Understand intent first, then map to parameters — never the reverse
- Explainable: always tell the user what was understood and what changed
- Safe fallback: low confidence → ask one clarifying question, not silent failure

### Phase 1 — Intent engine core ✅

File: `R/core/intent_engine.R`

- ✅ Unified intent schema:
  - `intent_type`: `modify_current | recommend_new | undo | unknown`
  - `common_patch`: global params (title, labels, palette, theme, ranges, dimensions)
  - `options_patch`: chart-specific `opt_*` params
  - `confidence`: `high | medium | low`
  - `needs_clarification` + `clarify_question`
  - `source`: `local | llm | fallback`
  - `hits`: list of matched field names
- ✅ `parse_intent()` orchestrates the 3-layer pipeline
- ✅ Layer 1: `extract_intent_local()` — synonym dict + regex, no API call
- ✅ Layer 2: `extract_intent_llm()` — focused parameter-extractor prompt (not chart recommender)
- ✅ LLM prompt injects `options_def` for the current chart so LLM knows valid values

### Phase 2 — Natural language coverage ✅

- ✅ `INTENT_SYNONYMS` dictionary (Chinese + English, mixed):
  - plot_title, x_label, y_label, alpha, point_size, bar_width, show_labels, show_smooth, …
- ✅ `CHANGE_VERBS`: 改成/改为/设为/换成/=/:/ →/ …
- ✅ Range parsing: "0到100" / "0~100" / "0-100" / "between 0 and 100"
- ✅ Bool parsing: 开/关/显示/隐藏/on/off/true/false/要/不要
- ✅ Word boundary fix: ASCII-only words (on/off/true/false) use `\b` anchors to prevent
  false positives (e.g., "on" inside "Month")
- ✅ Special title pattern: 起名/取名/命名 → dedicate regex captures the value
- 🔄 Axis range synonyms expanded (x坐标/x轴/横轴/横坐标) — fix in progress

### Phase 3 — Execution strategy ✅

- ✅ Three-tier routing in `mod_ai_chat.R`:
  - `high` confidence → auto-apply + echo summary in chat
  - `medium` confidence → show intent preview card with "Apply / Cancel"
  - `low` + needs_clarification → ask one targeted question
- ✅ `rv$pending_intent` holds the unconfirmed intent
- ✅ `output$intent_preview_ui` — coloured card listing fields to be changed with confidence badge
- ✅ `intent_confirm_btn` / `intent_cancel_btn` observers

### Phase 4 — Undo stack ✅

- ✅ `snapshot_inputs(input)` — captures all widget values before each patch
- ✅ `push_history(rv, snapshot)` — pushes onto `rv$patch_history` (max 10)
- ✅ `restore_last(rv, session)` — pops and bulk-updates widgets
- ✅ "撤销 / undo" detected by `UNDO_TRIGGERS` in local layer
- 🔄 Multi-turn context ("再把透明度调低一点" referencing previous param) — not yet done

### Phase 5 — Conflict & validation ⏳

- ⏳ Clamp numeric values to legal range before applying
- ⏳ Unsupported param for current chart → suggest alternative
- ⏳ Return actionable suggestion instead of silent failure

### Phase 6 — Full intent card UI ⏳

- ⏳ Intent type badge in chat bubbles
- ⏳ Fields table with before/after values
- ⏳ Confidence indicator in chat history
- ⏳ "Re-parse" button

### Phase 7 — Evaluation ⏳

- ⏳ Build a 30–50 sentence test set (Chinese-primary, mixed Chinese/English)
- ⏳ Targets: intent accuracy ≥ 90%, patch correct apply ≥ 85%, clarification rate ≤ 20%
- ⏳ Regression suite: must not break existing chart-recommendation flow

---

## Open Issues / Known Bugs

| Issue | File | Status |
|-------|------|--------|
| "修改X坐标1-10" not recognised | `R/core/intent_engine.R` axis_pats | 🔄 Fix prepared, needs test |
| Multi-turn context ("再…" referencing last param) | `intent_engine.R` Phase 4 | ⏳ Not started |
| Bar smart restrictions (negative y → diverging suggestion) | `mod_settings.R` | ⏳ Not started |
| Scatter Phase 2 (facet, hexbin, density2d) | `R/charts/scatter/` | ⏳ Not started |
| Intent eval test suite (Phase 7) | new `test_intent_eval.R` | ⏳ Not started |

---

*Consolidated from: ROADMAP.md, BAR_CHART_SYSTEM.md, BAR_CHART_ROADMAP.md,
MODULAR_PLAN.md, SCATTER_MODULE_TODO.md, PLOT_SETTINGS_ENHANCEMENT_TODO.md,
AI_V1_UPGRADE_TODO.md, AI_FLEX_INTENT_TODO.md*

*Last updated: 2026-03-27*
