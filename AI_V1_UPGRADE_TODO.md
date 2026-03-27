# AI V1 Upgrade TODO (Completed)

## Phase A - Contract & Prompt
- [x] Upgrade system prompt from single recommendation to structured multi-recommendation JSON.
- [x] Define JSON schema with `primary`, `recommendations`, `column_mapping`, `options_patch`, `warnings`.
- [x] Keep backward compatibility for legacy `recommended_chart` format.

## Phase B - Parsing & Normalization
- [x] Rebuild Kimi parser to normalize recommendation items.
- [x] Support up to 3 ranked recommendations.
- [x] Normalize confidence and filter invalid chart IDs.
- [x] Preserve compatibility fields for existing UI flow.

## Phase C - Runtime Context Injection
- [x] Add runtime data summary to AI request (rows, columns, types, missing, sample values).
- [x] Inject context as transient system message for each send action.

## Phase D - Apply Engine
- [x] Implement column mapping apply (`column_mapping`) by generating semantic columns (`x/y/group/...`).
- [x] Implement global settings patch apply (`plot_title`, labels, palette, theme, export/axis settings).
- [x] Implement chart option patch apply (`options_patch`) with type-aware UI updates.
- [x] Show apply summary notification (mapping/global/chart options).

## Phase E - Suggestion UI
- [x] Upgrade suggestion card to show multiple options.
- [x] Add selection dropdown + "Apply Selected" action.
- [x] Show per-recommendation reason and warnings.
- [x] Keep dismiss behavior.

## Phase F - Validation
- [x] `source('global.R'); source('ui.R'); source('server.R')` passes.
- [x] `source('app.R')` passes.

## Files Changed
- [x] `D:/coding/r-plot-ai/R/chart_registry.R`
- [x] `D:/coding/r-plot-ai/R/kimi_api.R`
- [x] `D:/coding/r-plot-ai/R/modules/mod_ai_chat.R`
- [x] `D:/coding/r-plot-ai/AI_V1_UPGRADE_TODO.md`