# R Intelligent Chart Assistant — Project Guide

> **Purpose of this document**: machine-readable reference for LLM-assisted
> maintenance.  When modifying the project, read the relevant section first to
> understand dependencies before editing any file.
>
> **Read first**: before any development work, also read `DEVELOPMENT_RULES.md`.
> The constraints in that file are part of the project's ongoing maintenance rules.

---

## 1. Project Overview

An interactive R Shiny application that combines ggplot2 chart generation with
a natural-language AI interface.  Users describe their data and visualisation
goals in a chat panel; the app recommends chart types, applies parameter
modifications, and exports ready-to-run R code.

**Key capabilities**
- 45+ chart types organised in a two-level dropdown grouped by family
- Natural-language intent engine (local synonym matching → LLM fallback)
- Multi-provider LLM support: Kimi, DeepSeek, Qwen, Zhipu, OpenAI, custom
- Persistent API key storage (one-time setup)
- Scene template presets for bar and scatter families
- User-defined named presets per chart type (JSON-backed)
- 10-step undo stack
- Export: PNG / PDF / SVG with custom DPI and dimensions
- Reproducible R code output panel
- Data import: CSV / TSV / XLSX file upload and Excel/WPS paste
- Column-mapping modal: auto-maps user columns to chart spec on chart switch
- Chart recommendation: on-demand analysis with real-data preview thumbnails
- SVG overlay annotation layer (shapes, text, arrows)

---

## 2. File Structure

```
r-plot-ai/
├── app.R                         Entry point — shinyApp(ui, server)
├── global.R                      Bootstrap: packages, source order, global helpers
├── ui.R                          Layout assembler — calls panel_*_ui() functions
├── server.R                      Server entry — creates rv, calls init_mod_*()
├── setup.R                       One-time dependency installer
├── DEVELOPMENT_RULES.md          Mandatory dev constraints (read before coding)
├── PROJECT_GUIDE.md              This file
│
├── R/
│   ├── utils/
│   │   └── logger.R              log_debug/info/warn/error, safe_run()
│   │
│   ├── config_manager.R          LLM_PROVIDERS, load/save_api_config, get_api_url
│   ├── ui_helpers.R              CHART_MENU_GROUPS, build_grouped_choices,
│   │                             build_controls, collect_options, show_when helpers
│   ├── chart_registry.R          Auto-discovers R/charts/**/*.R → CHARTS, CHART_IDS
│   ├── plot_core.R               COLOR_PALETTES, CHART_THEMES, generate_plot,
│   │                             apply_theme, apply_axis_limits, has_col
│   ├── kimi_api.R                chat_with_llm, chat_with_kimi (wrapper),
│   │                             parse_chart_suggestion
│   ├── preset_manager.R          save/load/delete/restore presets (JSON files)
│   ├── bar_scene_presets.R       BAR_SCENE_PRESETS (5 templates)
│   ├── scatter_scene_presets.R   SCATTER_SCENE_PRESETS (5 templates)
│   │
│   ├── core/
│   │   ├── intent_engine.R       parse_intent (3-layer NLP pipeline),
│   │   │                         INTENT_SYNONYMS, snapshot/push/restore undo stack
│   │   ├── code_engine.R         get_editor_code, apply_code_patches,
│   │   │                         quick_code_patch, build_patch_prompt
│   │   ├── module_shared.R       shared_prepare_code_context, shared_active_data_reactive,
│   │   │                         shared_build_plot_options, shared_collect_column_mapping
│   │   ├── chart_recommender.R   profile_data_for_recommend,
│   │   │                         recommend_charts_for_data, CHART_CAP_REG
│   │   ├── chart_capability_registry.R  load_chart_capability_registry
│   │   ├── ai_chat_handlers.R    register_ai_chat_handlers — all chat + recommendation
│   │   │                         observers; owns preview generation (.generate_preview_b64,
│   │   │                         .map_user_data_for_chart) and run_recommendations()
│   │   ├── ai_chat_helpers.R     ai_chat_helpers list: apply_recommendation, run_generate,
│   │   │                         apply_column_mapping, apply_common_patch, do_undo, etc.
│   │   ├── ai_chat_flow.R        run_ai_send_flow — LLM round-trip + intent apply
│   │   ├── ai_patch_apply.R      apply_recommendation, apply_column_mapping,
│   │   │                         apply_chart_option_patch, run_generate
│   │   └── ai_rule_config.R      ai_match_rule_string — YAML-driven rule lookup
│   │
│   ├── ui/                       UI panel constructor functions (sourced in global.R)
│   │   ├── panel_chat.R          chat_panel_ui()        — left column chat area
│   │   ├── panel_recommend.R     chart_recommend_panel_ui() — recommendation panel
│   │   │                         (shell only; content via output$chart_recommend_ui)
│   │   ├── panel_plot.R          plot_preview_card_ui() — chart type selector + canvas
│   │   │                         (no default chart selected on startup)
│   │   ├── panel_data.R          tab_data_ui()          — data tab with horizontal scroll
│   │   ├── panel_settings.R      tab_settings_ui()      — settings tab
│   │   ├── panel_code.R          tab_code_ui()          — R code tab
│   │   ├── panel_gallery.R       tab_gallery_ui()       — chart library tab
│   │   └── chat_renderers.R      register_ai_chat_renderers() — chat UI outputs +
│   │                             chart_recommend_ui (preview card grid)
│   │
│   ├── modules/                  Shiny server modules (sourced in global.R)
│   │   ├── mod_ai_chat.R         init_mod_ai_chat()  — chat, intent, undo,
│   │   │                         recommendation orchestration
│   │   ├── mod_data.R            init_mod_data()     — data loading/editing,
│   │   │                         column-mapping modal, auto-generate after mapping
│   │   ├── mod_plot.R            init_mod_plot()     — rendering, download, gallery
│   │   ├── mod_settings.R        init_mod_settings() — presets, API modal, show_when
│   │   ├── mod_code.R            init_mod_code()     — code editor, run, export
│   │   └── mod_overlay.R         init_mod_overlay()  — SVG annotation sync/export
│   │
│   └── charts/                   Chart definition files (auto-discovered)
│       ├── basic/        line, area, stacked_area, bubble, histogram, lollipop, scatter
│       ├── bar/          bar, bar_count, bar_value, bar_grouped, bar_stacked,
│       │                 bar_filled, bar_horizontal, bar_sorted, bar_diverging,
│       │                 bar_errorbar, bar_dotplot, bar_facet, bar_grouped_stacked
│       ├── scatter/      scatter_basic, scatter_grouped, scatter_regression,
│       │                 scatter_jitter, scatter_bubble
│       ├── distribution/ boxplot, violin, density, ridgeline
│       ├── proportion/   pie, treemap
│       ├── relationship/ heatmap, correlation, radar
│       ├── flow/         circos
│       └── genomics/     dna_single, dna_methylation, dna_many
│
├── www/
│   ├── styles.css                Custom CSS (includes .rec-preview-grid card styles)
│   └── overlay_editor.js         SVG overlay drawing engine
│
├── presets/                      User preset JSON files (git-ignored)
│   └── {chart_id}.json
│
└── docs/
    PROJECT_GUIDE.md              This file
    MODULAR_PLAN.md
    BAR_CHART_SYSTEM.md
    AI_FLEX_INTENT_TODO.md
    ROADMAP.md
```

---

## 3. Source Load Order (global.R)

The order below is **mandatory** — each step depends on the previous:

| Step | File | Provides |
|------|------|---------|
| 1 | `R/utils/logger.R` | `log_*`, `safe_run` |
| 2 | `R/config_manager.R` | `LLM_PROVIDERS`, `load_api_config`, `get_api_url` |
| 3 | `R/ui_helpers.R` | `CHART_MENU_GROUPS`, `build_*`, `apply_show_when` |
| 4 | `R/core/intent_engine.R` | `parse_intent`, undo stack |
| 5 | `R/chart_registry.R` | `CHARTS`, `CHART_IDS` |
| 6 | `R/plot_core.R` | `COLOR_PALETTES`, `CHART_THEMES`, `generate_plot` |
| 7 | `R/bar_scene_presets.R` | `BAR_SCENE_PRESETS` |
| 8 | `R/scatter_scene_presets.R` | `SCATTER_SCENE_PRESETS` |
| 9 | `R/kimi_api.R` | `chat_with_llm`, `parse_chart_suggestion` |
| 10 | `R/preset_manager.R` | `save_preset`, `load_presets`, … |
| 11 | `R/core/chart_recommender.R` | `profile_data_for_recommend`, `recommend_charts_for_data`, `CHART_CAP_REG` |
| 12 | `R/core/code_engine.R` | `get_editor_code`, `apply_code_patches` |
| 13 | `R/core/module_shared.R` | `shared_prepare_code_context`, `shared_*` |
| 14 | `R/core/ai_patch_apply.R` | `apply_recommendation`, `run_generate` |
| 15 | `R/core/ai_chat_helpers.R` | `ai_chat_helpers` list |
| 16 | `R/core/ai_chat_handlers.R` | `register_ai_chat_handlers` |
| 17 | `R/ui/*.R` | `chat_panel_ui`, `plot_preview_card_ui`, … |
| 18 | `R/modules/*.R` | `init_mod_*` |

---

## 4. Data Flow

### 4.1 AI Chat

```
User types message
        │
        ▼
input$send_btn  (mod_ai_chat.R)
        │
        ├─► parse_intent(text, chart_id)  ──►  intent_engine.R
        │         │                              Layer 1: local synonym dict
        │         │                              Layer 2: LLM structured JSON
        │         ▼
        │   intent object
        │   {intent_type, common_patch, options_patch, confidence}
        │         │
        │   ┌─────▼──────────────────────────────────────┐
        │   │ confidence == "high"  → apply immediately   │
        │   │ confidence == "medium"→ show preview card   │
        │   │ confidence == "low"   → ask clarification   │
        │   └─────────────────────────────────────────────┘
        │         │
        │   apply_common_patch(patch)    → updateTextInput / updateSelectInput
        │   apply_chart_option_patch()   → updateSliderInput / updateCheckboxInput
        │         │
        ▼         ▼
 input$generate_btn  (mod_plot.R / mod_code.R)
        │
        ├─► active_data()           — rhandsontable → data.frame
        ├─► build_plot_options()    — all input$* → options list
        ├─► generate_plot(id, data, opts)  — plot_core.R dispatcher
        │         └─► CHARTS[[id]]$plot_fn(data, opts)
        │
        ▼
 rv$current_plot → output$main_plot (renderPlot)
                 → output$r_code_output (renderText via code_template)
                 → download handlers (PNG/PDF)
```

### 4.2 Chart Recommendation

```
User clicks "图形推荐" (recommend_run_btn)
        │
        ▼
settings modal: select columns (rec_col_select) + count (rec_count)
        │
User clicks "开始分析" (rec_run_confirm_btn)
        │
        ▼
run_recommendations(selected_cols, n_recs)           ai_chat_handlers.R
        ├─► profile_data_for_recommend(data)          chart_recommender.R
        ├─► recommend_charts_for_data(...)            chart_recommender.R
        ├─► top N results → rv$chart_recommendations
        └─► for each rec:
              .map_user_data_for_chart(data, chart_id) — positional col remap
              .generate_preview_b64(chart_id, mapped)  — plot_fn → PNG → base64
              → rv$chart_recommend_previews[[chart_id]]
        │
        ▼
output$chart_recommend_ui (chat_renderers.R)
        → rec-preview-grid: base64 <img> + name + score + "使用" button
        │
User clicks "使用" (rec_select_{chart_id})
        │
        ▼
updateSelectInput("chart_type_select", selected = chart_id)
        │
        ▼
observeEvent(chart_type_select) in mod_data.R
        → user data present? → .show_col_mapping_modal(chart_id)
        │
User confirms mapping (apply_col_mapping)
        │
        ▼
rv$current_data columns renamed → shinyjs::click("generate_btn")
```

### 4.3 Data Import

```
User uploads file / pastes table
        │
        ▼
observeEvent(input$upload_file / input$paste_import_btn)   mod_data.R
        ├─► parse & validate → rv$current_data
        ├─► rv$current_data_source ← "upload" | "paste"
        └─► rv$current_data_file  ← temp CSV path

User selects chart type (chart_type_select)
        │
        ├─► user data present AND NOT preserve_once?
        │       └─► .show_col_mapping_modal(chart_id)
        │               selectInput per spec column (optional → default empty)
        │               apply_col_mapping → rename columns → auto-generate
        │
        └─► no user data? → load chart sample_data
```

---

## 5. Key Data Structures

### 5.1 Chart Definition (`chart_def`)
Each file in `R/charts/` must assign this to `chart_def`:
```r
chart_def <- list(
  id            = "scatter_basic",          # unique snake_case ID
  name          = "基础散点图",              # Chinese display name
  name_en       = "Basic Scatter",          # English display name
  category      = "散点图家族",
  description   = "...",
  best_for      = "...",
  columns       = "x(numeric), y(numeric), group(factor, optional)",
  sample_data   = data.frame(...),
  options_def   = list(                     # see §5.2
    list(id="alpha", label="Opacity", type="slider", ...)
  ),
  plot_fn       = function(data, options) { ... },   # returns ggplot / circos object
  code_template = function(options, data)  { ... }   # returns chr R code string
)
```

### 5.2 Option Descriptor (`options_def` entry)
```r
list(
  id        = "show_smooth",           # widget ID suffix (input$opt_show_smooth)
  label     = "Show Trend Line",
  type      = "checkbox",              # slider | checkbox | select | color | numeric | text
  group     = "basic",                 # "basic" | "advanced"
  default   = FALSE,
  show_when = "opt_show_smooth==TRUE"  # optional: hide until condition met
  # slider only:
  min = 0.1, max = 1, step = 0.05
  # select / radio only:
  choices = c("Linear" = "lm", "Loess" = "loess")
)
```

### 5.3 Intent Object (returned by `parse_intent`)
```r
list(
  intent_type         = "modify_current",   # | "recommend_new" | "undo" | "unknown"
  common_patch        = list(               # global Shiny inputs
    plot_title = "Sales Trend",
    x_min = 0, x_max = 100
  ),
  options_patch       = list(               # chart-specific opt_* inputs
    alpha = 0.5, show_smooth = TRUE
  ),
  confidence          = "high",             # | "medium" | "low"
  needs_clarification = FALSE,
  clarify_question    = "",
  source              = "local",            # | "llm" | "fallback"
  hits                = c("plot_title", "x_range", "opt_alpha")
)
```

### 5.4 Shared Reactive State (`rv`)
```r
rv <- reactiveValues(
  # ── chat ──────────────────────────────────────────────────────────────────
  messages                     = list(),  # OpenAI-format history (system+user+asst)
  pending_intent               = NULL,    # medium-confidence intent awaiting confirm
  suggestion                   = NULL,    # AI chart suggestion card payload
  patch_history                = list(),  # undo stack, max 10 snapshots

  # ── data ──────────────────────────────────────────────────────────────────
  current_data                 = NULL,    # active data.frame (NULL on startup)
  current_data_source          = "none",  # "none"|"sample"|"upload"|"paste"|"user_edit"
  current_data_file            = NULL,    # path to temp CSV for current data
  preserve_data_on_chart_change = FALSE,  # if TRUE, skip sample-swap once

  # ── plot ──────────────────────────────────────────────────────────────────
  current_plot                 = NULL,    # ggplot or circos object
  current_plot_code            = NULL,    # last successful R script string
  last_run_error               = NULL,    # last code-editor eval error (or NULL)

  # ── overlay ───────────────────────────────────────────────────────────────
  overlay_scene_json           = "[]",    # JSON array of annotation objects
  overlay_shared_points        = list(),  # data points synced to SVG layer

  # ── API / config ──────────────────────────────────────────────────────────
  api_config                   = list(),  # {provider, api_key, model, custom_url}

  # ── recommendation ────────────────────────────────────────────────────────
  chart_recommendations        = list(),  # top-N rec objects from recommender
  chart_recommend_profile      = NULL,    # data profile used for last rec run
  chart_recommend_previews     = list()   # chart_id -> base64 PNG preview string
)
```

### 5.5 Recommendation Object
```r
list(
  chart_id   = "stacked_area",
  chart_name = "堆叠面积图",
  status     = "recommended",   # | "available" | "not_recommended"
  score      = 85L,             # 0-100
  reason     = c("..."),        # human-readable fit notes
  mapping    = list(            # auto-detected role -> user_column
    x = "Year", y = NA, group = "Category", size = NA, label = NA
  )
)
```

---

## 6. Column Mapping Modal

Triggered automatically in `mod_data.R` when:
- User has uploaded / pasted data (`rv$current_data_source %in% c("upload","paste")`)
- AND user switches chart type (`input$chart_type_select`)
- AND `rv$preserve_data_on_chart_change` is FALSE

Flow:
1. `.column_specs_for_chart(chart_id)` parses `chart$columns` string into spec list
2. Each spec gets a `selectInput` (optional fields default to `"-- 不映射 --"`)
3. Auto-guess: exact name match → case-insensitive → positional (required only)
4. On "应用映射": columns renamed in `rv$current_data`, modal closed, generate triggered

---

## 7. How to Add a New Chart

1. **Create the file**: `R/charts/{family}/{id}.R`

2. **Define `chart_def`** with all required fields (see §5.1).

3. **Register in the menu**: add the id to the correct group in
   `CHART_MENU_GROUPS` in `R/ui_helpers.R`.

4. **Add sample data**: the `sample_data` field is shown immediately
   when the user selects the chart.

5. **Test**: run the app, select the chart, click Generate.

No changes to `global.R`, `server.R`, or `ui.R` are required — the
chart registry auto-discovers all `*.R` files under `R/charts/`.

---

## 8. How to Add a New LLM Provider

Edit `R/config_manager.R` — add an entry to `LLM_PROVIDERS`:
```r
my_provider = list(
  name        = "My Provider",
  url         = "https://api.example.com/v1/chat/completions",
  models      = c("model-a", "model-b"),
  placeholder = "sk-..."
)
```
No other files need changes — the settings modal reads `LLM_PROVIDERS`
dynamically.

---

## 9. Debug Mode

Set the environment variable before launching:
```r
Sys.setenv(RPLOT_LOG = "DEBUG")
shiny::runApp()
```

Log levels: `DEBUG` < `INFO` < `WARN` (default) < `ERROR`

Each log line format: `[HH:MM:SS][LEVEL][module] message`

Module tags used in log calls:
| Tag | File |
|-----|------|
| `global` | global.R |
| `mod_ai_chat` | R/modules/mod_ai_chat.R + R/core/ai_chat_handlers.R |
| `mod_plot` | R/modules/mod_plot.R |
| `mod_data` | R/modules/mod_data.R |
| `mod_settings` | R/modules/mod_settings.R |
| `mod_code` | R/modules/mod_code.R |
| `code_engine` | R/core/code_engine.R |

---

## 10. Environment Isolation

Two files use `local({...})` with `<<-` exports to keep internal
constants out of the global namespace:

| File | Private | Exported |
|------|---------|---------|
| `R/config_manager.R` | `.CONFIG_PATH`, `.default_config` | `LLM_PROVIDERS`, `load_api_config`, `save_api_config`, `get_api_url` |
| `R/kimi_api.R` | `.KIMI_API_URL`, `.normalize_*` helpers | `KIMI_API_URL` (alias), `chat_with_llm`, `chat_with_kimi`, `parse_chart_suggestion` |

Server modules (`mod_data.R`, `mod_code.R`, etc.) wrap their internals in
`local({...})` so `.MODULE`, helper functions, and private observers do not
leak into the global environment.

---

## 11. File Modification Quick Reference

| Goal | Edit |
|------|------|
| Add / rename a chart | `R/charts/{family}/{id}.R` + `R/ui_helpers.R` (CHART_MENU_GROUPS) |
| Change chart options | `R/charts/{family}/{id}.R` (options_def) |
| Add intent synonym | `R/core/intent_engine.R` (INTENT_SYNONYMS) |
| Add LLM provider | `R/config_manager.R` (LLM_PROVIDERS) |
| Change chat UI layout | `R/ui/panel_chat.R` |
| Change plot card / chart selector | `R/ui/panel_plot.R` |
| Change recommendation panel shell | `R/ui/panel_recommend.R` |
| Change recommendation card rendering | `R/ui/chat_renderers.R` |
| Change recommendation engine logic | `R/core/ai_chat_handlers.R` (run_recommendations) |
| Change column mapping modal | `R/modules/mod_data.R` (.show_col_mapping_modal) |
| Change data import / table display | `R/modules/mod_data.R` + `R/ui/panel_data.R` |
| Change settings tab | `R/ui/panel_settings.R` |
| Change colour palettes | `R/plot_core.R` (COLOR_PALETTES) |
| Change ggplot2 themes | `R/plot_core.R` (CHART_THEMES) |
| Add scene preset (bar) | `R/bar_scene_presets.R` |
| Add scene preset (scatter) | `R/scatter_scene_presets.R` |
| Global CSS | `www/styles.css` |
| Overlay drawing engine | `www/overlay_editor.js` |
