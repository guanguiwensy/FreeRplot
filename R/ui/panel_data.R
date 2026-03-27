# =============================================================================
# File   : R/ui/panel_data.R
# Purpose: Data tab UI — toolbar (load sample / download CSV / upload CSV),
#          Excel-paste accordion, and the editable handsontable grid.
#          Mirrors server logic in R/modules/mod_data.R.
#
# Exports:
#   tab_data_ui()
#     Returns the complete content for the "Data" tabPanel.
#     No parameters.
# =============================================================================

tab_data_ui <- function() {
  div(
    class = "p-2",

    # Toolbar row
    div(
      class = "data-toolbar",
      actionButton("load_sample_btn", "Load Sample Data", class = "btn btn-outline-info btn-sm"),
      downloadButton("download_csv",  "Download CSV Template", class = "btn btn-outline-secondary btn-sm"),
      fileInput(
        "upload_file",
        label       = NULL,
        accept      = c(".csv"),
        placeholder = "Upload CSV",
        width       = "200px",
        buttonLabel = "Choose File"
      )
    ),

    # Excel / WPS paste accordion
    bslib::accordion(
      open = FALSE,
      bslib::accordion_panel(
        "Paste Data (Excel / WPS)",
        div(
          textAreaInput(
            "paste_data_area",
            label       = NULL,
            placeholder = "Paste from Excel/WPS. Supports tab, comma, or semicolon delimiters.",
            rows        = 5,
            width       = "100%"
          ),
          div(
            class = "d-flex align-items-center gap-3 mt-1",
            checkboxInput("paste_has_header", "First row is header", value = TRUE),
            actionButton("paste_import_btn", "Import to Table", class = "btn btn-sm btn-primary")
          )
        )
      )
    ),

    # Editable data grid
    rHandsontableOutput("data_table", height = "200px")
  )
}
