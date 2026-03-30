# =============================================================================
# File   : R/ui/panel_settings.R
# Purpose: Settings tab UI for scene templates, user recipes, base styling,
#          color management, axis/export controls, and chart-specific options.
#          Mirrors server logic in R/modules/mod_settings.R.
#
# Exports:
#   tab_settings_ui()
#     Returns the complete content for the "Settings" tabPanel.
# =============================================================================

tab_settings_ui <- function() {
  div(
    class = "tab-pane-shell settings-pane-shell settings-pane p-3",

    div(
      class = "settings-section-card",
      div(class = "settings-section-title", "\u5b98\u65b9\u573a\u666f\u6a21\u677f"),
      tags$p(
        class = "settings-section-help",
        "\u5b98\u65b9\u573a\u666f\u6a21\u677f\u7528\u4e8e\u5feb\u901f\u8d77\u6b65\uff0c\u9002\u5408\u5148\u9009\u4e00\u4e2a\u5e38\u89c1\u56fe\u8868\u5f62\u6001\u518d\u7ee7\u7eed\u7ec6\u8c03\u3002"
      ),
      uiOutput("scene_templates_ui")
    ),

    div(
      class = "settings-section-card",
      div(class = "settings-section-title", "\u6211\u7684\u914d\u65b9"),
      tags$p(
        class = "settings-section-help",
        "\u6211\u7684\u914d\u65b9\u4f1a\u8bb0\u5f55\u56fe\u8868\u7c7b\u578b\u548c\u5f53\u524d\u8bbe\u7f6e\uff0c\u4f46\u4e0d\u4fdd\u5b58\u539f\u59cb\u6570\u636e\u3002"
      ),
      div(
        class = "settings-toolbar-row",
        div(
          class = "settings-flex-grow",
          selectInput(
            "recipe_select",
            label = "\u9009\u62e9\u914d\u65b9",
            choices = c("\u6682\u65e0\u914d\u65b9" = ""),
            width = "100%"
          )
        ),
        actionButton("recipe_load_btn", "\u52a0\u8f7d", class = "btn btn-sm btn-outline-primary settings-action-btn"),
        actionButton("recipe_save_btn", "\u4fdd\u5b58", class = "btn btn-sm btn-outline-success settings-action-btn"),
        actionButton("recipe_delete_btn", "\u5220\u9664", class = "btn btn-sm btn-outline-danger settings-action-btn")
      ),
      tags$small(
        class = "settings-inline-note",
        "\u5df2\u4fdd\u5b58\u7684\u914d\u65b9\u4f1a\u4ee5\u300c\u914d\u65b9\u540d [\u56fe\u8868]\u300d\u65b9\u5f0f\u663e\u793a\uff0c\u65e7\u7248 preset \u4f1a\u4ee5\u300c\u65e7\u7248\u300d\u6807\u8bc6\u663e\u793a\u3002"
      )
    ),

    div(
      class = "settings-section-card",
      div(class = "settings-section-title", "\u57fa\u7840\u6837\u5f0f"),
      layout_columns(
        col_widths = c(6, 6),
        textInput("plot_title", "\u56fe\u8868\u6807\u9898", placeholder = "\uff08\u53ef\u9009\uff09"),
        textInput("x_label", "\u0058\u8f74\u6807\u7b7e", placeholder = "\uff08\u53ef\u9009\uff09")
      ),
      layout_columns(
        col_widths = c(6, 6),
        textInput("y_label", "\u0059\u8f74\u6807\u7b7e", placeholder = "\uff08\u53ef\u9009\uff09"),
        selectInput(
          "chart_theme",
          "\u56fe\u8868\u4e3b\u9898",
          choices = names(CHART_THEMES),
          selected = names(CHART_THEMES)[1],
          width = "100%"
        )
      )
    ),

    div(
      class = "settings-section-card",
      div(class = "settings-section-title", "\u6570\u636e\u6620\u5c04"),
      tags$p(
        class = "settings-section-help",
        "\u6307\u5b9a\u54ea\u4e00\u5217\u4f5c\u4e3a X/Y/\u5206\u7ec4/\u6807\u7b7e/\u5927\u5c0f\uff0c\u89e3\u51b3\u4e0a\u4f20\u6570\u636e\u65f6\u81ea\u52a8\u731c\u6d4b\u4e0d\u51c6\u7684\u95ee\u9898\u3002"
      ),
      uiOutput("data_mapping_ui")
    ),

    div(
      class = "settings-section-card",
      div(class = "settings-section-title", "\u989c\u8272"),
      selectInput(
        "color_palette",
        "\u57fa\u7840\u914d\u8272",
        choices = names(COLOR_PALETTES),
        selected = names(COLOR_PALETTES)[1],
        width = "100%"
      ),
      tags$p(
        class = "settings-section-help",
        "\u5148\u9009\u62e9\u4e00\u5957\u57fa\u7840\u914d\u8272\uff0c\u518d\u6309\u9700\u8981\u5bf9\u5c11\u6570\u5177\u4f53\u53d6\u503c\u505a\u5c40\u90e8\u989c\u8272\u8986\u76d6\u3002"
      ),
      uiOutput("color_settings_ui")
    ),

    div(
      class = "settings-section-card",
      div(class = "settings-section-title", "\u5750\u6807\u4e0e\u5bfc\u51fa"),
      layout_columns(
        col_widths = c(4, 4, 4),
        numericInput("plot_width_in", "\u5bbd\u5ea6\uff08in\uff09", value = 10, min = 2, max = 40, step = 0.5, width = "100%"),
        numericInput("plot_height_in", "\u9ad8\u5ea6\uff08in\uff09", value = 6, min = 2, max = 40, step = 0.5, width = "100%"),
        numericInput("plot_dpi", "\u0050\u004e\u0047 DPI", value = 150, min = 72, max = 600, step = 10, width = "100%")
      ),
      layout_columns(
        col_widths = c(4, 4, 4),
        selectInput(
          "x_range_mode",
          "\u0058\u8f74\u8303\u56f4",
          choices = c("\u81ea\u52a8" = "auto", "\u624b\u52a8" = "manual"),
          selected = "auto",
          width = "100%"
        ),
        uiOutput("x_min_ui"),
        uiOutput("x_max_ui")
      ),
      layout_columns(
        col_widths = c(4, 4, 4),
        selectInput(
          "y_range_mode",
          "\u0059\u8f74\u8303\u56f4",
          choices = c("\u81ea\u52a8" = "auto", "\u624b\u52a8" = "manual"),
          selected = "auto",
          width = "100%"
        ),
        uiOutput("y_min_ui"),
        uiOutput("y_max_ui")
      ),
      uiOutput("axis_hint_ui")
    ),

    div(
      class = "settings-section-card",
      div(class = "settings-section-title", "\u5f53\u524d\u56fe\u8868\u4e13\u5c5e\u8bbe\u7f6e"),
      tags$p(
        class = "settings-section-help",
        "\u8fd9\u91cc\u53ea\u663e\u793a\u5f53\u524d\u56fe\u8868\u5b9e\u9645\u9700\u8981\u7684\u53c2\u6570\uff0c\u4e0d\u518d\u6df7\u5165\u5176\u4ed6\u56fe\u8868\u6b8b\u7559\u9009\u9879\u3002"
      ),
      uiOutput("chart_opts_ui")
    ),

    overlay_settings_section_ui()
  )
}
