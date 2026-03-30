# =============================================================================
# File   : R/ui/panel_chat.R
# Purpose: Left-column chat panel UI — AI conversation area, suggestion card
#          slot, intent preview slot, and the message input row.
#          Mirrors server logic in R/modules/mod_ai_chat.R.
#
# Exports:
#   chat_panel_ui()
#     Returns a bslib card containing the full left panel.
#     No parameters — all state is managed server-side via rv.
# =============================================================================

chat_panel_ui <- function() {
  card(
    class = "chat-card pane-card",
    style = "height: 100%; display: flex; flex-direction: column; overflow: hidden;",

    card_header(
      style = "flex-shrink: 0;",
      div(
        class = "d-flex align-items-center justify-content-between gap-2 flex-wrap",
        div(
          class = "d-flex align-items-center gap-2 flex-wrap",
          div("AI Chart Advisor"),
          tags$small(class = "text-muted", "Describe your data and visualisation goal")
        ),
        div(
          class = "pane-header-controls",
          tags$button(
            type = "button",
            class = "btn btn-outline-secondary btn-sm pane-ctrl-btn",
            title = "Minimize AI chat",
            `data-pane-action` = "toggle-sub-min",
            `data-pane-target` = "left-pane-chat",
            icon("minus")
          ),
          tags$button(
            type = "button",
            class = "btn btn-outline-secondary btn-sm pane-ctrl-btn",
            title = "Maximize AI chat",
            `data-pane-action` = "toggle-sub-max",
            `data-pane-target` = "left-pane-chat",
            icon("expand")
          )
        )
      )
    ),

    # Scrollable message list
    div(
      id    = "chat-container",
      style = paste0(
        "flex: 1 1 auto; overflow-y: auto; padding: 12px; ",
        "background: #f8f9fa; margin: 0 4px 4px; min-height: 0;"
      ),
      uiOutput("chat_messages_ui")
    ),

    # AI recommendation card (shown when LLM returns structured suggestion)
    uiOutput("suggestion_ui"),

    # Intent preview card (shown for medium-confidence intent, awaits confirm)
    uiOutput("intent_preview_ui"),

    # Input row: textarea + Send / Clear
    div(
      class = "chat-input-wrapper",
      div(
        class = "d-flex gap-2",
        textAreaInput(
          "user_input",
          label       = NULL,
          value       = "",
          placeholder = "Describe your data and chart needs (Enter to send, Shift+Enter for newline)",
          rows        = 3,
          width       = "100%"
        ),
        div(
          class = "d-flex flex-column gap-2",
          actionButton("send_btn",  "Send",  class = "btn btn-primary btn-sm",          icon = icon("paper-plane")),
          actionButton("undo_btn",  "Undo",  class = "btn btn-outline-warning btn-sm",  icon = icon("rotate-left")),
          actionButton("clear_btn", "Clear", class = "btn btn-outline-secondary btn-sm")
        )
      )
    )
  )
}
