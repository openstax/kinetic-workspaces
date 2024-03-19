# Get packages ------------------------------------------------------------
get.package<- function(package){
  if (!package %in% installed.packages()){
    install.packages(package, repos = "http://cran.rstudio.com/")
  }
  invisible(library(package, character.only = TRUE))
}

## packages required

packages.needed <- c("tidyverse", "qualtRics",
                     "jsonlite","kableExtra","lubridate",
                     "patchwork", "psych", "scales")
invisible(sapply(packages.needed, get.package))


# {r read creds}
# Create this file with your qualtrics credential
# Save it to the same folder as this code
# Right click on GH and add to gitignore

qualtrics_cred <- readLines("qualtrics_cred.txt", warn=FALSE)


# {r connect to qualtrics, warning=FALSE}

qualtrics_api_credentials(api_key = qualtrics_cred,
                          base_url = "riceuniversity.iad1.qualtrics.com",
                          install = FALSE)
surveys <- all_surveys()


# Filter to just the Kinetic surveys

kinetic_surveys <- surveys %>%
  filter(grepl("Kinetic", name))


personality_survey_id <- kinetic_surveys %>%
  filter(grepl("Big 5 Personality", name)) %>%
    select(id) %>%
  unlist(use.names = FALSE)


personality_survey <- fetch_survey(surveyID = personality_survey_id, verbose = FALSE, force_request = TRUE)


# Remove test cases, incomplete, minors, spam/previews, and students who spent less than half a second second per question (20qs*.5)

personality_survey <- personality_survey %>%
  filter(!(Status %in% c("Survey Preview", "Spam")),
         Finished == TRUE,
         Q3 == "18 or Older",
         `Duration (in seconds)` >= 10,
         Q1 == "I consent",
         !grepl("staging", return_to_url)) %>%
  mutate(date_recorded = as.Date(RecordedDate))


# Check to make sure there are no repeat participants (aka duplicate research IDs)


write_csv(personality_survey, "big5.csv")
