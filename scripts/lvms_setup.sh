#!/bin/bash

set -euo pipefail

root_dir="$(dirname $(readlink -f "$0"))/.."
# Load common functions
source "${root_dir}/scripts/functions.sh"

echo "Installing LVMS"
cat << EOF | oc apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-storage
spec: {}

---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-storage-operatorgroup
  namespace: openshift-storage
spec:
  targetNamespaces:
  - openshift-storage

---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: lvms
  namespace: openshift-storage
spec:
  installPlanApproval: Automatic
  name: lvms-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

wait_for_csv operators.coreos.com/lvms-operator.openshift-storage openshift-storage

# Create LVM Cluster
echo "Creating LVMCluster Storage Class"
cat << EOF | oc apply -f -
---
apiVersion: lvm.topolvm.io/v1alpha1
kind: LVMCluster
metadata:
  name: default
  namespace: openshift-storage
spec:
  storage:
    deviceClasses:
      - name: vg1
        default: true
        deviceSelector:
          paths:
            - /dev/vdb
        thinPoolConfig:
          name: vg1-pool-1
          sizePercent: 90
          overprovisionRatio: 10
        nodeSelector:
          nodeSelectorTerms:
            - matchExpressions:
                - key: node-role.kubernetes.io/worker
                  operator: Exists
EOF

until oc wait lvmcluster -n openshift-storage default --for=jsonpath={.status.ready}=true >/dev/null 2>&1; do
    echo -n .
    sleep 1
done
echo
