#!/bin/bash

set -euo pipefail

# echo "Installing Local Storage Operator"
# cat << EOF | oc apply -f -
# ---
# apiVersion: v1
# kind: Namespace
# metadata:
#   name: openshift-local-storage
# spec: {}

# ---
# apiVersion: operators.coreos.com/v1
# kind: OperatorGroup
# metadata:
#   name: local-storage-operatorgroup
#   namespace: openshift-local-storage
# spec:
#   targetNamespaces:
#   - openshift-local-storage

# ---
# apiVersion: operators.coreos.com/v1alpha1
# kind: Subscription
# metadata:
#   name: local-storage-operator
#   namespace: openshift-local-storage
# spec:
#   installPlanApproval: Automatic
#   name: local-storage-operator
#   source: redhat-operators
#   sourceNamespace: openshift-marketplace
# EOF

# echo "Waiting for operator to be ready"
# until oc wait -n openshift-local-storage csv -l operators.coreos.com/local-storage-operator.openshift-local-storage --for=jsonpath='{.status.phase}'=Succeeded > /dev/null 2>&1; do
#     echo -n .
#     sleep 1
# done
# echo

# echo "Installing ODF"
# cat << EOF | oc apply -f -
# ---
# apiVersion: v1
# kind: Namespace
# metadata:
#   name: openshift-storage
# spec: {}

# ---
# apiVersion: operators.coreos.com/v1
# kind: OperatorGroup
# metadata:
#   name: openshift-storage-operatorgroup
#   namespace: openshift-storage
# spec:
#   targetNamespaces:
#   - openshift-storage

# ---
# apiVersion: operators.coreos.com/v1alpha1
# kind: Subscription
# metadata:
#   name: odf-operator
#   namespace: openshift-storage
# spec:
#   installPlanApproval: Automatic
#   name: odf-operator
#   source: redhat-operators
#   sourceNamespace: openshift-marketplace
# EOF

# echo "Waiting for operator to be ready"
# until oc wait -n openshift-storage csv -l operators.coreos.com/odf-operator.openshift-storage --for=jsonpath='{.status.phase}'=Succeeded > /dev/null 2>&1; do
#     echo -n .
#     sleep 1
# done
# echo

# Label all worker nodes to be used as storage
oc label node -l node-role.kubernetes.io/worker cluster.ocs.openshift.io/openshift-storage=''

# Create LVM Cluster
echo "Creating LocalVolumeSet"
cat << EOF | oc apply -f -
---
apiVersion: local.storage.openshift.io/v1alpha1
kind: LocalVolumeSet
metadata:
  name: local-block
  namespace: openshift-local-storage
spec:
  nodeSelector:
    nodeSelectorTerms:
    - matchExpressions:
      - key: cluster.ocs.openshift.io/openshift-storage
        operator: In
        values:
        - ""
  storageClassName: localblock
  volumeMode: Block
  fstype: ext4
  deviceInclusionSpec:
    deviceTypes:
    - disk
    deviceMechanicalProperties:
    - NonRotational
    minSize: 100Gi
EOF

until oc wait localvolumeset local-block -n openshift-local-storage --for=condition=Available; do
    echo -n .
    sleep 1
done
echo

echo "Creating StorageCluster"
cat << EOF | oc apply -f -
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  name: ocs-storagecluster
  namespace: openshift-storage
spec:
  arbiter: {}
  encryption:
    kms: {}
  externalStorage: {}
  managedResources:
    cephBlockPools: {}
    cephCluster: {}
    cephConfig: {}
    cephDashboard: {}
    cephFilesystems: {}
    cephNonResilientPools: {}
    cephObjectStoreUsers: {}
    cephObjectStores: {}
    cephRBDMirror: {}
    cephToolbox: {}
  mirroring: {}
  nodeTopologies: {}
  storageDeviceSets:
  - count: 1
    dataPVCTemplate:
      metadata: {}
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Gi
        storageClassName: localblock  # Replace with your actual storage class
        volumeMode: Block
      status: {}
    name: ocs-deviceset-localblock
    placement: {}
    portable: true
    preparePlacement: {}
    replica: 3
EOF

until oc wait storagecluster ocs-storagecluster -n openshift-storage --for=condition=Available; do
    echo -n .
    sleep 1
done
echo

