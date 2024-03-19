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

# Sys.getenv("QUALTRICS_API_KEY")


# Get all surveys associated with this qualtrics account

surveys <- all_surveys()


# Filter to just the Kinetic surveys

kinetic_surveys <- surveys %>%
  filter(grepl("Kinetic", name))


# Select a specific Kinetic survey; riasec in this case


riasec_survey_id <- kinetic_surveys %>%
  filter(grepl("RIASEC \\(Survey\\)", name)) %>%
    select(id) %>%
      unlist(use.names = FALSE)


# Get riasec survey data

riasec_survey <- fetch_survey(surveyID = riasec_survey_id, verbose = FALSE, force_request = TRUE, include_display_order = FALSE)


# Remove test cases, incomplete, minors, students who spent less than .5 second per question (42qs*.5), staging in return URL, and status is not "survey preview"

riasec_survey <- riasec_survey %>%
  filter(!(Status %in% c("Survey Preview", "Spam")),
         Finished == TRUE,
         Q53 == "18 or Older",
         `Duration (in seconds)` >= 21,
         Q60 == "I consent",
         !grepl("staging", return_to_url)) %>%
  mutate(date_recorded = as.Date(RecordedDate))


write_csv(riasec_survey, "riasec.csv")
