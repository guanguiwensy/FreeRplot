# =============================================================================
# File   : ui.R
# Purpose: Top-level UI definition. Assembles sub-panel functions sourced
#          from R/ui/ into the final page layout.
#          This version uses a two-level resizable IDE-style workspace:
#          chat vs workspace, then preview vs tabbed workbench.
#
# Layout :
#   page_fillable
#     ├── <head>  JS helpers + resizable panes script
#     ├── .app-header
#     └── #app-shell
#           ├── #pane-left            -> chat_panel_ui()
#           ├── #main-resizer         -> vertical drag handle
#           └── #workspace-shell
#                 ├── #pane-right-top    -> plot_preview_card_ui()
#                 ├── #workspace-resizer -> horizontal drag handle
#                 └── #pane-right-bottom -> tabbed workbench card
#
# Sub-panel sources (loaded in global.R before this file is evaluated):
#   R/ui/panel_chat.R
#   R/ui/panel_plot.R
#   R/ui/panel_data.R
#   R/ui/panel_settings.R
#   R/ui/panel_code.R
#   R/ui/panel_gallery.R
# =============================================================================

ui <- page_fillable(

  theme = bs_theme(
    bootswatch = "flatly",
    primary    = "#2c7be5",
    font_scale = 0.92
  ),
  title = "R Intelligent Chart Assistant",

  tags$head(
    shinyjs::useShinyjs(),
    tags$link(rel = "stylesheet", href = "styles.css?v=20260330b"),
    tags$script(src = "panes.js?v=20260330b"),
    tags$script(src = "overlay_editor.js?v=20260329e"),
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

      function setCopyCodeButtonState(state) {
        var btn = document.getElementById('copy_code_btn');
        if (!btn) return;

        var defaultLabel = btn.getAttribute('data-default-label') || '复制代码';
        var successLabel = btn.getAttribute('data-success-label') || '已复制';
        var failedLabel = btn.getAttribute('data-failed-label') || '复制失败';

        if (state === 'success') {
          btn.innerText = successLabel;
          btn.classList.add('is-copied');
          btn.classList.remove('is-failed');
        } else if (state === 'failed') {
          btn.innerText = failedLabel;
          btn.classList.add('is-failed');
          btn.classList.remove('is-copied');
        } else {
          btn.innerText = defaultLabel;
          btn.classList.remove('is-copied');
          btn.classList.remove('is-failed');
        }
      }

      function getRCodeText() {
        var store = document.getElementById('r_code_copy_store');
        if (store && typeof store.value === 'string') {
          return (store.value || '').trim();
        }

        var host = document.querySelector('.code-raw-store #r_code_output');
        if (!host) return '';
        return (host.textContent || '').trim();
      }

      function fallbackCopyText(text) {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.setAttribute('readonly', '');
        ta.style.position = 'fixed';
        ta.style.left = '-9999px';
        ta.style.top = '0';
        document.body.appendChild(ta);
        ta.focus();
        ta.select();

        try {
          return document.execCommand('copy');
        } finally {
          document.body.removeChild(ta);
        }
      }

      // Copy R code to clipboard
      function copyRCode() {
        var text = getRCodeText();
        if (!text) {
          setCopyCodeButtonState('failed');
          setTimeout(function() { setCopyCodeButtonState('default'); }, 1800);
          return;
        }

        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(function() {
            setCopyCodeButtonState('success');
            setTimeout(function() { setCopyCodeButtonState('default'); }, 1800);
          }).catch(function() {
            var ok = fallbackCopyText(text);
            setCopyCodeButtonState(ok ? 'success' : 'failed');
            setTimeout(function() { setCopyCodeButtonState('default'); }, 1800);
          });
          return;
        }

        var ok = fallbackCopyText(text);
        setCopyCodeButtonState(ok ? 'success' : 'failed');
        setTimeout(function() { setCopyCodeButtonState('default'); }, 1800);
      }
    "))
  ),

  div(
    class = "app-header",
    span(class = "app-logo", "\U0001f4ca"),
    h4(class = "app-title", "R Intelligent Chart Assistant"),
    tags$small(style = "color:#8bacd4; margin-left:8px;", "Powered by LLM × ggplot2"),
    div(
      style = "margin-left:auto;",
      div(
        class = "layout-tools",
        tags$button(
          type = "button",
          class = "btn btn-sm btn-outline-light layout-tool-btn",
          title = "Show/Hide AI panel",
          `data-pane-action` = "toggle-min",
          `data-pane-target` = "pane-left",
          icon("comments")
        ),
        tags$button(
          type = "button",
          class = "btn btn-sm btn-outline-light layout-tool-btn",
          title = "Show/Hide chart panel",
          `data-pane-action` = "toggle-min",
          `data-pane-target` = "pane-right-top",
          icon("chart-line")
        ),
        tags$button(
          type = "button",
          class = "btn btn-sm btn-outline-light layout-tool-btn",
          title = "Show/Hide workbench panel",
          `data-pane-action` = "toggle-min",
          `data-pane-target` = "pane-right-bottom",
          icon("sliders")
        ),
        tags$button(
          type = "button",
          class = "btn btn-sm btn-outline-light layout-tool-btn",
          title = "Restore layout",
          `data-pane-action` = "restore-layout",
          icon("up-right-and-down-left-from-center")
        ),
        actionButton("settings_btn", "Settings", class = "btn btn-sm btn-outline-light")
      )
    )
  ),

  div(
    id = "app-shell",
    class = "app-shell",

    div(
      id = "pane-left",
      class = "pane-shell pane-left-shell",
      div(
        id = "left-pane-stack",
        class = "left-pane-stack",
        div(
          id = "left-pane-chat",
          class = "left-pane-chat",
          chat_panel_ui()
        ),
        div(
          id = "left-pane-resizer",
          class = "pane-resizer pane-resizer-y pane-resizer-sub",
          role = "separator",
          tabindex = "0",
          `aria-label` = "Resize chat and recommendation panels",
          `aria-orientation` = "horizontal"
        ),
        div(
          id = "left-pane-recommend",
          class = "left-pane-recommend",
          chart_recommend_panel_ui()
        )
      )
    ),

    div(
      id = "main-resizer",
      class = "pane-resizer pane-resizer-x",
      role = "separator",
      tabindex = "0",
      `aria-label` = "Resize chat and workspace panels",
      `aria-orientation` = "vertical"
    ),

    div(
      id = "workspace-shell",
      class = "pane-shell pane-right-shell workbench-shell",

      div(
        id = "pane-right-top",
        class = "pane-shell pane-right-top-shell",
        plot_preview_card_ui()
      ),

      div(
        id = "workspace-resizer",
        class = "pane-resizer pane-resizer-y",
        role = "separator",
        tabindex = "0",
        `aria-label` = "Resize preview and workbench panels",
        `aria-orientation` = "horizontal"
      ),

      div(
        id = "pane-right-bottom",
        class = "pane-shell pane-right-bottom-shell",
        card(
          class = "workbench-card",
          style = "height: 100%; display: flex; flex-direction: column; min-height: 0;",
          card_header(
            div(
              class = "d-flex align-items-center justify-content-between gap-2 flex-wrap",
              span("Data & Chart Settings"),
              div(
                class = "pane-header-controls",
                tags$button(
                  type = "button",
                  class = "btn btn-outline-secondary btn-sm pane-ctrl-btn",
                  title = "Minimize workbench panel",
                  `data-pane-action` = "toggle-min",
                  `data-pane-target` = "pane-right-bottom",
                  icon("minus")
                ),
                tags$button(
                  type = "button",
                  class = "btn btn-outline-secondary btn-sm pane-ctrl-btn",
                  title = "Maximize workbench panel",
                  `data-pane-action` = "toggle-max",
                  `data-pane-target` = "pane-right-bottom",
                  icon("expand")
                )
              )
            )
          ),
          div(
            class = "workbench-tab-host",
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
  )
)
