#!/bin/bash

set -e # Halt on error

SKIP_PRECACHE="${SKIP_PRECACHE:-no}"
seed_image=${1:-$SEED_IMAGE}
seed_version=${2:-$SEED_VERSION}
authfile=${AUTH_FILE:-"/var/tmp/backup-secret.json"}
image=${3:-$LCA_IMAGE}
pull_secret=${PULL_SECRET_FILE:-"/var/tmp/pull-secret.json"}

sudo podman run --privileged --rm --pid=host --authfile "${authfile}" -v /:/host --entrypoint /usr/local/bin/ibu-imager "${image}" ibi --seed-image "${seed_image}" --authfile "${authfile}" --seed-version "${seed_version}" --pullSecretFile "${pull_secret}"

echo "DONE. Be sure to attach the relocation site info to the host and you can reboot the node"
