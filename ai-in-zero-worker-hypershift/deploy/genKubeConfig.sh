#!/bin/bash

PROXY_L1=13245
APIURL_L1=http://localhost:$PROXY_L1
# Token valid for 8640 hours
TOKEN_SECONDS=$(( 8640 * 3600 ))

getToken(){
    local api_url=$1
    local service_account=$2
    local namespace=$3
    local token_seconds=${4:-$TOKEN_SECONDS}

    local token_request='{"kind": "TokenRequest", "apiVersion": "authentication.k8s.io/v1", "spec": { "expirationSeconds": '$token_seconds'}}'
    curl -s \
         -XPOST \
         -H 'Content-Type: application/json; charset=utf-8' \
         $api_url/api/v1/namespaces/$namespace/serviceaccounts/$service_account/token -d "$token_request" \
      | jq -r .status.token
}

getKubeConfig(){
    token=$1
    kubeconfig_origin=${2:-admin-kubeconfig}
    oc --context $CONTEXT_L0 -n $NAMESPACE extract secret/$kubeconfig_origin --keys=kubeconfig --to=- | yq -y '.users[0].user = {token: "'$token'"} | .contexts[0].context.namespace = "'$NAMESPACE'"'
}

genKubeConfig(){
    service_account=$1
    token=$(getToken $APIURL_L1 $service_account $NAMESPACE)
    if [ "$token" ]; then
        oc create secret generic --from-file=kubeconfig=<(getKubeConfig "$token") --context $CONTEXT_L0 --namespace $NAMESPACE managed-$service_account-kubeconfig
    else
        echo ERROR. Couldnt get token for $service_account
    fi
}

oc proxy --context $CONTEXT_L1 --port $PROXY_L1 &
sleep 1

for i in $@; do
    genKubeConfig $i
done

jobs -p | xargs -r kill
