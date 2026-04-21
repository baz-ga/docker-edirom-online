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
    #if --build-arg EDIROM_VERSION_STRATEGY=2.0.0 then add another --build-arg EXIST_DEFAULT_APP_PATH=xmldb:exist:///db/apps/Edirom-Online-Frontend
    if [[ "$arg" == EDIROM_VERSION_STRATEGY=* ]]; then
        XAR_FETCHER_ARGS+=("$arg")
        # Extract the version strategy
        version_strategy=$(echo "$arg" | cut -d'=' -f2)
        # Add the EXIST_DEFAULT_APP_PATH argument based on the version strategy
        if [[ "$version_strategy" == "2.0.0" ]]; then
            XAR_FETCHER_ARGS+=("--build-arg" "EXIST_DEFAULT_APP_PATH=xmldb:exist:///db/apps/Edirom-Online-Frontend")
        else
            XAR_FETCHER_ARGS+=("--build-arg" "EXIST_DEFAULT_APP_PATH=xmldb:exist:///db/apps/Edirom-Online")
        fi
        skip_next=0
        continue
    fi
    # Skip the -t or --tag argument and the next value
    if [[ "$arg" == "-t" ]] || [[ "$arg" == --tag ]]; then
        skip_next=1
        continue
    fi
    # Skip --push and --load flags (no value follows)
    if [[ "$arg" == "--push" ]] || [[ "$arg" == "--load" ]]; then
        continue
    fi
    # Skip --platform and its value
    if [[ "$arg" == "--platform" ]]; then
        skip_next=1
        continue
    fi
    # Add the current argument to the list
    XAR_FETCHER_ARGS+=("$arg")
done

# 1. Build xar-fetcher stage and extract the commit SHA
echo "Building xar-fetcher stage to fetch EDIROM commit..."
echo "Using these build arguments: ${XAR_FETCHER_ARGS[*]}"
# Ensure the xar-fetcher stage is built first to get the EDIROM commit
# This stage will create a file /tmp/build_env with the EDIROM_COMMIT
docker buildx build --target xar-fetcher --load -t temp-xar-fetcher "${XAR_FETCHER_ARGS[@]}" . \
    && echo "xar-fetcher stage built successfully." \
    || { echo "Error building xar-fetcher stage."; exit 1; }

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

# Default to --load (single-platform) or --push (multi-platform) if neither was specified
has_output=0
is_multiplatform=0
skip_next=0
for arg in "${DOCKER_BUILD_ARGS[@]}"; do
    if [[ $skip_next -eq 1 ]]; then
        if [[ "$arg" == *,* ]]; then
            is_multiplatform=1
        fi
        skip_next=0
        continue
    fi
    if [[ "$arg" == "--load" ]] || [[ "$arg" == "--push" ]]; then
        has_output=1
    fi
    if [[ "$arg" == "--platform" ]]; then
        skip_next=1
    fi
done
if [[ $has_output -eq 0 ]]; then
    if [[ $is_multiplatform -eq 1 ]]; then
        echo "Multi-platform build detected; defaulting to --push for the final image."
        DOCKER_BUILD_ARGS+=("--push")
    else
        echo "No --load or --push specified; defaulting to --load for the final image."
        DOCKER_BUILD_ARGS+=("--load")
    fi
fi

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
