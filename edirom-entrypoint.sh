#!/bin/bash

echo
echo "###################################"
echo "# Welcome to docker-edirom-online #"
echo "###################################"
echo
echo "This docker container is based on stadlerpeter/existdb:6."
echo "In order to deploy additional XARs at runtime, e.g.,"
echo "Edirom Edition data, place them in a directory on your host"
echo "and mount it to ›/var/add-xars‹ using the docker run -v flag."
echo

# check for additional XARs
echo "Checking for XARs at /var/add-xars/"

# Use nullglob to ensure the glob expands to nothing if no files match,
# preventing literal "*.xar" from being passed.
shopt -s nullglob
xars=(/var/add-xars/*.xar)
if [ ${#xars[@]} -gt 0 ]; then
    echo "Copying additional XARs: ${xars[@]} to $EXIST_HOME/autodeploy/"
    for xar in "${xars[@]}"; do
        basename_xar=$(basename "$xar")
        if [[ -f "$EXIST_HOME/autodeploy/$basename_xar" ]]; then
            echo "Warning: $basename_xar already exists in $EXIST_HOME/autodeploy/. Overwriting."
        else
            cp -f "$xar" "$EXIST_HOME/autodeploy/" || { echo "Error: Failed to copy $basename_xar." >&2; exit 1; }
            echo "Copied $basename_xar to $EXIST_HOME/autodeploy/"
        fi
    done
    echo
    echo "XARs copied successfully."
else
    echo "No XARs found at /var/add-xars/."
fi
shopt -u nullglob # Disable nullglob
echo

# starting the original image's entrypoint
echo "starting base-image…"
echo

# executing the original entrypoint.sh from stadlerpeter/existdb:6
exec ${EXIST_HOME}/entrypoint.sh
