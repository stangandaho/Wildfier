source("init.R")
ui <- fluidPage(
  title = "Wildfier",
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "style.css")
  ),
  shinyjs::useShinyjs(),# Set up shinyjs
  
  div(
    actionButton(inputId = "point_vulture", label = "Point vultures", 
                 style = "position:absolute; margin-top:25%; margin-left:50%"),
    style = "background-color:red; position: relative;"
  )
  
)
