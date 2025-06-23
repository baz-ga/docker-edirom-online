# global definitions
# syntax=docker/dockerfile:1.4
# This Dockerfile builds a Docker image for Edirom-Online, a web application displaying music editions.
# It uses a multi-stage build to fetch the necessary XAR files and set up the environment.
# The first stage fetches the Edirom-Online XAR files using a script from the GitHub repository.
# The second stage uses the stadlerpeter/existdb base image to deploy the Edirom-Online application.
# The image is configured with environment variables for Edirom version, commit, and build date.

# setup build arguments
ARG EDIROM_VERSION
ARG EDIROM_COMMIT

# setup build date
ARG BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# STAGE 1
FROM alpine:3.21.3 AS xar-fetcher

# setup build arguments
ARG EDIROM_VERSION
ARG EDIROM_COMMIT

ARG BUILD_DATE

# setup environment variables
ENV EDIROM_VERSION=${EDIROM_VERSION:-1.0.0}
ENV EDIROM_COMMIT=${EDIROM_COMMIT:-"unknown"}
ENV BUILD_DATE=${BUILD_DATE:-1970-01-01T00:00:00Z}

# get EDIROM
## copy gh-asset-downloader to xar-fetcher
COPY gitmodules/gh-asset-downloader /opt/gh-asset-downloader

## add requirements to baseimage
RUN apk add --no-cache bash curl libxml2-utils ncurses

## switch workdir
WORKDIR /opt/gh-asset-downloader

## run gh-asset-downloader for Edirom Online
RUN --mount=type=secret,id=GITHUB_API_TOKEN,target=/root/.secrets \
    /bin/bash -l /opt/gh-asset-downloader/gh-asset-downloader.sh Edirom Edirom-Online "v$EDIROM_VERSION" .xar \
    && mkdir /tmp/add-xars \
    && cp Edirom-Online-*.xar /tmp/add-xars/

# get ADD-XARS
## copy add-xars directory to xar-fetcher
COPY add-xars/*.xar /tmp/add-xars/

# STAGE 2
FROM stadlerpeter/existdb:6.4.0 AS edirom-online

# setup build arguments
ARG EDIROM_VERSION
ARG EDIROM_COMMIT

ARG BUILD_DATE

# setup EDIROM environment variables
ENV EDIROM_VERSION=${EDIROM_VERSION:-1.0.0}
ENV EDIROM_COMMIT=${EDIROM_COMMIT:-"unknown"}
ENV BUILD_DATE=${BUILD_DATE:-1970-01-01T00:00:00Z}

# setup EXIST environment variables
ENV EXIST_DEFAULT_APP_PATH=xmldb:exist:///db/apps/Edirom-Online
ENV EXIST_CONTEXT_PATH=/
ENV EXIST_ENV=development


# LABEL about this image
LABEL org.opencontainers.image.title="Docker Edirom-Online"
LABEL org.opencontainers.image.description="Dockerimage for running Edirom-Online"
LABEL org.opencontainers.image.documentation="https://github.com/bwbohl/docker-edirom-online"
LABEL org.opencontainers.image.url="https://github.com/bwbohl/docker-edirom-online"
LABEL org.opencontainers.image.authors="Benjamin W. Bohl https://github.com/bwbohl"
LABEL org.opencontainers.image.vendor="Benjamin W. Bohl"
LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.base.name="stadlerpeter/existdb:6.4.0"

# LABEL about the software
LABEL org.opencontainers.image.source="https://github.com/Edirom/Edirom-Online"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.revision=$EDIROM_COMMIT
LABEL org.opencontainers.image.licenses="MIT"

# switch user to stadlerpeter/existdb user
USER wegajetty:wegajetty

# copy XARs from xar-fetcher (STAGE 1)
COPY --from=xar-fetcher /tmp/add-xars/*.xar ${EXIST_HOME}/autodeploy/

# copy edirom-entrypoint.sh
COPY --chown=wegajetty:wegajetty edirom-entrypoint.sh ${EXIST_HOME}/

# on run execute entrypoint
CMD ["./edirom-entrypoint.sh"]

# expose default port
EXPOSE 8080
