#!/bin/bash

set -euo pipefail

root_dir="$(dirname $(readlink -f "$0"))/.."
# Load common functions
source "${root_dir}/scripts/functions.sh"

acm_channel=release-2.13

echo "Installing ACM"
oc create namespace open-cluster-management
oc create secret generic pull-secret -n open-cluster-management --from-file=.dockerconfigjson=${root_dir}/pull_secret.json --type=kubernetes.io/dockerconfigjson

cat << EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: acm-operator
  namespace: open-cluster-management
spec:
  targetNamespaces:
  - open-cluster-management

---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: acm-operator-subscription
  namespace: open-cluster-management
spec:
  sourceNamespace: openshift-marketplace
  source: redhat-operators
  channel: ${acm_channel}
  installPlanApproval: Automatic
  name: advanced-cluster-management
EOF

wait_for_csv operators.coreos.com/advanced-cluster-management.open-cluster-management open-cluster-management

cat << EOF | oc apply -f -
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: open-cluster-management
spec: {}
EOF

echo "Waiting for MultiClusterHub to be ready"
until oc wait mch -n open-cluster-management multiclusterhub --for=condition=Complete; do
    echo -n . ; sleep 1; done

cat << EOF | oc apply -f -
apiVersion: agent-install.openshift.io/v1beta1
kind: AgentServiceConfig
metadata:
  name: agent
  namespace: open-cluster-management
spec:
  databaseStorage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 40Gi
  filesystemStorage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 40Gi
  osImages:
    - openshiftVersion: "4.19"
      version: 9.6.20250402-0
      url: "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.19/4.19.0/rhcos-4.19.0-x86_64-live-iso.x86_64.iso"
      rootFSUrl: "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.19/4.19.0/rhcos-4.19.0-x86_64-live-rootfs.x86_64.iso"
      cpuArchitecture: "x86_64"
EOF

echo "Waiting for Assisted Service to be ready"
until oc wait agentserviceconfig agent --for=condition=DeploymentsHealthy; do
    echo -n . ; sleep 1; done
