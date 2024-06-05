#!/bin/bash

set -o errexit

# wait_for_csv label namespace
function wait_for_csv {
    local label
    local namespace
    label="-l $1"
    [[ "$2" ]] && namespace="-n $2"
    echo "Waiting for operator to be ready"
    until oc wait $namespace csv $label --for=jsonpath='{.status.phase}'=Succeeded > /dev/null 2>&1; do
        echo -n .
        sleep 1
    done
    echo
}

# Rewrite current routes
echo "Rewriting current routes"
ORIGINAL_ROUTES=apps.seed.ibo0.redhat.com
NEW_ROUTES=apps.ibi.ibo1.redhat.com
oc get route -A -o yaml | sed s/$ORIGINAL_ROUTES/$NEW_ROUTES/g | oc apply -f -

# Create LVM Cluster
echo "Creating LVMCluster Storage Class"
oc apply -f manifests/deploy/002-lvmcluster.yaml
until oc wait lvmcluster -n openshift-storage default --for=jsonpath={.status.ready}=true >/dev/null 2>&1; do
    echo -n .
    sleep 1
done
echo

### Install Pipelines Operator
echo "Installing Pipelines Operator"
oc apply -f manifests/deploy/007-pipeline-operator.yaml
wait_for_csv operators.coreos.com/openshift-pipelines-operator-rh.openshift-operators openshift-operators

### Install RHOAI components
echo "Installing RHOAI components"
oc apply -f manifests/deploy/009-data-science-cluster.yaml
until oc wait dsc default-dsc --for=jsonpath={.status.phase}=Ready >/dev/null 2>&1; do
    echo -n .
    sleep 1
done
echo

# Configure ODH dashboard
echo "Configuring ODH Dashboard"
oc apply -f manifests/deploy/010-odh-dashboard-config.yaml

# Create custom workbench image
echo "Creating Custom Image for workbench"
oc apply -f manifests/test/011-workbench-imagestream.yaml

# Deploy big LLM to test
# Disabled because we dont have GPU
# oc apply -f manifests/test/012-llm.yaml

# Deploy Flan-T5-Small LLM to test
echo "Deploying Flan T5 Small LLM"
oc apply -f manifests/test/012-llm-flan-t5-small.yaml

cat << EOF

================
RHOAI configured
================

EOF
