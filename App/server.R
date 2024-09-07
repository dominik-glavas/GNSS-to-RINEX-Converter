library(shiny)
library(shinyFiles)
library(here)
library(git2r)
library(ggplot2)
library(leaflet)
library(lubridate)

# Set maximum upload size to 150 MB
options(shiny.maxRequestSize = 150 * 1024^2)

shinyServer(function(input, output, session) {
  volumes <- getVolumes()
  
  # Set up file and directory choose dialogs
  shinyFileChoose(input, "file", roots = volumes(), filetypes = c('txt'))
  shinyDirChoose(input, "directory", roots = volumes(), session = session)
  
  output$selectedRinexDir <- renderText({
    req(input$directory)
    selected_dir <- parseDirPath(volumes, input$directory)
    return(selected_dir)
  })
  
  output$selectedPosDir <- renderText({
    req(input$posOutputDir)
    selected_dir <- parseDirPath(volumes, input$posOutputDir)
    return(selected_dir)
  })
  
  # Log to RINEX Conversion
  observeEvent(input$convertToRinex, {
    req(input$file)
    req(input$directory)
    
    # Extract file and directory paths
    selected_file <- input$file$datapath
    
    # Extract directory info
    dir_info <- parseDirPath(volumes, input$directory)
    selected_directory <- dir_info[1]
    
    # Ensure selected_directory is not empty and is correctly extracted
    if (length(selected_directory) == 0) {
      output$status <- renderText("No directory selected.")
      return()
    }
    
    # Construct the new directory path
    new_directory <- file.path(selected_directory, "tmp")

    new_directory <- gsub('/', '\\\\', new_directory)

    #Create the new directory
    dir.create(new_directory, recursive = TRUE, mode = "0777")
    
    # Get the input and output file paths
    output_file <- paste0(input$output, ".txt")
    
    tmp_destination <- file.path(new_directory, output_file)
    
    # Move the file
    file.rename(selected_file, tmp_destination)
    
    # Define the path to the executable
    executable <- here("..", "Repo", "csv2rinex(Double click to run).exe")
    quoted_exe <- shQuote(executable)
    
    # Check if the executable file exists
    if (file.exists(quoted_exe)) {
      output$status <- renderText("Executable file already exists.")
    } else {
      output$status <- renderText("Executable file not found. Cloning repository...")
      
      # Define the repository URL and local path to clone to
      repo_url <- "https://github.com/iGNSS/Convert-from-Google-gnsslogger-to-standard-RINEX-3.04-observation-files-for-Android-smartphones.git"
      clone_path <- here("..", "Repo")
      
      dir.create(clone_path, recursive = TRUE, mode = "0777")
      tryCatch({
        # Clone the repository
        clone(repo_url, clone_path)
        
        output$status <- renderText("Repository cloned successfully.")
      }, error = function(e) {
        output$status <- renderText(paste("Cloning failed:", e$message))
      })
    }

      # Construct the command string using paste()
    command <- paste(quoted_exe, new_directory)

    tryCatch({
      # Run the command and capture the output
      output_message <- system(command, intern = TRUE)
      
    }, error = function(e) {
      output$status <- renderText(paste("Conversion failed:", e$message))
    })
    
    file_list <- list.files(new_directory, pattern = paste0("\\", ".*o", "$"), full.names = TRUE)
    
    file_name <- basename(file_list)
    
    # Construct the destination path
    destination_path <- file.path(selected_directory, file_name)
    
    if (file.exists(destination_path)) {
      output$status <- renderText("File already exists.")
    } else {
      file.rename(file_list, destination_path)
      if (file.exists(destination_path)) {
        output$status <- renderText("File successfully converted!")
      }
    }
    
    unlink(new_directory, recursive = TRUE)
  })
  
  # RINEX to POS Conversion
  shinyDirChoose(input, "posOutputDir", roots = volumes(), session = session)
  
  observeEvent(input$convertToPos, {
    req(input$rinexFile)  # Ensure a RINEX file is uploaded
    req(input$navFile)  # Ensure a navigation file is uploaded
    req(input$posOutputDir)  # Ensure an output directory is selected
    
    dir_info <- parseDirPath(volumes, input$posOutputDir)
    selected_directory <- dir_info[1]
    
    new_directory <- file.path(selected_directory, "tmp")
    
    dir.create(new_directory, recursive = TRUE, mode = "0777")
    
    setwd(new_directory)
    
    # Get the file path and directory path
    tmp_rinex <- input$rinexFile$datapath
    rinex_file <- file.path(new_directory, input$rinexFile$name)
    file.rename(tmp_rinex, rinex_file)
    
    tmp_nav <- input$navFile$datapath
    nav_file <- file.path(new_directory, input$navFile$name)
    file.rename(tmp_nav, nav_file)
    
    # Define the output POS file name and path
    pos_file_name <- paste0(tools::file_path_sans_ext(input$rinexFile$name), ".pos")
    pos_file_path <- file.path(selected_directory, pos_file_name)
    
    # Path to the rnx2rtkp executable
    rnx2rtkp_executable <- here("..", "RTKLIB", "bin", "rnx2rtkp.exe")
    
    # Check if the executable file exists
    if (file.exists(rnx2rtkp_executable)) {
      output$status <- renderText("Executable file already exists.")
    } else {
      output$status <- renderText("Executable file not found. Cloning repository...")
      
      # Define the repository URL and local path to clone to
      repo_url <- "https://github.com/tomojitakasu/RTKLIB_bin.git"
      clone_path <- here("..", "RTKLIB")
      
      dir.create(clone_path, recursive = TRUE, mode = "0777")
      tryCatch({
        # Clone the repository
        clone(repo_url, clone_path)
        
        output$status <- renderText("Repository cloned successfully.")
      }, error = function(e) {
        output$status <- renderText(paste("Cloning failed:", e$message))
      })
    }
    
    # Construct the command
    command <- paste(
      shQuote(rnx2rtkp_executable),
      "-o", shQuote(pos_file_path), # Output file
      "-p", "0",
      shQuote(rinex_file),          # Rover RINEX observation file
      shQuote(nav_file)            # RINEX navigation file (.n file)
    )
    
    # Execute the command
    result <- tryCatch({
      system(command, intern = TRUE)
    }, error = function(e) {
      return(paste("Error:", e$message))
    })
    
    # Output status
    if (file.exists(pos_file_path)) {
      output$posStatus <- renderText(paste("POS file created successfully at", pos_file_path))
    } else {
      output$posStatus <- renderText(paste("Conversion failed:", result))
    }
    
    setwd(here())
    
    unlink(new_directory, recursive = TRUE)
    
    output$processLogs <- renderText(paste(result, collapse = "\n"))
  })
  
  # Plot your position file
  observeEvent(input$plotPos, {
    req(input$posFile)
    
    pos_file <- input$posFile$datapath
    
    # Read the .pos file (assuming space-delimited)
    pos_data <- read.table(pos_file, skip = 8, header = FALSE, fill = TRUE)
    
    colnames(pos_data) <- c("week", "seconds", "latitude", "longitude", "height", "Q", "ns", "sdn", "sde", "sdu", "sdne", "sdeu", "sdun", "age", "ratio")
    
    # Extract relevant columns (assuming latitude, longitude, and height)
    lat <- pos_data$latitude  # Latitude
    lon <- pos_data$longitude  # Longitude
    height <- pos_data$height  # Height
    
    # Create a leaflet map
    output$mymap <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        addCircles(lng = lon, lat = lat, weight = 1, radius = 2) %>%
        addMarkers(lng = lon[1], lat = lat[1], popup = "Start") %>%
        addMarkers(lng = lon[length(lon)], lat = lat[length(lat)], popup = "End")
    })
  })
})
