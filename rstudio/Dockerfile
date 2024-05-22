# Use rocker/rstudio as the base image
FROM rocker/rstudio:latest

ENV DISABLE_AUTH=true
# Needed?
ENV USER=rstudio
ENV PASSWORD=test

# This works, the install2.r doesn't for some reason
RUN R -e "install.packages('remotes')"
RUN R -e "install.packages('tidyverse')"
RUN R -e "install.packages('janitor')"
RUN R -e "install.packages('rstudioapi')"
RUN R -e "install.packages('devtools')"
RUN R -e "install.packages('rmarkdown')"
RUN R -e "install.packages('BiocManager')"
RUN R -e "install.packages('vroom')"
RUN R -e "install.packages('gert')"
RUN R -e "install.packages('jsonlite')"
RUN R -e "install.packages('rvest')"
RUN R -e "install.packages('qualtRics')"
RUN R -e "install.packages('kableExtra')"
RUN R -e "install.packages('leaflet')"
RUN R -e "install.packages('plotly')"
RUN R -e "install.packages('psych')"
RUN R -e "install.packages('careless')"
RUN R -e "install.packages('RSQLite')"
RUN R -e "install.packages('renv')"
RUN R -e "install.packages('shiny')"

# TODO Get kinetic api in here
#RUN R -e "install.packages('/tmp/kinetic-r-api.tar.gz', repos = NULL, type = 'source')"

# Install additional R packages
RUN R -e "remotes::install_github('ricompute/ricomisc', upgrade='always')"

# Optionally, you may copy your own R scripts or data into the container
# COPY my_script.R /home/rstudio/

# Expose the port RStudio server is running on
EXPOSE 8787
