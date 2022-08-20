#!/usr/bin/env Rscript

# DEPENDENCIES, CONFIGURATION AND SOCKETS =======================================================
if (!require("pacman")) install.packages("pacman")
pacman::p_load_gh("sysrev/srrecogito")
pacman::p_load(shiny, jsonlite, srrecogito)

cfg <- read_json(Sys.getenv("SR_CONFIG"))

mksock <- purrr::compose(~ socketConnection(.[[1]],.[[2]],blocking=T), ~ strsplit(.,":")[[1]])
sr_output <- mksock(Sys.getenv("SR_OUTPUT"),":")
sr_input  <- mksock(Sys.getenv("SR_INPUT"),":")

# HELPER FUNCTIONS  =============================================================================
getDoc <- function(){
  safejs <- purrr::possibly(jsonlite::parse_json,otherwise=NULL)

  while(TRUE){
    line  <- readLines(sr_input,n=1)  
    event <- safejs(line,auto_unbox=T)
    if(!is.null(event) && event$type=="document"){
      writeLines(line, con=sr_output)
      return(event) 
    }
  }
}

writeLabelAnswer <- function(input, d){
  lbl  <- cfg$labels[[cfg$current_step$labels[[1]]]]$hash
  anno <- recogito::read_recogito(input$annotations)
  ts   <- floor(unclass(Sys.time()))
  data <- list(answer=anno, document=d$hash, label=lbl, reviewer=cfg$reviewer, timestamp=ts)

  ans  <- jsonlite::toJSON(list(data=data, type="label-answer", auto_unbox=T))
  writeLines(ans, con=sr_output)
}

# HTML TEMPLATE  =================================================================================
tagset <- c("LOCATION", "TIME", "PERSON")
colors <- c("red","green","gold")
tagcss <- tags$style(HTML(glue::glue("\n\n.tag-{tagset} {{ color:{colors}; }}\n\n")))

ui <- fluidPage(
  tags$head(tagcss),tags$br(),
  recogitoOutput(outputId = "annotation_text"),tags$hr(), 
  actionButton("submit", "Submit"))

server <- function(input, output){
  state <- reactiveValues(doc=getDoc())
  
  output$annotation_text <- renderRecogito({
    recogito("annotations", text = state$doc$data$abstract, tags = tagset)
  })

  observeEvent(input$submit, {
    writeLabelAnswer(input, state$doc)
    state$doc <- getDoc()
  })
}

shinyApp(ui, server, options=list("port"=cfg$current_step$port))
