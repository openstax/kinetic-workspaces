FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y git \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install ipython

RUN pip install git+https://github.com/vanderschaarlab/synthcity
