#!/bin/bash -e

# Pushes the final image to an internal registry (Artifactory) with git SHA tag.
# If branch is master, also pushes the 'latest' tag to the internal registry.

TAG="${1:-$(git rev-parse --short HEAD)}"
LATEST_TAG='latest'

SOURCE_IMAGE="hello"
INTERNAL_IMAGE="registry.tld/hello"

docker tag "$SOURCE_IMAGE" "$INTERNAL_IMAGE:$TAG"
docker push "$INTERNAL_IMAGE:$TAG"

if [ "$BRANCH_NAME" = "master" ]; then
    docker tag "$SOURCE_IMAGE" "$INTERNAL_IMAGE:$LATEST_TAG"
    docker push "$INTERNAL_IMAGE:$LATEST_TAG"
fi