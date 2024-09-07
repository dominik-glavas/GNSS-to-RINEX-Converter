library(shiny)
library(shinyFiles)
library(leaflet)

shinyUI(fluidPage(
  titlePanel("GNSS data converter"),

  sidebarLayout(
    sidebarPanel(
      h3("Log to RINEX Conversion"),
      fileInput("file", "Choose GNSS Log File", accept = c(".txt")),
      div(
        shinyDirButton("directory", "Choose Destination Folder", "Upload"),
        textOutput("selectedRinexDir", inline = TRUE)
      ),
      textInput("output", "Output RINEX File Name", value = "output"),
      actionButton("convertToRinex", "Convert to RINEX"),
      
      hr(),
      
      h3("RINEX to POS Conversion"),
      fileInput("rinexFile", "Choose a RINEX File", accept = c(".*o")),
      fileInput("navFile", "Choose a navigation File", accept = c(".*n")),
      div(
        shinyDirButton("posOutputDir", "Select Output Directory", "Please select a directory"),
        textOutput("selectedPosDir", inline = TRUE)
      ),
      actionButton("convertToPos", "Convert to POS"),
      textOutput("posStatus"),
      
      hr(),
      
      h3("Plot your position file"),
      fileInput("posFile", "Choose a position File", accept = c(".pos")),
      actionButton("plotPos", "Plot")
    ),
    
    mainPanel(
      textOutput("status"),
      leafletOutput("mymap")
    )
  )
))
