#!/usr/bin/env Rscript
if (!require("pacman")) install.packages("pacman")
pacman::p_load_gh("sysrev/srrecogito")
pacman::p_load(shiny, jsonlite, srrecogito)

config <- read_json(Sys.getenv("SR_CONFIG"))
in_file <- fifo(Sys.getenv("SR_INPUT"), open="rt")
out_file <- fifo(Sys.getenv("SR_OUTPUT"), open="wt", blocking=TRUE)
label <- config$labels[[config$current_step$labels[[1]]]]

getDoc <- function () {
  line <- character(0)
  # Read lines until a document is found
  # Write each line to out_file
  while ( TRUE ) {
    # We have to use a non-blocking connection to get correct behavior with
    # partial line reads, but we still need to wait for a full line.
    while ( length(line) == 0 ) {
      line <- readLines(in_file, n=1)
    }
    writeLines(line, con=out_file)
    flush(out_file)
    event <- parse_json(line)

    if ( event$type == "document" ) {
      return(event)
    }
  }
}

docText <- function(doc) {
  doc$data$abstract
}

writeLabelAnswer <- function(input, doc) {
  annotations <- read_recogito(input$annotations)
  data <- list(
    answer=annotations,
    document=unbox(doc$hash),
    label=unbox(label$hash),
    reviewer=unbox(config$reviewer),
    timestamp=unbox(floor(unclass(Sys.time())))
  )
  answer <- list(data=data,type=unbox("label-answer"))
  writeLines(toJSON(answer), con=out_file)
  flush(out_file)
}

tagset <- c("LOCATION", "TIME", "PERSON")
tagcss <- tags$style(HTML(
  ".tag-PERSON   { color:red;   }",
  ".tag-LOCATION { color:green; }",
  ".tag-TIME     { color: gold; }"))

ui <- fluidPage(tags$head(tagcss),
                tags$br(),
                recogitoOutput(outputId = "annotation_text"),
                tags$hr(), 
                actionButton("submit", "Submit"))

# TODO STREAM IN/OUT DOCS https://jeroen.github.io/mongo-slides/#18
server <- function(input, output) {
  state <- reactiveValues(doc=getDoc())
  
  output$annotation_text <- renderRecogito({
    recogito("annotations", text = docText(state$doc), tags = tagset)
  })

  observeEvent(input$submit, {
    writeLabelAnswer(input, state$doc)
    state$doc <- getDoc()
  })
}

shinyApp(ui, server, options=list("port"=config$current_step$port))
