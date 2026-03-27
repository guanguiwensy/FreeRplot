# =============================================================================
# File   : R/ui_helpers.R
# Purpose: Dynamic UI generation driven by the chart options_def registry.
#          Provides the two-level grouped dropdown, per-chart control panels,
#          input collection, show_when conditional visibility, and the default
#          options helper.
#
# Globals exported:
#   CHART_MENU_GROUPS  named list — group label → vector of chart IDs.
#                      Drives both the selectInput <optgroup> dropdown and the
#                      gallery tab grouping.  This is the single source of
#                      truth for chart ordering.  Add new IDs here when
#                      registering a new chart in chart_registry.R.
#
# Functions:
#   build_grouped_choices(charts, groups)
#     Converts CHART_MENU_GROUPS + CHARTS into a Shiny-compatible named list
#     rendered as <optgroup> elements by selectize.js.
#     Parameters: charts [list] CHARTS registry; groups [list] defaults to CHART_MENU_GROUPS.
#     Returns: named list suitable for selectInput(choices = ...).
#
#   build_controls(defs)
#     Generates a tagList of Shiny input widgets from an options_def list.
#     Controls with show_when are initially wrapped in shinyjs::hidden().
#     Parameters: defs [list] subset of chart$options_def.
#     Returns: tagList
#
#   collect_options(input)
#     Reads all opt_* input values and returns them as a named list.
#     Parameters: input [Shiny input] reactive input object.
#     Returns: named list  e.g. list(alpha=0.7, show_smooth=TRUE, ...)
#
#   get_default_options(chart_id)
#     Returns default option values from options_def for a chart.
#     Parameters: chart_id [chr]
#     Returns: named list
#
#   build_show_when_map(charts)
#     Builds a nested map: widget_id → list(trigger_id → required_value).
#     Used by apply_show_when() to toggle visibility reactively.
#     Parameters: charts [list] full CHARTS registry.
#     Returns: named list
#
#   apply_show_when(sw_map, chart_id, input)
#     Shows/hides controls based on the current input state and sw_map.
#     Parameters: sw_map [list]; chart_id [chr]; input [Shiny input].
#
#   build_system_prompt()
#     Constructs the LLM system prompt listing all registered chart IDs,
#     names, and descriptions.
#     Returns: chr
# =============================================================================


# 鈹€鈹€ CHART_MENU_GROUPS 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Defines the two-level dropdown grouping for the chart selector.
# Keys   = group label shown as <optgroup> header
# Values = ordered vector of chart IDs belonging to that group
#
# Add new chart IDs here when registering them in chart_registry.R.

CHART_MENU_GROUPS <- list(
  "📊 基础图表" = c("line", "area", "stacked_area", "bubble", "histogram", "lollipop"),
  "🎯 散点图家族" = c("scatter_basic", "scatter_grouped", "scatter_regression", "scatter_jitter", "scatter_bubble", "scatter"),
  "📉 柱图家族" = c("bar",
                     "bar_count", "bar_value", "bar_grouped",
                     "bar_stacked", "bar_filled", "bar_horizontal",
                     "bar_sorted", "bar_diverging", "bar_errorbar",
                     "bar_dotplot", "bar_facet", "bar_grouped_stacked"),
  "📦 分布分析" = c("boxplot", "violin", "density", "ridgeline"),
  "🧩 比例结构" = c("pie", "treemap"),
  "🔆 关系分析" = c("heatmap", "correlation", "radar"),
  "🌀 流向图" = c("circos"),
  "🧬 基因序列" = c("dna_single", "dna_methylation", "dna_many")
)

# 鈹€鈹€ build_grouped_choices() 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Converts CHART_MENU_GROUPS + CHARTS into a named list suitable for
# selectInput(choices = ...), which Shiny renders as <optgroup> elements.
#
# Only includes IDs that actually exist in `charts`; unknown/future IDs are
# silently skipped so the registry and the menu can be updated independently.
#
# Returns a named list, e.g.:
#   list(
#     "馃搳 鍩虹鍥捐〃" = c("鏁ｇ偣鍥? = "scatter", "鎶樼嚎鍥? = "line", ...),
#     "馃搲 鏌卞浘瀹舵棌" = c("鏌辩姸鍥? = "bar", ...),
#     ...
#   )

build_grouped_choices <- function(charts,
                                   groups = CHART_MENU_GROUPS) {
  result <- lapply(groups, function(ids) {
    # Keep only IDs that are registered in charts
    valid <- ids[ids %in% names(charts)]
    if (length(valid) == 0) return(NULL)
    # name  = display label,  value = chart id
    setNames(valid, sapply(valid, function(id) charts[[id]]$name))
  })
  # Drop empty groups (e.g. bar_count before it's registered)
  Filter(Negate(is.null), result)
}

# 鈹€鈹€ build_controls() 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Converts a list of control-definition objects (from chart$options_def)
# into a Shiny tagList ready to be placed inside renderUI.
#
# Each definition object supports these fields:
#   id        (chr)  unique key; control rendered as input "opt_{id}"
#   label     (chr)  human-readable label shown in UI
#   type      (chr)  "slider" | "checkbox" | "select" | "color" | "numeric" | "text"
#   group     (chr)  "basic" (always visible) | "advanced" (inside accordion)
#   default   (any)  initial value
#   min/max/step     for slider / numeric
#   choices   (named chr vector)  for select
#   show_when (chr)  e.g. "show_smooth" 鈥?id of a checkbox that must be TRUE
#                    (Phase 3: currently stored but not yet enforced in UI)

build_controls <- function(defs) {
  if (is.null(defs) || length(defs) == 0) return(tagList())

  controls <- lapply(defs, function(d) {
    input_id <- paste0("opt_", d$id)
    wrap_id  <- paste0("wrap_opt_", d$id)

    ctrl <- switch(d$type,

      slider = sliderInput(
        inputId = input_id,
        label   = d$label,
        min     = d$min,
        max     = d$max,
        value   = d$default,
        step    = d$step %||% 0.1,
        width   = "100%"
      ),

      checkbox = checkboxInput(
        inputId = input_id,
        label   = d$label,
        value   = isTRUE(d$default)
      ),

      select = selectInput(
        inputId  = input_id,
        label    = d$label,
        choices  = d$choices,
        selected = d$default,
        width    = "100%"
      ),

      color = colourpicker::colourInput(
        inputId        = input_id,
        label          = d$label,
        value          = d$default %||% "#4ECDC4",
        showColour     = "background",
        returnName     = FALSE
      ),

      numeric = numericInput(
        inputId = input_id,
        label   = d$label,
        value   = d$default %||% 0,
        min     = d$min,
        max     = d$max,
        step    = d$step %||% 1,
        width   = "100%"
      ),

      text = textInput(
        inputId = input_id,
        label   = d$label,
        value   = d$default %||% "",
        width   = "100%"
      ),

      {
        warning("build_controls: unknown type '", d$type,
                "' for control '", d$id, "' 鈥?skipped.")
        NULL
      }
    )

    if (is.null(ctrl)) return(NULL)

    # Controls with show_when start hidden; shinyjs::show/hide toggles them.
    # Controls without show_when are always visible.
    wrapper <- div(id = wrap_id, ctrl)
    if (!is.null(d$show_when)) shinyjs::hidden(wrapper) else wrapper
  })

  do.call(tagList, Filter(Negate(is.null), controls))
}


# 鈹€鈹€ collect_options() 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Scans all "opt_*" inputs in the current Shiny session and returns them as a
# named list with the "opt_" prefix stripped.
# Call inside observeEvent / reactive where input is in scope.

collect_options <- function(input) {
  all_inputs <- shiny::reactiveValuesToList(input)
  opt_keys   <- names(all_inputs)[startsWith(names(all_inputs), "opt_")]
  if (length(opt_keys) == 0) return(list())
  setNames(
    lapply(opt_keys, function(k) all_inputs[[k]]),
    sub("^opt_", "", opt_keys)
  )
}


# 鈹€鈹€ get_default_options() 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Returns a named list of default values from a chart's options_def.
# Useful for initialising options when input is not yet available
# (e.g., server-side code-template rendering before user interaction).

get_default_options <- function(chart) {
  defs <- chart$options_def
  if (is.null(defs) || length(defs) == 0) return(list())
  setNames(
    lapply(defs, function(d) d$default),
    sapply(defs, function(d) d$id)
  )
}


# 鈹€鈹€ build_show_when_map() 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Pre-computes a lookup table from all charts:
#   chart_id 鈫?trigger_input_id 鈫?character vector of wrap_div_ids
#
# Called once at server startup; result passed to show_when observer logic.

build_show_when_map <- function(charts) {
  lapply(charts, function(chart) {
    defs <- chart$options_def
    if (is.null(defs)) return(list())
    result <- list()
    for (d in defs) {
      if (!is.null(d$show_when)) {
        key        <- paste0("opt_", d$show_when)   # e.g. "opt_show_smooth"
        wrap_id    <- paste0("wrap_opt_", d$id)      # e.g. "wrap_opt_smooth_method"
        result[[key]] <- c(result[[key]], wrap_id)
      }
    }
    result
  })
}


# 鈹€鈹€ apply_show_when() 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#
# Reads each trigger input for the active chart and calls shinyjs::show/hide
# on the corresponding wrapper divs.  Safe to call at any time 鈥?shinyjs
# silently ignores missing DOM elements (e.g. before renderUI completes).
#
# Args:
#   show_when_map  result of build_show_when_map(CHARTS)
#   chart_id       current value of input$chart_type_select
#   input          Shiny input object

apply_show_when <- function(show_when_map, chart_id, input) {
  map <- show_when_map[[chart_id]]
  if (length(map) == 0) return(invisible(NULL))
  for (trigger_id in names(map)) {
    val      <- isTRUE(input[[trigger_id]])
    wrap_ids <- map[[trigger_id]]
    for (wid in wrap_ids) {
      if (val) shinyjs::show(wid) else shinyjs::hide(wid)
    }
  }
  invisible(NULL)
}

