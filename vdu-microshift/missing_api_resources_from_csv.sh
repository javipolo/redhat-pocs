#!/bin/bash

# Generate a existing_api_resources.json file with the command
# oc api-resources -oname --no-headers| jq -Rcs 'split("\n")' > existing_api_resources.json

yq -r \
    --argjson existing $(cat existing_api_resources.json) \
    '[.spec.customresourcedefinitions.owned[].name] as $crds
     | [ .spec.install.spec | .permissions[].rules[], .clusterPermissions[].rules[]
       | .apiGroups[] as $apiGroup
       | .resources[] as $resource
       | [$resource, $apiGroup]
       | join(".")
       | sub("[.]$"; "")
       | select(contains("/") | not) ]
       as $permissions
     | $permissions - $crds - $existing
     | .[]' $1
