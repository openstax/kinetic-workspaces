

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

# Create this file with your qualtrics credential
# Save it to the same folder as this code
# Right click on GH and add to gitignore

qualtrics_cred <- readLines("qualtrics_cred.txt", warn=FALSE)


qualtrics_api_credentials(api_key = qualtrics_cred,
                          base_url = "riceuniversity.iad1.qualtrics.com", #<YOUR-QUALTRICS_BASE_URL>; yourorganizationid.yourdatacenterid.qualtrics.com
                          install = FALSE)

# Sys.getenv("QUALTRICS_API_KEY")


# Get all surveys associated with this qualtrics account

surveys <- all_surveys()


# Filter to just the Kinetic surveys

kinetic_surveys <- surveys %>%
  filter(grepl("Kinetic", name))


# Select a specific Kinetic survey; science knowledge in this case


science_survey_id <- kinetic_surveys %>%
  filter(grepl("Kinetic-Science Knowledge Survey", name)) %>%
    select(id) %>%
      unlist(use.names = FALSE)



# Get science survey data

science_survey <- fetch_survey(surveyID = science_survey_id, verbose = FALSE, include_display_order = FALSE, label=FALSE, convert=FALSE, force_request = TRUE)


#How many are NA's?

#table(science_survey$is_testing, useNA = "always")


# Remove test cases, incomplete, minors, non-consents

science_survey <- science_survey %>%
  filter(Finished == 1,
         Q23 == 2,
         Status != 8,
         consent == TRUE,
         is_testing == FALSE)


# If a person has completed the test, but they have an NA in the score column, recode to 0

science_survey <- science_survey %>%
  mutate(SC0 =
           ifelse(Finished == TRUE & is.na(SC0), 0, SC0))


# Check to make sure there are no repeat participants (aka duplicate research IDs)

# test <- science_survey %>%
#   count(research_id) %>%
#     filter(n > 1)


# Rename the three score categories

science_survey <- science_survey %>%
  rename(
     LabScore =  SC1,
     MeasurementScore = SC2,
     ClimateScore = SC3)


# Convert raw scores to percentages bc there are different numbers of problems in each category

science_survey <- science_survey %>%
    mutate(
     LabScore =  LabScore/6,
     MeasurementScore =  MeasurementScore/5,
     ClimateScore = ClimateScore/7,
     SC0 = SC0/18)



write_csv(science_survey, "science-knowledge.csv")
