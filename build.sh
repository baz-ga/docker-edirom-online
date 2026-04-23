#!/bin/bash
set -e

# Usage: ./build.sh [--secret type=file,id=GITHUB_API_TOKEN,src=/path/to/secret] [additional docker build args...]

echo "#####################################################"
echo "# Welcome to the EDIROM Online Docker Build Script! #"
echo "#####################################################"
echo ""

# Collect all arguments to pass to docker build
DOCKER_BUILD_ARGS=("$@")

echo "Building EDIROM Online Docker image with the following arguments:"
for arg in "${DOCKER_BUILD_ARGS[@]}"; do
    echo "  - $arg"
done
echo ""

# Parse DOCKER_BUILD_ARGS to extract values needed on the host before the Docker build.
EDIROM_VERSION_STRATEGY_VAL="1.0.0"
EDIROM_OWNER_VAL="Edirom"
EDIROM_REF_VAL=""

next_is_build_arg=0
next_is_secret=0
for arg in "${DOCKER_BUILD_ARGS[@]}"; do
    if [[ $next_is_build_arg -eq 1 ]]; then
        next_is_build_arg=0
        if [[ "$arg" == EDIROM_VERSION_STRATEGY=* ]]; then
            EDIROM_VERSION_STRATEGY_VAL="${arg#EDIROM_VERSION_STRATEGY=}"
        elif [[ "$arg" == EDIROM_OWNER=* ]]; then
            EDIROM_OWNER_VAL="${arg#EDIROM_OWNER=}"
        elif [[ "$arg" == EDIROM_REF=* ]]; then
            EDIROM_REF_VAL="${arg#EDIROM_REF=}"
        fi
        continue
    fi
    if [[ $next_is_secret -eq 1 ]]; then
        next_is_secret=0
        if [[ "$arg" == *id=GITHUB_API_TOKEN* ]]; then
            secret_src=$(echo "$arg" | sed 's/.*src=\([^,]*\).*/\1/')
            [[ -f "$secret_src" ]] && export GITHUB_API_TOKEN=$(cat "$secret_src")
        fi
        continue
    fi
    if [[ "$arg" == "--build-arg" ]]; then
        next_is_build_arg=1
    elif [[ "$arg" == "--secret" ]]; then
        next_is_secret=1
    elif [[ "$arg" == --secret=* ]]; then
        secret_val="${arg#--secret=}"
        if [[ "$secret_val" == *id=GITHUB_API_TOKEN* ]]; then
            secret_src=$(echo "$secret_val" | sed 's/.*src=\([^,]*\).*/\1/')
            [[ -f "$secret_src" ]] && export GITHUB_API_TOKEN=$(cat "$secret_src")
        fi
    fi
done

[[ -z "$EDIROM_REF_VAL" ]] && EDIROM_REF_VAL="v$EDIROM_VERSION_STRATEGY_VAL"

# Determine which repo to query and EXIST_DEFAULT_APP_PATH based on version strategy.
version_major=$(echo "$EDIROM_VERSION_STRATEGY_VAL" | cut -d. -f1)
if [[ "$version_major" -ge 2 ]]; then
    COMMIT_REPO="Edirom-Online-Backend"
    EXIST_DEFAULT_APP_PATH_VAL="xmldb:exist:///db/apps/Edirom-Online-Frontend"
else
    COMMIT_REPO="Edirom-Online"
    EXIST_DEFAULT_APP_PATH_VAL="xmldb:exist:///db/apps/Edirom-Online"
fi

# Resolve EDIROM_COMMIT on the host directly — no Docker build stage needed.
GH_VERSION_DESCRIPTOR="./gitmodules/gh-asset-downloader/gh-version-descriptor.sh"
if [[ "$version_major" -ge 2 ]]; then
    echo "Resolving EDIROM_COMMIT for $EDIROM_OWNER_VAL/Edirom-Online-Backend and Edirom-Online-Frontend @ $EDIROM_REF_VAL..."
    COMMIT_BACKEND=$("$GH_VERSION_DESCRIPTOR" --with-repo "$EDIROM_OWNER_VAL" Edirom-Online-Backend "$EDIROM_REF_VAL") \
        || { echo "Error: Failed to resolve Edirom-Online-Backend version descriptor."; exit 1; }
    COMMIT_FRONTEND=$("$GH_VERSION_DESCRIPTOR" --with-repo "$EDIROM_OWNER_VAL" Edirom-Online-Frontend "$EDIROM_REF_VAL") \
        || { echo "Error: Failed to resolve Edirom-Online-Frontend version descriptor."; exit 1; }
    EDIROM_COMMIT="$COMMIT_BACKEND + $COMMIT_FRONTEND"
else
    echo "Resolving EDIROM_COMMIT for $EDIROM_OWNER_VAL/Edirom-Online @ $EDIROM_REF_VAL..."
    EDIROM_COMMIT=$("$GH_VERSION_DESCRIPTOR" --with-repo "$EDIROM_OWNER_VAL" Edirom-Online "$EDIROM_REF_VAL") \
        || { echo "Error: Failed to resolve EDIROM_COMMIT."; exit 1; }
fi
echo "EDIROM_COMMIT=$EDIROM_COMMIT"
echo ""

# Add resolved values as build-args.
DOCKER_BUILD_ARGS+=("--build-arg" "EDIROM_COMMIT=$EDIROM_COMMIT")
DOCKER_BUILD_ARGS+=("--build-arg" "EXIST_DEFAULT_APP_PATH=$EXIST_DEFAULT_APP_PATH_VAL")

# Default to --load (single-platform) or --push (multi-platform) if neither was specified.
has_output=0
is_multiplatform=0
skip_next=0
for arg in "${DOCKER_BUILD_ARGS[@]}"; do
    if [[ $skip_next -eq 1 ]]; then
        [[ "$arg" == *,* ]] && is_multiplatform=1
        skip_next=0
        continue
    fi
    if [[ "$arg" == "--load" ]] || [[ "$arg" == "--push" ]]; then
        has_output=1
    fi
    [[ "$arg" == "--platform" ]] && skip_next=1
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

echo "Final build arguments:"
for arg in "${DOCKER_BUILD_ARGS[@]}"; do
    echo "  - $arg"
done
echo ""

echo "Building EDIROM Online Docker image with EDIROM_COMMIT=$EDIROM_COMMIT"
docker buildx build "${DOCKER_BUILD_ARGS[@]}" .
