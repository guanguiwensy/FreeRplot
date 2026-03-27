# =============================================================================
# File   : ui.R
# Purpose: Top-level UI definition.  Assembles sub-panel functions sourced
#          from R/ui/ into the final page layout.
#          All panel content is defined in dedicated files; this file owns
#          only the page theme, global <head> tags, header bar, and the
#          two-column layout wrapper.
#
# Layout :
#   page_fillable
#     ├── <head>  JS helpers (Enter-to-send, scrollChat, copyRCode)
#     ├── .app-header  (logo + title + settings button)
#     └── layout_columns  col_widths = c(5, 7)
#           ├── [col 5]  chat_panel_ui()           → R/ui/panel_chat.R
#           └── [col 7]  tabsetPanel
#                 ├── plot_preview_card_ui()        → R/ui/panel_plot.R
#                 └── card  "Data & Settings"
#                       tabPanel "Data"             → tab_data_ui()
#                       tabPanel "Settings"         → tab_settings_ui()
#                       tabPanel "R Code"           → tab_code_ui()
#                       tabPanel "Chart Library"    → tab_gallery_ui()
#
# Sub-panel sources (loaded in global.R before this file is evaluated):
#   R/ui/panel_chat.R      panel_chat.R
#   R/ui/panel_plot.R      panel_plot.R
#   R/ui/panel_data.R      panel_data.R
#   R/ui/panel_settings.R  panel_settings.R
#   R/ui/panel_code.R      panel_code.R
#   R/ui/panel_gallery.R   panel_gallery.R
# =============================================================================

ui <- page_fillable(

  # ── Page theme ─────────────────────────────────────────────────────────────
  theme = bs_theme(
    bootswatch = "flatly",
    primary    = "#2c7be5",
    font_scale = 0.92
  ),
  title = "R Intelligent Chart Assistant",

  # ── Global <head>: shinyjs + styles + JS helpers ──────────────────────────
  tags$head(
    shinyjs::useShinyjs(),
    tags$link(rel = "stylesheet", href = "styles.css"),
    tags$script(HTML("
      // Send on Enter (Shift+Enter = newline)
      $(document).on('keydown', '#user_input', function(e) {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          $('#send_btn').click();
        }
      });

      // Scroll chat container to bottom
      Shiny.addCustomMessageHandler('scrollChat', function(msg) {
        var c = document.getElementById('chat-container');
        if (c) c.scrollTop = c.scrollHeight;
      });

      // Copy R code to clipboard
      function copyRCode() {
        var pre = document.getElementById('r_code_output');
        if (!pre) return;
        var text = pre.innerText || pre.textContent;
        navigator.clipboard.writeText(text).then(function() {
          var btn = document.getElementById('copy_code_btn');
          if (btn) {
            btn.innerText = 'Copied!';
            setTimeout(function(){ btn.innerText = 'Copy Code'; }, 2000);
          }
        });
      }
    "))
  ),

  # ── App header bar ─────────────────────────────────────────────────────────
  div(
    class = "app-header",
    span(class = "app-logo", "\U0001f4ca"),
    h4(class = "app-title", "R Intelligent Chart Assistant"),
    tags$small(style = "color:#8bacd4; margin-left:8px;", "Powered by LLM \u00d7 ggplot2"),
    div(
      style = "margin-left:auto;",
      actionButton("settings_btn", "Settings", class = "btn btn-sm btn-outline-light")
    )
  ),

  # ── Two-column layout ──────────────────────────────────────────────────────
  layout_columns(
    col_widths = c(5, 7),
    style      = "padding: 12px; gap: 12px; height: calc(100vh - 56px); overflow: hidden;",

    # Left column — AI chat panel
    chat_panel_ui(),

    # Right column — plot preview + data/settings/code tabs
    layout_columns(
      col_widths = 12,
      style      = "height: 100%; overflow-y: auto; gap: 10px;",

      # Plot preview card
      plot_preview_card_ui(),

      # Data & settings card with tab panels
      card(
        card_header("Data & Chart Settings"),
        tabsetPanel(
          type = "pills",
          id   = "data_tabs",
          tabPanel("Data",          tab_data_ui()),
          tabPanel("Settings",      tab_settings_ui()),
          tabPanel("R Code",        tab_code_ui()),
          tabPanel("Chart Library", tab_gallery_ui())
        )
      )
    )
  )
)
