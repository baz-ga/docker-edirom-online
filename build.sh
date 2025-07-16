#!/bin/bash
set -e

# Usage: ./build.sh [--secret type=file,id=GITHUB_API_TOKEN,src=/path/to/secret] [additional docker build args...]

echo "#####################################################"
echo "# Welcome to the EDIROM Online Docker Build Script! #"
echo "#####################################################"
echo ""

# Collect all arguments to pass to docker build
DOCKER_BUILD_ARGS=("$@")

# echo build args, splitting by spaces
echo "Building EDIROM Online Docker image with the following arguments:"
for arg in "${DOCKER_BUILD_ARGS[@]}"; do
    echo "  - $arg"
done
echo ""

# prepare docker args for first build stage, rmoving -t  and the following string if present
# This is to ensure we don't tag the intermediate stage with the final image name
# as it is not needed and can cause issues with the build process.
# Remove -t and its value from DOCKER_BUILD_ARGS
XAR_FETCHER_ARGS=()
skip_next=0
for arg in "${DOCKER_BUILD_ARGS[@]}"; do
    if [[ $skip_next -eq 1 ]]; then
        skip_next=0
        continue
    fi
    if [[ "$arg" == "-t" ]]; then
        skip_next=1
        continue
    fi
    XAR_FETCHER_ARGS+=("$arg")
done

# 1. Build xar-fetcher stage and extract the commit SHA
echo "Building xar-fetcher stage to fetch EDIROM commit..."
# Ensure the xar-fetcher stage is built first to get the EDIROM commit
# This stage will create a file /tmp/build_env with the EDIROM_COMMIT
docker buildx build --target xar-fetcher -t temp-xar-fetcher "${XAR_FETCHER_ARGS[@]}" . \
    && echo "xar-fetcher stage built successfully." \
    || echo "Error building xar-fetcher stage."

# Create a temporary container to extract the build_env file
# This file contains the EDIROM_COMMIT value
# We will copy it to the host and then remove the temporary container
echo ""
echo "Extracting EDIROM_COMMIT from build_env file for use in final stage..."
docker create --name temp-xar-fetcher-container temp-xar-fetcher
docker cp temp-xar-fetcher-container:/tmp/build_env ./build_env
docker rm temp-xar-fetcher-container
docker image rm temp-xar-fetcher

export EDIROM_COMMIT=$(cat ./build_env | cut -d'=' -f2)
echo "Extracted EDIROM_COMMIT=$EDIROM_COMMIT"
echo ""
# Clean up the build_env file
rm -f ./build_env

# 2. Build the final image, passing the commit as a build-arg and any secrets/args
echo "Preparing to build the final EDIROM Online Docker image..."

# Add EDIROM_COMMIT as build-arg
DOCKER_BUILD_ARGS+=("--build-arg" "EDIROM_COMMIT=$EDIROM_COMMIT")

# echo build args for second stage
echo "Final build arguments:"
for arg in "${DOCKER_BUILD_ARGS[@]}"; do
    echo "  - $arg"
done
echo ""

# Build the final image, passing the EDIROM_COMMIT as a build argument
echo "Building final EDIROM Online Docker image with EDIROM_COMMIT=$EDIROM_COMMIT"
echo "Using additional build arguments: ${DOCKER_BUILD_ARGS[*]}"
# Build the final image, passing the EDIROM_COMMIT as a build argument
docker buildx build "${DOCKER_BUILD_ARGS[@]}" .
