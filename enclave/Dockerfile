FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y git ruby-full build-essential awscli

ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_SESSION_TOKEN
ARG AWS_REGION=us-east-1

RUN aws s3 cp s3://kinetic-workspaces-config/configs/kinetic-r-api.tar.gz /tmp/kinetic-r-api.tar.gz

COPY ./install_r_and_pkgs /tmp/

RUN bash /tmp/install_r_and_pkgs kinetic-workspaces-config
