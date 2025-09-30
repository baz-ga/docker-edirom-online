# global definitions
# syntax=docker/dockerfile:1.4
# This Dockerfile builds a Docker image for Edirom-Online, a web application displaying music editions.
# It uses a multi-stage build to fetch the necessary XAR files and set up the environment.
# The first stage fetches the Edirom-Online XAR files using a script from the GitHub repository.
# The second stage uses the stadlerpeter/existdb base image to deploy the Edirom-Online application.
# The image is configured with environment variables for Edirom version, commit, and build date.

# setup build arguments
ARG EDIROM_VERSION_STRATEGY
ARG EDIROM_OWNER
ARG EDIROM_REF
ARG EDIROM_COMMIT

# setup build date
ARG BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# build arguments for stadlerpeter/existdb
ARG EXIST_DEFAULT_APP_PATH

# STAGE 1
FROM bwbohl/sencha-cmd:2.1.0 AS xar-fetcher

# setup build arguments
ARG EDIROM_VERSION_STRATEGY
ARG EDIROM_OWNER
ARG EDIROM_REF

ARG BUILD_DATE

# setup environment variables
ENV EDIROM_VERSION_STRATEGY=${EDIROM_VERSION_STRATEGY:-1.0.0}
ENV EDIROM_OWNER=${EDIROM_OWNER:-"Edirom"}
ENV EDIROM_REF=${EDIROM_REF:-"v$EDIROM_VERSION_STRATEGY"}

# copy gh-asset-downloader to xar-fetcher
COPY gitmodules/gh-asset-downloader /opt/gh-asset-downloader

# copy xar-fetcher-entrypoint.sh to xar-fetcher
# this script will be executed in the first stage to fetch the XAR files
# it will use the gh-asset-downloader to download the Edirom XAR files.
COPY xar-fetcher-entrypoint.sh /opt/xar-fetcher-entrypoint.sh

# add requirements to baseimage
RUN apt-get update && apt-get install -y --no-install-recommends \
 --no-install-suggests \
 bash curl libxml2-utils

## switch workdir
WORKDIR /opt

# get ADD-XARS
## copy add-xars directory to xar-fetcher
COPY add-xars/* /tmp/add-xars/

## run gh-asset-downloader for Edirom Online
RUN --mount=type=secret,id=GITHUB_API_TOKEN,target=/root/.secrets,env=GITHUB_API_TOKEN \
    /bin/bash -l /opt/xar-fetcher-entrypoint.sh "$EDIROM_OWNER" Edirom-Online "$EDIROM_VERSION_STRATEGY" "$EDIROM_REF" \
    && mkdir -p /tmp/add-xars \
    && cp Edirom-Online*.xar /tmp/add-xars/

    # The xar-fetcher-entrypoint.sh writes EDIROM_COMMIT to /tmp/build_env.
    # This file will be copied to the next stage.


# STAGE 2
FROM stadlerpeter/existdb:6.4.0 AS edirom-online

# setup build arguments
ARG EDIROM_VERSION_STRATEGY
ARG EDIROM_OWNER
ARG EDIROM_REF
ARG EDIROM_COMMIT

ARG BUILD_DATE

# build arguments for stadlerpeter/existdb
ARG EXIST_DEFAULT_APP_PATH

# setup EDIROM environment variables
ENV EDIROM_VERSION_STRATEGY=${EDIROM_VERSION_STRATEGY:-1.0.0}
ENV EDIROM_OWNER=${EDIROM_OWNER:-"Edirom"}
ENV EDIROM_REF=${EDIROM_REF:-"v${EDIROM_VERSION_STRATEGY}"}
ENV EDIROM_COMMIT=${EDIROM_COMMIT:-"unknown"}

ENV BUILD_DATE=${BUILD_DATE:-1970-01-01T00:00:00Z}

# setup EXIST environment variables
ENV EXIST_DEFAULT_APP_PATH=${EXIST_DEFAULT_APP_PATH:-xmldb:exist:///db/apps/Edirom-Online}
ENV EXIST_CONTEXT_PATH=/
ENV EXIST_ENV=development

# LABEL about this image
LABEL org.opencontainers.image.title="Docker Edirom Online"
LABEL org.opencontainers.image.description="A Dockerimage running on eXist-db with a predeployed Edirom Online, and options for deploying additional XAR archives on-build or on-run."
LABEL org.opencontainers.image.documentation="https://github.com/${EDIROM_OWNER}/docker-edirom-online"
LABEL org.opencontainers.image.url="https://github.com/${EDIROM_OWNER}/docker-edirom-online"
LABEL org.opencontainers.image.authors="Benjamin W. Bohl https://github.com/${EDIROM_OWNER}"
LABEL org.opencontainers.image.vendor="Benjamin W. Bohl"
LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.base.name="stadlerpeter/existdb:6.4.0"

# LABEL about the software
LABEL org.opencontainers.image.source="https://github.com/${EDIROM_OWNER}/docker-edirom-online"
LABEL org.opencontainers.image.version=$EDIROM_VERSION_STRATEGY
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
