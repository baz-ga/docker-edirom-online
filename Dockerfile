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
LABEL org.opencontainers.image.revision="1.0.0-dev"
LABEL org.opencontainers.image.authors="Benjamin W. Bohl https://github.com/bwbohl"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.ref.name="bwbohl_edirom-online"
LABEL org.opencontainers.image.base.name="stadlerpeter/existdb:6.4.0"
LABEL org.opencontainers.image.documentation="https://github.com/bwbohl/docker-edirom-online"
LABEL org.opencontainers.image.source="https://github.com/bwbohl/docker-edirom-online"
LABEL org.opencontainers.image.url="https://github.com/bwbohl/docker-edirom-online"
LABEL org.opencontainers.image.version="1.0.0"

# setup environment variables
ENV EXIST_DEFAULT_APP_PATH=xmldb:exist:///db/apps/Edirom-Online
ENV EXIST_CONTEXT_PATH=/
ENV EXIST_ENV=development

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
