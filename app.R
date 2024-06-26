#################################### GETTING STARTED ####################################
# # Uncomment for new R user (custom installer designed like pip)
# source("usePackages.R")
# packagesNames <-
#   c(
#     "DT",
#     "DBI",
#     "reticulate",
#     "RMySQL"
#     "odbc"
#     "shiny",
#     "shinyjs",
#     "tidyverse",
#     "rsconnect",
#     "shinydashboard",
#     "shinydashboardPlus"
#   )
# loadPkgs(packagesNames)

library(DT)
library(DBI)
library(shiny)
library(shinyjs)
library(tidyverse)
library(rsconnect)
library(shinydashboard)
library(shinydashboardPlus)

# Create virtual env and install dependencies for python
PYTHON_DEPENDENCIES = c('pip', 'pandas')
virtualenv_dir = Sys.getenv('VIRTUALENV_NAME')
python_path = Sys.getenv('PYTHON_PATH')

reticulate::virtualenv_create(envname = virtualenv_dir, python = python_path)
reticulate::virtualenv_install(virtualenv_dir,
                               packages = PYTHON_DEPENDENCIES,
                               ignore_installed = TRUE)
reticulate::use_virtualenv(virtualenv_dir, required = T)
reticulate::source_python("helper.py")

#################################### HELPER FUNCTIONS ####################################
# SQLite Connection (Bonus Requirement 2)
getDBConnection <- function() {
  conn <- dbConnect(RSQLite::SQLite(), dbname = "champion.db")
  # source("setAWSPassword.R")
  # conn <- dbConnect(
  #   RMySQL::MySQL(),
  #   dbname = "championdb",
  #   host = "championdb.cvvdxaeh2ffd.ap-southeast-1.rds.amazonaws.com",
  #   port = 3306,
  #   user = "champion",
  #   password = getOption("AWSPassword")
  # ) # Free-tier MySQL database hosted using AWS RDS (slower)
  conn
}

# Force close any existing connection if needed during testing stage
dbDisconnectAll <- function() {
  ile <- length(dbListConnections(MySQL()))
  lapply(dbListConnections(MySQL()), function(x)
    dbDisconnect(x))
  cat(sprintf("%s connection(s) closed.\n", ile))
}

# Extract the tables from database
getTeamInformation <- function() {
  conn <- getDBConnection()
  information <- dbReadTable(conn, "information")
  dbDisconnect(conn)
  information
}

getTeamMatches <- function() {
  conn <- getDBConnection()
  matches <- dbReadTable(conn, "matches")
  dbDisconnect(conn)
  matches
}

# Delete tables if exist from database
deleteTables <- function() {
  conn <- getDBConnection()
  dbSendQuery(conn, "DROP TABLE IF EXISTS champion.information;")
  dbSendQuery(conn, "DROP TABLE IF EXISTS champion.matches;")
  dbDisconnect(conn)
}

# Modal to show error if the user types a wrongly or empty text input
WronginputModal <- function() {
  div(id = "wronginputModal",
      modalDialog(
        easyClose = FALSE,
        title = strong("Error Message"),
        h5("Wrong text format!"),
        footer = tagList(modalButton(h5(strong(
          "Cancel"
        ))))
      ))
}

# Modal to show correct text input
CorrectinputModal <- function() {
  div(id = "correcinputModal",
      modalDialog(
        easyClose = FALSE,
        title = strong("Successful Input"),
        h5("Proceed with Check!"),
        footer = tagList(modalButton(h5(strong(
          "Cancel"
        ))))
      ))
}

#################################### UI ####################################
ui <- dashboardPage(
  skin = "red",
  dashboardHeader(title = strong("Champions Web Application")),
  dashboardSidebar(
    useShinyjs(),
    sidebarMenu(id = "tabs",
                menuItem(strong("Input Text"), tabName = "start")),
    br(),
    tags$script(
      JS(
        "document.getElementsByClassName('sidebar-toggle')[0].style.visibility = 'hidden';"
      )
    ),
    textAreaInput(
      "team_info",
      "Team Information",
      value = "",
      placeholder = "(Example)\nteamA 01/04 1\nteamB 02/05 1\nteamC 03/06 1\nteamD 04/06 1",
      width = '100%',
      rows = 5,
      resize = "none"
    ),
    textAreaInput(
      "team_matches",
      "Match Results",
      value = "",
      placeholder = "(Example)\nteamA teamB 0 1\nteamA teamC 1 3\nteamA teamD 2 2\nteamA teamE 2 4",
      width = '100%',
      rows = 5,
      resize = "none"
    ),
    actionButton("check_valid",
                 h6(strong(
                   "Step 1: Check Valid Input"
                 )),
                 style = "color: #fff; background-color: #AE0404; border-color: #AE0404"),
    br(),
    hidden(
      actionButton("check_now",
                   h6(strong(
                     "Step 2: Run Evaluation"
                   )),
                   style = "color: #fff; background-color: #AE0404; border-color: #AE0404")
    )
  ),
  dashboardBody(tabItems(tabItem(
    tabName = "start",
    fluidRow(useShinyjs(),
             class = "center",
             column(
               width = 12,
               h2(strong("Results of Evaluation")),
               DTOutput("table"),
               hidden(
                 actionButton("clear_results",
                              h6(strong("Reset Everything")),
                              style = "color: #fff; background-color: #AE0404; border-color: #AE0404")
               )
             ))
  )))
)

#################################### SERVER ####################################
server <- function(input, output, session) {
  # Initialize server values
  vals <- reactiveValues(result_values = NULL)
  
  # Handle reading of the multi-line text inputs and push to database (REQUIREMENT 1/2)
  read_input_texts <- function(input_1, input_2) {
    # Try catch for invalid input handling
    tryCatch({
      # Add the multi-line inputs to data frames
      df_1 <- data.frame()
      df_2 <- data.frame()
      lines_1 <- unlist(str_split(input_1, "\n"))
      lines_2 <- unlist(str_split(input_2, "\n"))
      
      for (line in lines_1) {
        words <- unlist(str_split(line, " "))
        df_1 <- rbind(df_1, words)
      }
      for (line in lines_2) {
        words <- unlist(str_split(line, " "))
        df_2 <- rbind(df_2, words)
      }
      
      # Remove any empty words
      df_1 <- df_1[!apply(df_1 == "", 1, all),]
      df_2 <- df_2[!apply(df_2 == "", 1, all),]
      
      # Write to DB
      conn <- getDBConnection()
      dbWriteTable(conn,
                   "information",
                   df_1,
                   overwrite = TRUE,
                   row.names = FALSE)
      dbWriteTable(conn,
                   "matches",
                   df_2,
                   overwrite = TRUE,
                   row.names = FALSE)
      dbDisconnect(conn)
      showModal(CorrectinputModal())
      shinyjs::show("check_now")
    },
    error = function(e) {
      showModal(WronginputModal())
    })
  }
  
  # Proceed to check the validity of the input texts (REQUIREMENT 1/2)
  observeEvent(input$check_valid, {
    read_input_texts(input$team_info, input$team_matches)
  })
  
  # Proceed with evaluation and output the results (REQUIREMENT 3)
  observeEvent(input$check_now, {
    information <- getTeamInformation()
    matches <- getTeamMatches()
    
    # Convert string columns to numeric
    information[, 3] <- as.numeric(information[, 3])
    matches[, 3] <- as.numeric(matches[, 3])
    matches[, 4] <- as.numeric(matches[, 4])
    
    # Do the evaluation and render the results
    vals$result_values <- get_rankings(information, matches)
    output$table <-
      renderDT(
        vals$result_values %>% datatable(
          colnames = c(
            'Group Number',
            'Team Name',
            'Ranking',
            'Next Round',
            'Registration Date',
            'Scores',
            'Alternative Scores',
            'Total Goals'
          ),
          option = list(pageLength = 12),
          rownames = FALSE
        ) %>%
          formatStyle(
            columns = c("Team Name", "Ranking", "Next Round"),
            valueColumns = "Next Round",
            color = styleEqual(c("Yes", "No"), c("green", "red"))
          ) %>%
          formatStyle(
            "Group Number",
            target = "row",
            backgroundColor = styleEqual(c(1, 2), c('white', 'lightgray'))
          )
      )
    shinyjs::show("clear_results")
    if (input$check_now)
      show("table")
    else
      hide("table")
  })
  
  # Proceed to reset everything (REQUIREMENT 4)
  observeEvent(input$clear_results, {
    updateTextInput(session, "team_info", value = "")
    updateTextInput(session, "team_matches", value = "")
    if (input$clear_results)
      hide("table")
    else
      show("table")
    shinyjs::hide("check_now")
    shinyjs::hide("clear_results")
    deleteTables()
  })
}

shinyApp(ui, server)

# (BONUS REQUIREMENT 1 - Deployed by publishing)
# Deployed to:
# https://samuelsim.shinyapps.io/TAPapplication/
