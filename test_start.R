setwd("D:/coding/r-plot-ai")
options(shiny.trace = FALSE, shiny.error = print)
library(shiny)
source("global.R")

# Override the UI and server from files
ui_env <- new.env(parent = globalenv())
server_env <- new.env(parent = globalenv())
source("ui.R", local = ui_env)
source("server.R", local = server_env)

app <- shinyApp(ui = ui_env$ui, server = server_env$server)
cat("Starting app on port 9999...\n")
runApp(app, port = 9999, launch.browser = FALSE, quiet = FALSE)
