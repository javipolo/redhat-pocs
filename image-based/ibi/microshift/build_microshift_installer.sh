#!/bin/bash

output=${1:-microshift.iso}

[ -f "$output" ] && rm -f $output

wait_for_build(){
    local buildid=$1
    local status
    while composer-cli compose info $buildid | head -n1 | grep -qE 'WAITING|RUNNING'; do
        echo -n .
        sleep 20
    done
    echo

    status=$(composer-cli compose info $buildid | head -n1 | cut -d ' ' -f 2)
    if [[ "$status" != "FINISHED" ]]; then
        echo "Build did not finish successfully"
        echo "Check logs with"
        echo "      composer-cli compose log $buildid"
        exit 1
    fi
}

trap _cleanup EXIT
_cleanup(){
    if podman ps -qa --filter name=minimal-microshift-server | grep -q .; then
        podman kill minimal-microshift-server
    fi
}

for source in sources/*.toml; do
    echo "Adding source $source"
    composer-cli sources add $source
done

for blueprint in blueprints/*.toml; do
    echo "Adding blueprint $blueprint"
    composer-cli blueprints push $blueprint
done

echo Building blueprint
BUILDID=$(sudo composer-cli compose start-ostree --ref "rhel/9/$(uname -m)/edge" microshift edge-container | awk '{print $2}')
wait_for_build $BUILDID
composer-cli compose image ${BUILDID}

IMAGEID=$(cat < "./${BUILDID}-container.tar" | sudo podman load | grep -o -P '(?<=sha256[@:])[a-z0-9]*')
podman run --rm -d --name=minimal-microshift-server -p 8085:8080 ${IMAGEID}

BUILDID=$(sudo composer-cli compose start-ostree --url http://localhost:8085/repo/ --ref "rhel/9/$(uname -m)/edge" microshift-installer edge-installer | awk '{print $2}')
wait_for_build $BUILDID
composer-cli compose image ${BUILDID}

mv ${BUILDID}-installer.iso microshift-installer-vanilla.iso

echo Creating final ISO $output
mkksiso kickstart/microshift.ks microshift-installer-vanilla.iso microshift.iso

mv microshift.iso /home/isos/microshift.iso
