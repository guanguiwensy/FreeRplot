ui <- page_fillable(
  theme = bs_theme(
    bootswatch = "flatly",
    primary = "#2c7be5",
    font_scale = 0.92
  ),
  title = "R 智能绘图助手",

  tags$head(
    shinyjs::useShinyjs(),
    tags$link(rel = "stylesheet", href = "styles.css"),
    tags$script(HTML(" 
      $(document).on('keydown', '#user_input', function(e) {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          $('#send_btn').click();
        }
      });

      Shiny.addCustomMessageHandler('scrollChat', function(msg) {
        var c = document.getElementById('chat-container');
        if (c) c.scrollTop = c.scrollHeight;
      });

      function copyRCode() {
        var pre = document.getElementById('r_code_output');
        if (!pre) return;
        var text = pre.innerText || pre.textContent;
        navigator.clipboard.writeText(text).then(function() {
          var btn = document.getElementById('copy_code_btn');
          if (btn) {
            btn.innerText = 'Copied';
            setTimeout(function(){ btn.innerText = 'Copy Code'; }, 2000);
          }
        });
      }
    "))
  ),

  div(class = "app-header",
      span(class = "app-logo", "📊"),
      h4(class = "app-title", "R 智能绘图助手"),
      tags$small(style = "color:#8bacd4; margin-left:8px;", "Powered by Kimi × ggplot2"),
      div(style = "margin-left:auto;",
          actionButton("settings_btn", "设置", class = "btn btn-sm btn-outline-light")
      )
  ),

  layout_columns(
    col_widths = c(5, 7),
    style = "padding: 12px; gap: 12px; height: calc(100vh - 56px); overflow: hidden;",

    card(
      style = "height: 100%; display: flex; flex-direction: column; overflow: hidden;",
      card_header(
        style = "flex-shrink: 0;",
        div(class = "d-flex align-items-center justify-content-between",
            div("AI 绘图顾问"),
            tags$small(class = "text-muted", "描述你的数据和可视化目标")
        )
      ),

      div(id = "chat-container",
          style = "flex: 1 1 auto; overflow-y: auto; padding: 12px; background: #f8f9fa; margin: 0 4px 4px;",
          uiOutput("chat_messages_ui")
      ),

      uiOutput("suggestion_ui"),
      uiOutput("intent_preview_ui"),

      div(class = "chat-input-wrapper",
          div(class = "d-flex gap-2",
              textAreaInput(
                "user_input", label = NULL, value = "",
                placeholder = "描述你的数据和可视化需求（Enter 发送，Shift+Enter 换行）",
                rows = 3, width = "100%"
              ),
              div(class = "d-flex flex-column gap-2",
                  actionButton("send_btn", "发送", class = "btn btn-primary btn-sm", icon = icon("paper-plane")),
                  actionButton("clear_btn", "清除", class = "btn btn-outline-secondary btn-sm")
              )
          )
      )
    ),

    layout_columns(
      col_widths = 12,
      style = "height: 100%; overflow-y: auto; gap: 10px;",

      card(
        card_header(
          div(class = "d-flex align-items-center gap-2 flex-wrap",
              span("图表预览"),
              div(class = "ms-auto d-flex align-items-center gap-2 flex-wrap",
                  selectInput(
                    "chart_type_select",
                    label = NULL,
                    choices = build_grouped_choices(CHARTS),
                    selected = "scatter_basic",
                    width = "185px"
                  ),
                  actionButton(
                    "generate_btn",
                    "生成图表",
                    class = "btn btn-success btn-sm",
                    icon = icon("wand-magic-sparkles")
                  ),
                  downloadButton("download_plot", "下载 PNG", class = "btn btn-outline-secondary btn-sm"),
                  downloadButton("download_plot_pdf", "下载 PDF", class = "btn btn-outline-secondary btn-sm")
              )
          )
        ),
        shinycssloaders::withSpinner(
          plotOutput("main_plot", height = "auto"),
          color = "#2c7be5", type = 6
        )
      ),

      card(
        card_header("数据与图表设置"),
        tabsetPanel(
          type = "pills",
          id = "data_tabs",

          tabPanel(
            "数据",
            div(class = "p-2",
                div(class = "data-toolbar",
                    actionButton("load_sample_btn", "加载示例数据", class = "btn btn-outline-info btn-sm"),
                    downloadButton("download_csv", "下载模板 CSV", class = "btn btn-outline-secondary btn-sm"),
                    fileInput(
                      "upload_file", label = NULL,
                      accept = c(".csv"), placeholder = "上传 CSV",
                      width = "200px", buttonLabel = "选择文件"
                    )
                ),

                bslib::accordion(
                  open = FALSE,
                  bslib::accordion_panel(
                    "粘贴数据（Excel/WPS）",
                    div(
                      textAreaInput(
                        "paste_data_area",
                        label = NULL,
                        placeholder = "从 Excel/WPS 复制后直接粘贴，支持制表符、逗号、分号分隔。",
                        rows = 5,
                        width = "100%"
                      ),
                      div(
                        class = "d-flex align-items-center gap-3 mt-1",
                        checkboxInput("paste_has_header", "第一行为列名", value = TRUE),
                        actionButton("paste_import_btn", "导入到表格", class = "btn btn-sm btn-primary")
                      )
                    )
                  )
                ),

                rHandsontableOutput("data_table", height = "200px")
            )
          ),

          tabPanel(
            "设置",
            div(class = "p-3",
                div(class = "d-flex align-items-center gap-2 mb-1",
                    tags$small(class = "text-muted fw-semibold text-nowrap", "预设"),
                    div(style = "flex:1; min-width:80px;",
                        selectInput("preset_select", label = NULL, choices = c("-- 暂无预设 --" = ""), width = "100%")
                    ),
                    actionButton("preset_load_btn", "加载", class = "btn btn-sm btn-outline-primary", title = "加载所选预设"),
                    actionButton("preset_save_btn", "另存", class = "btn btn-sm btn-outline-success", title = "保存当前设置"),
                    actionButton("preset_delete_btn", "删除", class = "btn btn-sm btn-outline-danger", title = "删除所选预设")
                ),
                tags$hr(style = "margin: 4px 0 10px;"),

                layout_columns(
                  col_widths = c(6, 6),
                  textInput("plot_title", "Plot Title", placeholder = "(optional)"),
                  textInput("x_label", "X Label", placeholder = "(optional)")
                ),
                layout_columns(
                  col_widths = c(6, 6),
                  textInput("y_label", "Y Label", placeholder = "(optional)"),
                  selectInput("color_palette", "Palette", choices = names(COLOR_PALETTES), selected = names(COLOR_PALETTES)[1])
                ),
                selectInput("chart_theme", "Theme", choices = names(CHART_THEMES), selected = names(CHART_THEMES)[1], width = "100%"),

                layout_columns(
                  col_widths = c(4, 4, 4),
                  numericInput("plot_width_in", "Width (in)", value = 10, min = 2, max = 40, step = 0.5, width = "100%"),
                  numericInput("plot_height_in", "Height (in)", value = 6, min = 2, max = 40, step = 0.5, width = "100%"),
                  numericInput("plot_dpi", "PNG DPI", value = 150, min = 72, max = 600, step = 10, width = "100%")
                ),
                layout_columns(
                  col_widths = c(4, 4, 4),
                  selectInput("x_range_mode", "X Range", choices = c("Auto" = "auto", "Manual" = "manual"), selected = "auto", width = "100%"),
                  numericInput("x_min", "X Min", value = NA_real_, step = 0.1, width = "100%"),
                  numericInput("x_max", "X Max", value = NA_real_, step = 0.1, width = "100%")
                ),
                layout_columns(
                  col_widths = c(4, 4, 4),
                  selectInput("y_range_mode", "Y Range", choices = c("Auto" = "auto", "Manual" = "manual"), selected = "auto", width = "100%"),
                  numericInput("y_min", "Y Min", value = NA_real_, step = 0.1, width = "100%"),
                  numericInput("y_max", "Y Max", value = NA_real_, step = 0.1, width = "100%")
                ),
                tags$hr(style = "margin: 10px 0 6px;"),

                uiOutput("bar_scene_ui"),
                uiOutput("scatter_scene_ui"),
                uiOutput("chart_opts_ui")
            )
          ),

          tabPanel(
            "R 代码",
            div(class = "p-3",
                div(style = "position: relative;",
                    tags$button(
                      id = "copy_code_btn",
                      "Copy Code",
                      onclick = "copyRCode()",
                      class = "btn btn-sm btn-outline-secondary",
                      style = "position:absolute; top:6px; right:6px; z-index:10; font-size:0.78rem;"
                    ),
                    verbatimTextOutput("r_code_output")
                )
            )
          ),

          tabPanel(
            "图表库",
            div(class = "p-3", uiOutput("chart_gallery_ui"))
          )
        )
      )
    )
  )
)