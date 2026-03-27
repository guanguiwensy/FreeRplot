# app.R
# App entrypoint after phase-2 split.

source("global.R")
source("ui.R")
source("server.R")

shinyApp(ui, server)
