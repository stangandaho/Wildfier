# Call model
source("init.R")
mdl <- ult$YOLO("./models/best.onnx", task = "segment")

server <- function(input, output, session) {
  access_data <- reactiveValues(path = NULL)
  options(shiny.maxRequestSize=30*1024^2)
  
  observeEvent(input$point_vulture, {
    
    showModal(
      modalDialog(tagList(
        radioButtons("src_type", "Single/Mutilple images", choices = c("Image", "Folder"), inline = T),
        
        conditionalPanel("input.src_type == 'Image'",
                         tagList(
                           textInput("image_url", "URL", placeholder = "htts://example.com/animage.jpeg"),
                           fileInput("image_path", label = "Select an image", 
                                     buttonLabel = "Browse", placeholder = "No image selected",
                                     accept = c(".bmp", ".dng", ".jpeg", ".jpg", "mpo", ".png", ".tif", ".tiff", ".webp", ".pfm"))
                           )),
        conditionalPanel("input.src_type == 'Folder'",
                         textInput("folder_path", "Folder path", placeholder = "D://camtrap/data")
        ),
        numericInput(inputId = "mct", "Minimum confidence threshold", value = 0.7, min = 0, max = 1, step = 0.01),
        disabled(actionButton("process_seg", "Process", icon = icon("play")))
        
      ) ,title = "Process Vulture Detection", footer = modalButton("Cancel"), size = "m")
    )}
  )
    
    # Hide browse if url is provided
    observe({
      req(input$src_type)
      if (input$image_url != "") {
        access_data$path <- input$image_url
        shinyjs::hide("image_path", anim = TRUE)
      }else{
        shinyjs::show("image_path")
        access_data$path <- NULL
      }
    })
    
    # Hide URL if image path is provided
    observe({
      req(input$image_path)
      image_access <- input$image_path
      image_path <- image_access$datapath
      if (image_path != "") {
        access_data$path <- image_path
        shinyjs::hide("image_url", anim = TRUE)
      }else{
        shinyjs::show("image_url")
        access_data$path <- NULL
      }
    })
    
    
    # Folder selection
    folder_path <- reactive(
      input$folder_path
    )
    observe({
      req(folder_path())
      if (folder_path() != "" | !is.null(folder_path())) {
        access_data$path <- folder_path()
      }else{
        access_data$path <- NULL
      }
    })
    
    # Activate or disactive process button
    observe({
      if (!is.null(access_data$path)) {
        shinyjs::enable("process_seg")
      }else{
        shinyjs::disable("process_seg")
      }
    })
    
    ## PROCESS SEGMENTATION
    observeEvent(input$process_seg, {
      showModal(
        modalDialog(
          shinycssloaders::withSpinner(
            DT::DTOutput("seg_df", height = "70%", width = "100%"),
            type = 5, color = "#6C5B7B", color.background = "gray80", size = 0.3
          ),
          size = "xl", title = "Detection table",
          footer = tagList(
            shinyjs::disabled(downloadButton("download_detect_df", "Save")),
            footer = modalButton("Close")
          )
        )
      )
      
      if (dir.exists("./results")) {
        unlink("./results", recursive = T)
      }
      
      if(fs::is_dir(access_data$path)) {
        img_path <- list.files(access_data$path, full.names = T)
      }else{
        img_path <- access_data$path
      }
        
      # main loop
      seg_df <- data.frame()
      for (path in img_path) {
        
        tryCatch({
          prd <- mdl$predict(path, retina_masks = T, conf = input$mct, imgsz = c(672, 672),
                             project = "./", name = "results/result", save = T)
          #Metadata of
          gps = piexif$load(path)["GPS"]
          date_time = piexif$load(path)["Exif"]
          
          if (length(date_time[[1]]) == 0) {
            lon <- NA
            lat <- NA
            dat <- NA
            hour <- NA
          }else{
            deg_lon = gps$GPS$`2`[[1]]; minutes_lon = gps$GPS$`2`[[2]]; sec_lon = gps$GPS$`2`[[3]]
            deg_lat = gps$GPS$`4`[[1]]; minutes_lat = gps$GPS$`4`[[2]]; sec_lat = gps$GPS$`4`[[3]]
            # 
            lon = deg_lon[[1]]/deg_lon[[2]] + (minutes_lon[[1]]/minutes_lon[[2]])/60 + (sec_lon[[1]]/sec_lon[[2]])/3600
            lat = deg_lat[[1]]/deg_lat[[2]] + (minutes_lat[[1]]/minutes_lat[[2]])/60 + (sec_lat[[1]]/sec_lat[[2]])/3600
            lon = round(lon, 6)
            lat = round(lat, 6)
            
            date_time = strsplit(as.character(date_time$Exif$`36867`), " ")
            
            
            dat <- date_time[[1]][1]
            hour <- date_time[[1]][2]
          }
          
          
        }, error = function(e)print(e))
        
        
        tryCatch({
          prd <- prd[[1]]
          nms <- prd$names
          save_dir <- file.path(getwd(), "results/result")
          #print(prd)
          
          for (r in 0:(length(prd) - 1)){
            confident <- prd[r]$boxes$conf
            confident <- as.numeric(gsub("[^0-9.]", "", as.character(confident[0])))
            cls <- prd[r]$boxes$cls
            cls <- as.character(as.double(gsub("[^0-9.]", "", as.character(cls[0]))))
            class_name <- nms[[cls]]
            
            eddf <- data.frame(
              image = path,
              prediction = save_dir,
              species = class_name,
              confident = confident,
              longitude = lon,
              latitude = lat,
              date = dat,
              hour = hour
            )
            
            seg_df <- rbind(seg_df, eddf)
          }

        }, error = function(e)paste(e))
        
      }
      
      # Move detection image to root of result
      for (d in list.dirs(paste0(getwd(), "/results"), full.names = T, recursive = F)) {
        for (f in list.files(d, full.names = T)) {
          file.copy(from = f, to = paste0(getwd(), "/results/", basename(f)), 
                    overwrite = T, copy.date = T)
          unlink(d, recursive = T)
        }
        
      }
      
      if (nrow(seg_df) == 0) {
        seg_df <- data.frame("No detection")
        colnames(seg_df) <- NULL
      }
      
      output$seg_df <- DT::renderDT({
        input$process_seg
        Sys.sleep(1.5)
        seg_df
      },options = list(scrollX = TRUE, scrollY = TRUE, lengthChange = FALSE, pageLength = 5),
      selection = "none", rownames = FALSE, width = "75%", 
      height = "75%")
      
      
      # Download
     observe({
       req(input$process_seg)
       if (seg_df[[1]][1] != "No detection") {
         shinyjs::enable("download_detect_df")
         
         output$download_detect_df <- downloadHandler(
           filename = function() {
             paste0("detection_", Sys.Date(),".csv")
           },
           content = function(file) {
             write.csv(seg_df, file, row.names = FALSE)
           }
         )
         
       }
     })
      
    })
    onStop(fun = function() {rm(list = ls())}, session = session)
}

