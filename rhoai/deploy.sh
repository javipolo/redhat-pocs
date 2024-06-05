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

### Enable internal image registry
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}'
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'

### LVMS
echo "Installing LVMS"
oc apply -f manifests/deploy/001-lvms.yaml
wait_for_csv operators.coreos.com/lvms-operator.openshift-storage openshift-storage

# # Create LVM Cluster
# echo "Creating LVMCluster Storage Class"
# oc apply -f manifests/deploy/002-lvmcluster.yaml
# until oc wait lvmcluster -n openshift-storage default --for=jsonpath={.status.ready}=true >/dev/null 2>&1; do
#     echo -n .
#     sleep 1
# done
# echo

### OpenShift Serverless
echo "Installing Serverless Operator"
oc apply -f manifests/deploy/003-serverless-operator.yaml
wait_for_csv olm.copiedFrom=openshift-serverless

### OpenShift Distributed Tracing Platform (Jaeger)
echo "Installing Distributed Tracing (jaeger)"
oc apply -f manifests/deploy/004-jaeger.yaml
wait_for_csv operators.coreos.com/jaeger-product.openshift-distributed-tracing openshift-distributed-tracing

### Kiali Operator
echo "Installing Kiali"
oc apply -f manifests/deploy/005-kiali.yaml
wait_for_csv operators.coreos.com/kiali-ossm.openshift-operators openshift-operators

### Service Mesh Operator
echo "Installing Service Mesh Operator"
oc apply -f manifests/deploy/006-service-mesh-operator.yaml
wait_for_csv operators.coreos.com/servicemeshoperator.openshift-operators openshift-operators

# ### Install Pipelines Operator
# echo "Installing Pipelines Operator"
# oc apply -f manifests/deploy/007-pipeline-operator.yaml
# wait_for_csv operators.coreos.com/openshift-pipelines-operator-rh.openshift-operators openshift-operators

### Install Red Hat Openshift AI Operator
echo "Installing RHODS operator (RHOAI)"
oc apply -f manifests/deploy/008-rhods-operator.yaml
wait_for_csv operators.coreos.com/rhods-operator.redhat-ods-operator redhat-ods-operator

# ### Install RHOAI components
# echo "Installing RHOAI components"
# oc apply -f manifests/deploy/009-data-science-cluster.yaml
# until oc wait dsc default-dsc --for=jsonpath={.status.phase}=Ready >/dev/null 2>&1; do
#     echo -n .
#     sleep 1
# done
# echo

# # Configure ODH dashboard
# echo "Configuring ODH Dashboard"
# oc apply -f manifests/deploy/010-odh-dashboard-config.yaml

cat << EOF

===============
RHOAI installed
===============

EOF
