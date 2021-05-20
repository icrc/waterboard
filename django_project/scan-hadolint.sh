#!/bin/sh

HELP="Launch hadolint on all Dockerfile files"
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "$HELP"
    exit 0
fi
docker run --rm -i hadolint/hadolint < ./src/Dockerfile
