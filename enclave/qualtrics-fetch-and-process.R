library(qualtRics)

# Check for the necessary arguments and environmental variables
if (length(commandArgs(trailingOnly = TRUE)) < 3) {
  stop("Survey ID, start or end date were not provided as an argument.")
}

if (Sys.getenv("QUALTRICS_API_KEY") == "") {
  stop("QUALTRICS_API_KEY environmental variable is not set.")
}

# Get args
survey_id <- commandArgs(trailingOnly = TRUE)[1]
start_date <- commandArgs(trailingOnly = TRUE)[2]
end_date <- commandArgs(trailingOnly = TRUE)[3]

# print(paste("Survey ID: ", survey_id)) # Debug statement

# Get API key from environmental variable
api_key <- Sys.getenv("QUALTRICS_API_KEY")

# Set API key in qualtrics configuration
qualtRics::qualtrics_api_credentials(
  api_key = api_key,
  base_url = "iad1.qualtrics.com"
)

# Fetch survey
survey <- qualtRics::fetch_survey(
                       surveyID = survey_id,
                       start_date = start_date,
                       end_date = end_date,
                       label = FALSE,
                       verbose = TRUE,
                     )

# Print survey
print(survey)
