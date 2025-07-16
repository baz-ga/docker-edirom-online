#!/bin/bash

set -euo pipefail

echo
echo "#######################################################"
echo "# Welcome to the Edirom-Online xar-fetcher-entrypoint #"
echo "#######################################################"
echo

# Validate settings.

# check if $GITHUB_API_TOKEN is set
# If it is not set source ~/.secrets if it exists.
if [ -z "${GITHUB_API_TOKEN:-}" ]; then
    # Source secrets if they exist, but don't fail if not.
    echo "GITHUB_API_TOKEN is not set. Checking for ~/.secrets..."
    [ -f ~/.secrets ] && source ~/.secrets || true
else
    echo "GITHUB_API_TOKEN is set."
    echo
fi

# Ensure GITHUB_API_TOKEN is defined.
[ -z "${GITHUB_API_TOKEN:-}" ] && { echo "Error: GITHUB_API_TOKEN variable is not defined. Please set it." >&2; exit 1; }
# Validate number of arguments.
[ $# -ne 4 ] && { echo "Usage: $0 [owner] [main_repo_name] [edirom_version_strategy] [target_ref]" >&2; exit 1; }
# Enable trace mode if TRACE variable is set to a non-empty string.
# Using ${TRACE:-} to avoid "unbound variable" error when `set -u` is active.
[ "${TRACE:-}" ] && set -x


EDIROM_OWNER=$1
EDIROM_REPO=$2 # This is the main repository name, e.g., Edirom-Online
EDIROM_VERSION_STRATEGY=$3 # This is the version strategy, e.g., 2.0.0
EDIROM_REF=$4 # This is the target reference (tag or branch), e.g., v1.0.0, develop, bazga/candidate

echo "Owner: $EDIROM_OWNER"
echo "Repo: $EDIROM_REPO"
echo "Version: $EDIROM_VERSION_STRATEGY"
echo "Ref: $EDIROM_REF"
echo

# Check if the gh-ref-type-checker script exists and is executable.
REF_CHECKER_SCRIPT="/opt/gh-asset-downloader/gh-ref-type-checker.sh"
if [[ ! -f "$REF_CHECKER_SCRIPT" ]]; then
    echo "Error: gh-ref-type-checker script not found at $REF_CHECKER_SCRIPT" >&2
    echo "Please ensure the script is available in the expected location." >&2
    echo "If you are using a Docker image, make sure the image includes the gh-ref-type-checker script." >&2
    echo "You can find the script at https://github.com/baz-ga/gh-asset-downloader" >&2
    exit 1
elif [[ ! -x "$REF_CHECKER_SCRIPT" ]]; then
    echo "Error: gh-ref-type-checker script is not executable at $REF_CHECKER_SCRIPT" >&2
    exit 1
fi

# Define a function for fetching a release asset or checking out the github repository and build it.
# This function will be used to fetch xar files from the Edirom-Online repository.
# It will use the gh-ref-type-checker script to determine if the ref is a release or a branch.
# If it is a release, it will fetch the xar files using the gh-asset-downloader script.
# If it is a branch, it will clone the repository and build the xar files from the branch.
# The function will also handle errors and provide appropriate messages.
GET_XAR() {
    local owner="$1"
    local repo="$2"
    local ref="$3"
    local name="${4:-.xar}" # Default to .xar if not provided

    # GitHub API settings (re-defined for this function's scope)
    local GH_API="https://api.github.com"
    local GH_REPO="$GH_API/repos/$owner/$repo"
    local FORMAT="Accept: application/vnd.github+json"
    local AUTH="Authorization: Bearer $GITHUB_API_TOKEN"
    local API_VERSION="X-GitHub-Api-Version: 2022-11-28"

    echo "-> Checking reference type for $owner/$repo @ $ref"
    # We need to capture the exit code of the checker script without `set -e`
    # terminating the script. The `|| ref_code=$?` pattern achieves this.
    # If the script succeeds (exit 0), the `||` part is skipped and ref_code remains 0.
    # If it fails (non-zero exit), the `||` part is executed, and ref_code gets the exit code.
    local ref_code=0
    "$REF_CHECKER_SCRIPT" "$owner" "$repo" "$ref" || ref_code=$?
    echo "gh-ref-type-checker returned code: $ref_code"

    # Interpret the return code from gh-ref-type-checker.
    local release_or_branch=""
    case $ref_code in
        0) # 0: Reference is a release
            echo "Reference '$ref' is a release."
            release_or_branch="release"
            ;;
        1) # 1: Reference is a branch
            echo "Reference '$ref' is a branch."
            release_or_branch="branch"
            ;;
        2) # 2: Reference not found
            echo "Error: Reference '$ref' not found in '$owner/$repo'. Please check the reference or network connection." >&2
            exit 1
            ;;
        3) # 3: API error
            echo "Error: An API error occurred while checking reference type for '$owner/$repo'. Please check GitHub token and network." >&2
            exit 1
            ;;
        *) # Unknown exit code
            echo "Error: Unknown exit code ($ref_code) from gh-ref-type-checker." >&2
            exit 1
            ;;
    esac

    echo "Fetching XAR files from $owner/$repo at reference $ref with name pattern $name..."
    echo

    if [[ "$release_or_branch" == "branch" ]]; then
        echo "Cloning branch '$ref' from $owner/$repo to build XAR files..."

        # Create a temporary directory for cloning and building
        local temp_dir
        temp_dir=$(mktemp -d -t xar_build_XXXXXX)
        echo "Created temporary directory: $temp_dir"

        # Ensure the temporary directory is cleaned up on exit
        trap 'rm -rf "$temp_dir"' EXIT

        # Clone the repository and checkout the specified branch into a subdirectory
        local repo_path="$temp_dir/$repo"
        git clone -b "$ref" --single-branch "https://github.com/$owner/$repo.git" "$repo_path" \
            || { echo "Error: Failed to clone repository '$owner/$repo' branch '$ref'." >&2; exit 1; }

        # Change to the cloned repository directory
        cd "$repo_path" || { echo "Error: Failed to change directory to $repo_path" >&2; exit 1; }

        # Build the XAR files from the branch.
        # After cloning and checking out the branch, get the commit hash.
        # Initialize commit_hash to an empty string
        local commit_hash=""
        # Get the commit hash
        commit_hash=$(git rev-parse HEAD)
        echo "Commit hash for branch '$ref': $commit_hash"

        echo "Building XAR files from branch '$ref'..."
        echo "Running build script..."
        if [[ -f build.sh ]]; then
            ./build.sh
        elif [[ -f build.xml ]]; then
            ant
        else
            echo "Error: Neither 'build.sh' nor 'build.xml' found in the cloned repository '$repo_path'. Please check the repository structure." >&2
                exit 1
        fi
        echo "Build completed."

        # Check if any .xar files were produced
        shopt -s nullglob # Prevent *.xar from expanding to literal "*.xar" if no files match
        local xar_files=( build-xar/*.xar )
        shopt -u nullglob # Turn off nullglob

        if [[ ${#xar_files[@]} -eq 0 ]]; then
            echo "Warning: No .xar files were found after building in '$repo_path'." >&2
            # Exit with success if no .xar files are expected, or error if they are
            # For now, let's assume it's an error if no .xar files are found.
            exit 1
        else
            echo "Copying built XAR files to current working directory (/opt)."
            cp "${xar_files[@]}" /opt/ || { echo "Error: Failed to copy built XAR files to /opt." >&2; exit 1; }
            echo "XAR files copied successfully."
        fi

        # Set the EDIROM_COMMIT environment variable for the Docker build.
        if [[ -n "$commit_hash" ]]; then
            echo "Setting EDIROM_COMMIT to $commit_hash (from branch $ref)."
            echo "EDIROM_COMMIT=$commit_hash" >> /tmp/build_env
        fi

        # The trap command will handle cleaning up $temp_dir on exit.
        # ...existing code...
        elif [[ "$release_or_branch" == "release" ]]; then
            echo "Downloading assets from release '$ref'..."

            # Get the release API response
            local release_api_url="$GH_REPO/releases/tags/$ref"
            if [ "$ref" = "release-latest" ]; then
                release_api_url="$GH_REPO/releases/latest"
            fi
            local release_response
            release_response=$(curl -s -L -H "$FORMAT" -H "$AUTH" -H "$API_VERSION" "$release_api_url")

            # Extract the tag name from the release response
            local tag_name
            tag_name=$(echo "$release_response" | grep -oP '"tag_name": "\K[^"]+')
            if [[ -z "$tag_name" ]]; then
                echo "Warning: Could not extract tag_name from release response." >&2
            fi

            # Get the tag ref object (may be annotated or lightweight)
            local tag_ref_url="$GH_API/repos/$owner/$repo/git/ref/tags/$tag_name"
            local tag_ref_response
            tag_ref_response=$(curl -s -L -H "$FORMAT" -H "$AUTH" -H "$API_VERSION" "$tag_ref_url")
            local tag_object_url
            tag_object_url=$(echo "$tag_ref_response" | grep -oP '"url": "\K[^"]+' | head -1)

            # Get the tag object to resolve to the commit (for annotated tags)
            local tag_object_response
            tag_object_response=$(curl -s -L -H "$FORMAT" -H "$AUTH" -H "$API_VERSION" "$tag_object_url")
            local tag_type
            tag_type=$(echo "$tag_object_response" | grep -oP '"type": "\K[^"]+')
            local commit_sha
            if [[ "$tag_type" == "commit" ]]; then
                commit_sha=$(echo "$tag_object_response" | grep -oP '"sha": "\K[^"]+' | head -1)
            elif [[ "$tag_type" == "tag" ]]; then
                # Annotated tag, follow to the commit object
                local annotated_commit_url
                annotated_commit_url=$(echo "$tag_object_response" | grep -oP '"object": {[^}]*"url": "\K[^"]+')
                local annotated_commit_response
                annotated_commit_response=$(curl -s -L -H "$FORMAT" -H "$AUTH" -H "$API_VERSION" "$annotated_commit_url")
                commit_sha=$(echo "$annotated_commit_response" | grep -oP '"sha": "\K[^"]+')
            fi

            if [[ -n "$commit_sha" ]]; then
                echo "Setting EDIROM_COMMIT to $commit_sha (from release tag $tag_name)."
                echo "EDIROM_COMMIT=$commit_sha" >> /tmp/build_env
            else
                echo "Warning: Could not extract commit SHA from release tag '$tag_name'. EDIROM_COMMIT may not be accurate." >&2
            fi

            # Use the gh-asset-downloader script to fetch the XAR files for the release.
            /opt/gh-asset-downloader/gh-asset-downloader.sh "$owner" "$repo" "$ref" "$name" \
                || { echo "Error: Failed to fetch XAR files from $owner/$repo release '$ref'." >&2; exit 1; }
    # ...existing
    else
        # Since we can't reliably get the commit hash from a release tag,
        # we'll leave EDIROM_COMMIT as is (default or user-provided value).
        # In the future, the Edirom Online release process should include
        # the commit hash in the asset name or description.
        echo "Warning: Could not determine commit hash for release '$ref'.  EDIROM_COMMIT may not be accurate."

        echo "Error: Invalid 'release_or_branch' value: $release_or_branch. Expected 'release' or 'branch'." >&2
        exit 1
    fi
    echo "XAR files operation completed for $owner/$repo at reference $ref."
}

# ---
# Main Logic
# ---

# Validate EDIROM_VERSION_STRATEGY is version-like (e.g., 1.0.0).
# Using a more specific regex to ensure it's strictly three dot-separated numbers.
if [[ "$EDIROM_VERSION_STRATEGY" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "'$EDIROM_VERSION_STRATEGY' is a valid version number (e.g., 1.0.0)."
    EDIROM_VERSION_MAJOR=$(echo "$EDIROM_VERSION_STRATEGY" | cut -d. -f1)
    EDIROM_VERSION_MINOR=$(echo "$EDIROM_VERSION_STRATEGY" | cut -d. -f2)
    EDIROM_VERSION_PATCH=$(echo "$EDIROM_VERSION_STRATEGY" | cut -d. -f3)
    echo "Parsing to version parts:"
    echo "Major: $EDIROM_VERSION_MAJOR"
    echo "Minor: $EDIROM_VERSION_MINOR"
    echo "Patch: $EDIROM_VERSION_PATCH"
    echo

    if [[ "$EDIROM_VERSION_MAJOR" -ge 2 ]]; then
        echo "Edirom Edition version $EDIROM_VERSION_STRATEGY is >= 2.0.0."
        echo "Fetching XAR files from Edirom-Online-Frontend and Edirom-Online-Backend repositories."

        # Fetch xar files from Edirom-Online-Backend repository.
        GET_XAR "$EDIROM_OWNER" Edirom-Online-Backend "$EDIROM_REF" "*.xar" \
            || { echo "Error: Failed to fetch Edirom-Online-Backend XAR files." >&2; exit 1; }
        echo "Edirom-Online-Backend XAR file fetched successfully."
        echo

        # Fetch xar files from Edirom-Online-Frontend repository.
        GET_XAR "$EDIROM_OWNER" Edirom-Online-Frontend "$EDIROM_REF" "*.xar" \
            || { echo "Error: Failed to fetch Edirom-Online-Frontend XAR files." >&2; exit 1; }
        echo "Edirom-Online-Frontend XAR file fetched successfully."
        echo
    else # EDIROM_VERSION_STRATEGY is a version number and less than 2.0.0.
        echo "Edirom Edition version $EDIROM_VERSION_STRATEGY is less than 2.0.0."
        echo "Fetching XAR file from Edirom-Online repository."
        GET_XAR "$EDIROM_OWNER" Edirom-Online "$EDIROM_REF" "*.xar" \
            || { echo "Error: Failed to fetch Edirom-Online XAR files." >&2; exit 1; }
        echo "Edirom-Online XAR file fetched successfully."
        echo
    fi
else
    echo "Error: EDIROM_VERSION_STRATEGY '$EDIROM_VERSION_STRATEGY' is not a valid version number (e.g., 1.0.0). Please provide a valid version number." >&2
    exit 1
fi

exit 0
