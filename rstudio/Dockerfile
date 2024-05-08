# Use rocker/rstudio as the base image
FROM rocker/rstudio:latest

#RUN install2.r --error --skipinstalled -n 4 \
#    remotes\
#    janitor \
#    tidyverse \
#    rstudioapi \
#    devtools \
#    rmarkdown \
#    BiocManager \
#    vroom \
#    gert \
#    jsonlite \
#    rvest \
#    qualtRics \
#    kableExtra \
#    leaflet \
#    plotly \
#    psych \
#    careless \
#    RSQLite \
#    renv \
#    shiny

# TODO Get kinetic api in here
#RUN R -e "install.packages('/tmp/kinetic-r-api.tar.gz', repos = NULL, type = 'source')"

# Install additional R packages
#RUN R -e "remotes::install_github('ricompute/ricomisc', upgrade='always')"

# Optionally, you may copy your own R scripts or data into the container
# COPY my_script.R /home/rstudio/

# Expose the port RStudio server is running on
EXPOSE 8787
