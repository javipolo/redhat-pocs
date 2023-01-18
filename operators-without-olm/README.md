# Installing OLM operators without OLM

## Requirements
* Working OpenShift cluster to search in the operator catalogs
* Valid credentials in pull-secret.json file
* New cluster where we want to install the operators
* jq - https://github.com/stedolan/jq
* yq - https://github.com/kislyuk/yq
* gprcurl - https://github.com/fullstorydev/grpcurl

## Find operators
Running the script `search_operator_image.sh` pointing a running OpenShift cluster will search for operators and get the bundle image to install
```
$ ./search_operator_image.sh ptp-operator
CATALOG certified-operators.openshift-marketplace.svc:50051
CATALOG community-operators.openshift-marketplace.svc:50051
CATALOG redhat-marketplace.openshift-marketplace.svc:50051
CATALOG redhat-operators.openshift-marketplace.svc:50051
ptp-operator 4.10.0-202212072254 stable registry.redhat.io/openshift4/ose-ptp-operator-bundle@sha256:784f93ac75b76cae6e4c1436207e5740ea862372b6325b00fa6eb8714972aa50
```

## Download operator bundle to disk
Running the script `download_bundle.sh` will download an unpack the operator bundle
```
$ ./download_bundle.sh registry.redhat.io/openshift4/ose-ptp-operator-bundle@sha256:784f93ac75b76cae6e4c1436207e5740ea862372b6325b00fa6eb8714972aa50
Downloading to bundles/ptp-operator
```

## Satisfy operator requirements
Running the script `search_operator_image.sh` will show the CRDs/api-resources used by the operator that are missing in our cluster
Before running it, we must gather the api-resources that are present in the cluster we want to install the operator
```
$ oc api-resources --context my_new_cluster -oname --no-headers| jq -Rcs 'split("\n")' > existing_api_resources.json
$ ./missing_api_resources_from_csv.sh bundles/ptp-operator/manifests/ptp-operator.clusterserviceversion.yaml
*.ptp.openshift.io
*.ptp.openshift.io
servicemonitors.monitoring.coreos.com
prometheusrules.monitoring.coreos.com
infrastructures.config.openshift.io
```

Now we should manually install the needed operators/resources to satisfy those constraints
Note that the \*.ptp.openshift.io are the ones that the ptp operator will provide

## Generate manifests and install them
Running the script `gen_manifests.py` will generate the needed manifests defined in the ClusterServiceVersion file
```
$ ./gen_manifests.py bundles/ptp-operator/manifests/ptp-operator.clusterserviceversion.yaml > ptp-operator-manifests.yaml
```

Those manifests can now be created in our cluster
```
$ oc apply --context my_new_cluster -f ptp-operator-manifests.yaml
```
