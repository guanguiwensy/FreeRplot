# =============================================================================
# File   : R/ui/panel_data.R
# Purpose: Data tab UI for data import, source visibility, and direct editing.
#          The layout is table-first:
#            1. quick actions (load / download sample)
#            2. current data-source badge
#            3. compact import card with file / paste modes
#            4. current data table shown in a simple handsontable area
#
# Exports:
#   tab_data_ui()
#     Returns the complete content for the "Data" tabPanel.
#     No parameters.
# =============================================================================

tab_data_ui <- function() {
  div(
    class = "tab-pane-shell data-pane-shell p-2",

    div(
      class = "data-topbar",

      div(
        class = "data-topbar-actions",
        actionButton(
          "load_sample_btn",
          "加载示例数据",
          class = "btn btn-sm data-action-btn data-action-btn-soft"
        ),
        downloadButton(
          "download_csv",
          "下载示例数据",
          class = "btn btn-sm data-action-btn data-action-btn-soft"
        )
      ),

      div(
        class = "data-source-panel",
        div(class = "data-meta-label", "当前数据来源"),
        uiOutput("data_source_ui")
      )
    ),

    div(
      class = "data-import-card",

      div(
        class = "data-section-head",
        div(
          h6(class = "data-section-title mb-1", "数据导入"),
          p(
            class = "data-section-subtitle mb-0",
            "支持 .csv / .tsv / .xlsx，Excel 默认读取第一个工作表。"
          )
        )
      ),

      div(
        class = "data-meta-grid",
        div(
          class = "data-meta-item",
          div(class = "data-meta-label", "当前图表字段"),
          uiOutput("data_requirements_ui")
        )
      ),

      div(
        class = "data-import-tabs",
        tabsetPanel(
          id = "data_import_mode",
          type = "pills",

          tabPanel(
            "文件导入",
            div(
              class = "data-upload-area",
              fileInput(
                "upload_file",
                label = "上传数据文件",
                accept = c(".csv", ".tsv", ".xlsx"),
                placeholder = "支持 .csv / .tsv / .xlsx",
                width = "100%",
                buttonLabel = "选择文件"
              ),
              p(
                class = "data-upload-hint text-muted mb-0",
                "CSV / TSV 会自动尝试常见编码；XLSX 默认读取首个工作表。"
              )
            )
          ),

          tabPanel(
            "粘贴数据（Excel / WPS）",
            div(
              class = "data-paste-panel",
              textAreaInput(
                "paste_data_area",
                label = NULL,
                placeholder = "从 Excel / WPS 粘贴表格数据，支持制表符、逗号或分号分隔。",
                rows = 5,
                width = "100%"
              ),
              div(
                class = "data-paste-actions mt-1",
                checkboxInput("paste_has_header", "首行为表头", value = TRUE),
                actionButton("paste_import_btn", "导入到表格", class = "btn btn-sm btn-primary")
              )
            )
          )
        )
      )
    ),

    div(
      class = "data-table-card",
      div(
        class = "data-section-head data-table-head",
        h6(class = "data-section-title mb-0", "当前数据表")
      ),
      div(
        class = "data-table-shell",
        rHandsontableOutput("data_table", height = "200px")
      )
    )
  )
}
