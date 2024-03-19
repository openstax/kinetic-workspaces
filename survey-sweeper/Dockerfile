FROM ubuntu:jammy as builder
WORKDIR /usr/app
ENV DEBIAN_FRONTEND=noninteractive TZ=America/Chicago

RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_current.x | bash - && \
    apt-get install -y git libgit2-dev build-essential cmake dh-autoreconf nodejs


WORKDIR /app


CMD ["index.handler"]
# FROM ubuntu:jammy
# WORKDIR ${LAMBDA_TASK_ROOT}
# COPY --from=builder /usr/app/dist/* ./

#CMD ["index.handler"]




# COPY . /app
# CMD [ "app.handler" ]
