#!/bin/bash

catalog_namespace=openshift-marketplace
catalog_tmp_port=50051
context=dev
search=$1
oc="oc --context $context"

function get_catalog_services(){
    $oc get catalogsource -n "$catalog_namespace" -ojson| jq -r .items[].status.connectionState.address
}

function grpcurl(){
    podman run --net host -i --rm docker.io/fullstorydev/grpcurl:latest "$@"
}

function start_forward(){
    $oc port-forward -n "$catalog_namespace" svc/$1 $catalog_tmp_port:$2 > /dev/null &
    until nc -z localhost $catalog_tmp_port; do
        sleep 0.2
    done
}

catalogs=$(get_catalog_services)
for catalog in $catalogs; do
    catalog_svc="${catalog%%.*}"
    catalog_port="${catalog##*:}"
    start_forward $catalog_svc $catalog_port
    forward_pid=$!

    echo CATALOG $catalog
    grpcurl -plaintext localhost:$catalog_tmp_port api.Registry.ListBundles | jq -rs '.[] | select(.packageName | contains("'$search'")) | [ .packageName, .version, .channelName, .bundlePath ] | join(" ")' | sort -V

    kill $forward_pid
    wait $forward_pid 2> /dev/null
done
