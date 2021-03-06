# UI file for Shiny App phenoRemote
# Initiate the UI
ui = fluidPage(shinyjs::useShinyjs(), includeCSS("./Aesthetics/styles.css"),
               mainPanel(
                 bsModal("getDataPopup",
                         "Get Data for Analysis", "getData",
                         tags$head(tags$style("#window .modal{backdrop: 'static'}")),
                         size = "medium",
                         checkboxInput("localDownload", "Download Data Locally", value = TRUE),
                         selectInput('dataTypes_get', 'Data Types', multiple = TRUE, selected = c('NDVI', 'GCC', 'EVI', 'Transition Dates'), c('NDVI', 'EVI', 'GCC', 'Transition Dates')),
                         selectInput('phenocamFrequency', 'GCC Frequency', multiple = FALSE, selected = '3 day', c('1 day', '3 day')),
                         actionButton('getDataButton', 'Get Data'),
                         tags$head(tags$style("#getDataPopup .modal-footer{ display:none}")))
                 ,
                 bsModal("plotDataPopup",
                         "Select Plot Data", "plotRemoteData",
                         tags$head(tags$style("#window .modal{backdrop: 'static'}")),
                         size = "small",
                         selectInput('dataTypes_plot', 'Data Types', multiple = TRUE, selected = c('NDVI', 'GCC'), c('NDVI', 'EVI', 'GCC', 'Transition Dates')),
                         selectInput('pixelTypes', 'Pixel Resolution', c('250m', '500m')),
                         sliderInput('dataDateRange', 'Date start to end',
                                     min = as.Date('2000-01-01'),
                                     max = Sys.Date(),
                                     value = c(as.Date('2000-01-01'), Sys.Date())),
                         actionButton('plotDataButton', 'Plot Data'),
                         helpText(id = 'noPixelWarning', 'No Pixels selected')
                         # actionButton('genDF', 'Download Data')
                         )
               ,
               bsModal("downloadDataPopup",
                       "Download Data from Plot", "downloadData",
                       tags$head(tags$style("#window .modal{backdrop: 'static'}")),
                       size = "medium",
                       selectInput('dataTypes_download', 'Data Types',selected = 'All Data', multiple = TRUE, c('All Data','NDVI', 'EVI', 'GCC', 'Transition Dates')),
                       downloadButton('downloadDataButton', 'Download'),
                       tags$head(tags$style("#getDataPopup .modal-footer{ display:none}")))
               ,
               navbarPage("PhenoSynth-development phase", id="navbar",

                          tabPanel("Site explorer",

                                   div(class="outer",

                                       tags$head(# Include custom CSS
                                                 includeCSS("./Aesthetics/styles.css"),
                                                 includeScript("./Aesthetics/gomap.js")
                                                 ),

                        # If not using custom CSS, set height of leafletOutput to a number instead of percent
                        leafletOutput("map", width="100%", height="100%"),

                        textOutput("See Field of View (FOV)"),

                        # Shiny versions prior to 0.11 should use class = "modal" instead.
                        absolutePanel(id = "controls", class = "panel panel-default", fixed = TRUE,
                                      draggable = FALSE, top = 70, left = "auto", right = 20, bottom = "auto",
                                      width = 320, height = "auto", style="z-index:600;",
                                      h2(id = 'explorerTitle', "Site Explorer"),
                                      h2(id = 'analyzerTitle', "Site Analyzer"),
                                      actionButton('siteExplorerMode', 'Back to Site Explorer'),
                                      actionButton("usZoom", "Show Contiguous US"),
                                      actionButton('showSites', 'Show all Sites'),
                                      actionButton("siteZoom", "Zoom to Selected Site"),
                                      selectInput("filterSites", 'Filter Sites by', site_filters, selected = 'All', multiple = FALSE),
                                      selectInput("site", "Phenocam Site Name", site_names, selected = 'acadia'),
                                      actionButton('analyzerMode', 'Enter Analyze Mode'),
                                      checkboxInput("drawROI", "See PhenoCam Field of View (FOV)", value = FALSE),
                                      sliderInput("azm", "Toggle FOV:", min = 0, max = 360, value = 0.0 , step = 5),
                                      checkboxInput('drawImage', "Show site PhenoCam Image", value = TRUE),
                                      checkboxInput("drawImageROI", "Show ROI on PhenoCam Image", value = FALSE),
                                      selectInput('pftSelection', 'PhenoCam ROI Vegetation', ''),
                                      checkboxInput("highlightPixelMode", "Select Landcover Pixels (500m resolution)", value = FALSE),
                                      checkboxInput("highlightPixelModeNDVI", "Select MODIS NDVI Pixels (250m resolution)", value = FALSE),
                                      actionButton('getData', 'Import Data'),
                                      actionButton('plotRemoteData', 'Plot Data'),
                                      actionButton('clearPixels', 'Clear Pixels')
                                                                            ),

                        absolutePanel(id = 'currentImage', class = 'panel panel-default', #fixed = TRUE,
                                      draggable = TRUE,  top = 'auto', left = 250, right = 'auto' , bottom = 10,
                                      width = 375, height = 225, style="z-index:500;",
                                      actionButton('showImage', '-', value=FALSE),
                                      actionButton('showROIimage', 'Overlay selected ROI'),
                                      tags$div(id = 'image')
                                      ),

                        absolutePanel(id = 'plotpanel', class = 'panel panel-default', #fixed = TRUE,
                                      draggable = TRUE,  top = 'auto', left = 400, right = 'auto' , bottom = 20,
                                      width = 375, height = 225, style="z-index:500;",
                                      actionButton('hidePlot', '-', value=FALSE),
                                      plotOutput("currentPlot", height = 225)
                                      ),

                        absolutePanel(id = 'mouseBox', class = 'panel panel-default', fixed = TRUE,
                                      draggable = FALSE,  top = 'auto', left = 'auto', right = 20 , bottom = 85,
                                      width = 240, height = 40, style="z-index:500;",
                                      verbatimTextOutput("mouse")
                                      ),

                        absolutePanel(id = 'siteTitle', class = 'panel panel-default', fixed = FALSE, style="z-index:500;",
                                      draggable = FALSE,  top = 25, left = 'auto', right = 320 , bottom = 'auto',
                                      div(id = 'analyzerHeader', uiOutput("analyzerTitle"))
                                      ),

                        tags$div(id="cite",
                                 ' ', tags$em(''), ' '#eventually we can put some APIS text here so I'm saving it for now
                                )
                            ) # close div outer
                        ), # close tab panel


           # tabPanel('pAOI Management',
           # 
           #          tags$div(id='pAOItab'),
           #          selectInput('shapefiles', "Select Shapefile", c('None')),
           #          actionButton('saveshp', 'Save Shapefile'),
           #          br(),
           #          br(), br(),
           # 
           # 
           #          # Attempting to build a chart here for the shapefiles, mihgt move it to a new tab at
           #          #   some point......
           #          DTOutput("pAOIchart")
           # 
           #         ),

           # tabPanel('User Guide',
           #          includeMarkdown('UserGuide.Rmd')
           #          ),

           tabPanel('Phenocam Metadata',
                    tableOutput("phenoTable")
                    
                   ),

           tabPanel('Plot Data', value = 'PlotPanel',
                    plotlyOutput("data_plot", height = 600, width = 1300, inline =TRUE),
                    # verbatimTextOutput("event_plot")
                    actionButton('downloadData', 'Download Dataframe')
                    
           ),

           conditionalPanel("false", icon("crosshair"))
      )
  )
)
