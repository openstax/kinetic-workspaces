library(qualtRics)

# Check for the necessary arguments and environmental variables
if (length(commandArgs(trailingOnly = TRUE)) < 1) {
  stop("Survey ID was not provided as an argument.")
}

if (Sys.getenv("QUALTRICS_API_KEY") == "") {
  stop("QUALTRICS_API_KEY environmental variable is not set.")
}

# Get survey ID from command line argument
survey_id <- commandArgs(trailingOnly = TRUE)[1]

print(paste("Survey ID: ", survey_id)) # Debug statement

# Get API key from environmental variable
api_key <- Sys.getenv("QUALTRICS_API_KEY")

# Set API key in qualtrics configuration
qualtRics::qualtrics_api_credentials(
  api_key = api_key,
  install = TRUE,
  base_url = "https://iad1.qualtrics.com/API/v3/"
)

# Fetch survey
survey <- qualtRics::fetch_survey(surveyID = survey_id, verbose = TRUE)

# Print survey
print(survey)
