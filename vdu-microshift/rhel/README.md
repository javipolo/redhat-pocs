# Replication of SNO-vDU environment on RHEL

We're going to use RHEL for performance testing because mangling with kernel, packages, files and everything is simpler, and it should not affect the overall performance of the system

## Install and register server
We're using as base RHEL 8.7 with an additional disk that will be used for microshift's LVM
```
kcli download image rhel8
kcli create vm -i rhel8 -P disks=['{"size":120,"pool":"default"},{"size":120,"pool":"default"},{"size":120,"pool":"default"}'] -P memory=32768 -P numcpus=4 rhel
```

Once installed, we ssh into it and register the host with subscription-manager
```
subscription-manager register
```

## RT Kernel
```
subscription-manager repos --enable rhel-8-for-x86_64-rt-rpms
dnf install kernel-rt
```
### TODO RT related tuning

## Microshift
```
dnf install lvm2
pvcreate /dev/vdb
vgcreate rhel /dev/vdb
sudo subscription-manager repos     --enable rhocp-4.12-for-rhel-8-$(uname -i)-rpms     --enable fast-datapath-for-rhel-8-$(uname -i)-rpms
dnf install -y microshift
systemctl enable --now microshift
```

## Prepare ACM Hub
### Install a cluster
### Install RHACM
### Create MultiClusterHub
### Install Local Storage Operator
### Create a LSO StorageClass and set as default
```
cat << EOF | oc apply -f -
apiVersion: local.storage.openshift.io/v1
kind: LocalVolume
metadata:
  name: localstorage
  namespace: openshift-local-storage
spec:
  nodeSelector:
    nodeSelectorTerms:
    - matchExpressions:
        - key: node-role.kubernetes.io/worker
          operator: Exists
  storageClassDevices:
    - storageClassName: localstorage
      volumeMode: Filesystem
      devicePaths:
        - /dev/vdb
EOF

oc patch storageclass localstorage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Configure MultiClusterObservability
```
HUB_CLUSTER=sno
oc --context=$HUB_CLUSTER create namespace open-cluster-management-observability
oc --context=$HUB_CLUSTER create secret generic multiclusterhub-operator-pull-secret \
    -n open-cluster-management-observability \
    --from-literal=.dockerconfigjson="$(oc --context=$HUB_CLUSTER extract secret/pull-secret -n openshift-config --to=-)" \
    --type=kubernetes.io/dockerconfigjson
oc --context=$HUB_CLUSTER create -f thanos-object-storage.yaml -n open-cluster-management-observability
oc --context=$HUB_CLUSTER create -f - << EOF
apiVersion: observability.open-cluster-management.io/v1beta2
kind: MultiClusterObservability
metadata:
  name: observability
spec:
  observabilityAddonSpec: {}
  storageConfig:
    metricObjectStorage:
      name: thanos-object-storage
      key: thanos.yaml
EOF
```

## Attach cluster to ACM Hub
We need a preexisting Openshift cluster with RHACM installed to be used as a HUB cluster to manage some stuff on the microshift cluster

### Create resources on HUB cluster
```
CLUSTER_NAME=microshift
oc --context=$HUB_CLUSTER create namespace $CLUSTER_NAME
oc --context=$HUB_CLUSTER label namespace $CLUSTER_NAME cluster.open-cluster-management.io/managedCluster=$CLUSTER_NAME

cat << EOF | oc --context=$HUB_CLUSTER create -f -
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: $CLUSTER_NAME
spec:
  hubAcceptsClient: true
EOF

cat << EOF | oc --context=$HUB_CLUSTER create -f -
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: $CLUSTER_NAME
  namespace: $CLUSTER_NAME
spec:
  clusterName: $CLUSTER_NAME
  clusterNamespace: $CLUSTER_NAME
  applicationManager:
    enabled: false
  certPolicyController:
    enabled: false
  clusterLabels:
    cloud: auto-detect
    vendor: auto-detect
  iamPolicyController:
    enabled: false
  policyController:
    enabled: false
  searchCollector:
    enabled: false
  version: 2.7.2
EOF
```

### Deploy klusterlet on microshift cluster
```
oc --context=$HUB_CLUSTER -n $CLUSTER_NAME extract secret/${CLUSTER_NAME}-import --to=- --keys=crds.yaml   | oc --context=$CLUSTER_NAME create -f -
oc --context=$HUB_CLUSTER -n $CLUSTER_NAME extract secret/${CLUSTER_NAME}-import --to=- --keys=import.yaml | oc --context=$CLUSTER_NAME create -f -
```
## Node Tuning Operator
We will apply the tunning profiles using tuned, which is already available both in RHEL and rhel4edge

### Initial profile copy
The profiles are already provided in this repo, but here's the method used to extract them from a working cluster:

- Apply the vDU profiles to a working SNO cluster
```
oc --context $SNO_CONTEXT apply -f manifests/nto
```
- Copy the rendered profiles from a tuned pod, and "patch" them as needed
```
POD=$(oc --context $SNO_CONTEXT -n openshift-cluster-node-tuning-operator get po -l openshift-app=tuned -o'jsonpath={.items[0].metadata.name}')
# Do this for all the needed profiles
oc --context $SNO_CONTEXT -n openshift-cluster-node-tuning-operator cp $POD:/etc/tuned/openshift-node-performance-performance tuned/openshift-node-performance-performance
```

The list of the profiles I needed to copy are:
- /usr/lib/tuned/cpu-partitioning
- /usr/lib/tuned/openshift
- /etc/tuned/openshift-node
- /etc/tuned/openshift-node-performance-performance
- /etc/tuned/performance-patch

Watch out for isolated_cores definition both in cpu-partitioning and openshift-node-performance-performance

### Copy the profiles to the microshift node and apply them
```
scp -r tuned/* microshift:/etc/tuned
ssh microshift sudo tuned-adm profile openshift-node-performance-performance
```

## Additional tuning
### Kubelet config
Microshift rewrites kubelet.conf on restart, so no kubelet tuning is allowed

### CRI-O tuning
We should add specific configuration for CRI-O taking into account the CPU partitioning:
```
mkdir -p to_copy/etc/crio/crio.conf.d
cat << EOF > to_copy/etc/crio/crio.conf.d/01-workload-partitioning
[crio.runtime.workloads.management]
activation_annotation = "target.workload.openshift.io/management"
annotation_prefix = "resources.workload.openshift.io"
resources = { "cpushares" = 0, "cpuset" = "0,2" }
EOF
```

### 50-performance-performance MachineConfig
We need to apply the changes specified in a custom MachineConfig, provided in this repo in manifests/machineconfig/50-performance-performance.yaml
#### Plain files
```
mc=manifests/machineconfig/machineconfig-50-performance-performance.yaml
i=0
total=$(yq -r '.spec.config.storage.files | length' $mc)
while [[ $i -lt $total ]]; do
  path=$(yq -r .spec.config.storage.files[$i].path $mc)
  mode=$(printf %o $(yq -r .spec.config.storage.files[$i].mode $mc))
  mkdir -p to_copy/$(dirname $path)
  yq -r .spec.config.storage.files[$i].contents.source $mc | cut -d , -f 2 | base64 -d > "to_copy/$path"
  chmod $mode "to_copy/$path"
  i=$((i + 1))
done
```
#### Systemd units
```
mc=manifests/machineconfig/machineconfig-50-performance-performance.yaml
i=0
total=$(yq -r '.spec.config.systemd.units| length' $mc)
mkdir -p to_copy/etc/systemd/system/
while [[ $i -lt $total ]]; do
  name=$(yq -r .spec.config.systemd.units[$i].name $mc)
  enabled=$(yq -r .spec.config.systemd.units[$i].enabled $mc)
  yq -r .spec.config.systemd.units[$i].contents $mc > "to_copy/etc/systemd/system/${name}"
  [[ "$enabled" == "true" ]] && echo $name >> systemd_enable
  i=$((i + 1))
done

```

### Tweak as needed
We need to set proper values for CPU partitioning, specifically in */etc/crio/crio.conf.d/01-workload-partitioning* and */etc/crio/crio.conf.d/99-runtimes.conf*

### Copy all files to the vDU host, enable systemd services and restart it
```
tar czC to_copy . | ssh microshift sudo tar xvzC /
ssh microshift sudo systemctl daemon-reload
for u in $(< systemd_enable) ; do ssh microshift echo sudo systemctl enable $u; done
ssh microshift reboot
```

## Minimal Openshift CRDs
We will need to install some basic OpenShift CRDs and create basic CRs for them, so other operators wont complain
### Extract manifests from release image

```
mkdir -p ocp-release
podman create --name ocp quay.io/openshift-release-dev/ocp-release:4.12.0-x86_64
podman cp ocp:release-manifests ocp-release/release-manifests
podman cp ocp:manifests ocp-release/manifests
podman rm ocp
```

### Copy, create and patch the needed manifests
```
mkdir -p manifests/ocp/crd manifests/ocp/not_crd
cp ocp-release/manifests/0000_00_cluster-version-operator_01_clusteroperator.crd.yaml \
   ocp-release/release-manifests/0000_03_config-operator_01_proxy.crd.yaml \
   ocp-release/release-manifests/0000_10_config-operator_01_apiserver.crd.yaml \
   ocp-release/release-manifests/0000_10_config-operator_01_console.crd.yaml \
   ocp-release/release-manifests/0000_10_config-operator_01_featuregate.crd.yaml \
   ocp-release/release-manifests/0000_10_config-operator_01_infrastructure.crd.yaml \
   manifests/ocp/crd

cp ocp-release/release-manifests/0000_10_config-operator_01_openshift-config-ns.yaml \
   ocp-release/release-manifests/0000_05_config-operator_02_apiserver.cr.yaml \
   ocp-release/release-manifests/0000_05_config-operator_02_console.cr.yaml \
   ocp-release/release-manifests/0000_05_config-operator_02_featuregate.cr.yaml \
   ocp-release/release-manifests/0000_05_config-operator_02_infrastructure.cr.yaml \
   ocp-release/release-manifests/0000_05_config-operator_02_proxy.cr.yaml \
   manifests/ocp/not_crd

oc create -f manifests/ocp/crd
oc create -f manifests/ocp/not_crd
kubectl patch infrastructure cluster --subresource=status --type merge -p '{"status":{"controlPlaneTopology": "SingleReplica","infrastructureTopology": "SingleReplica"}}'
oc create secret generic pull-secret -n openshift-config --from-file=.dockerconfigjson=../../pull-secret.json --type=kubernetes.io/dockerconfigjson
```


## Cluster logging operator

### Download operator bundle
```
../download_bundle.sh registry.redhat.io/openshift-logging/cluster-logging-operator-bundle@sha256:b009f0a28c67cad352f7b52c46b89e9a295b56c4b96a6bcf32d59eb7e8b9a16f
```

### Prepare manifests
```
mkdir -p manifests/cluster-logging-operator/crd
cp ocp-release/release-manifests/0000_10_consoleexternalloglink.crd.yaml \
   ocp-release/release-manifests/0000_10_consoleplugin.crd.yaml \
   ocp-release/manifests/0000_00_cluster-version-operator_01_clusterversion.crd.yaml \
   manifests/cluster-logging-operator/crd
```

### Deploy Cluster Logging Operator
```
oc create -f manifests/cluster-logging-operator/crd
oc create -f manifests/cluster-logging-operator/manual
../gen-manifests.py bundles/cluster-logging/manifests/clusterlogging.v5.6.4.clusterserviceversion.yaml openshift-logging | oc apply -f -
```

## Cluster Monitoring Operator

### Prepare manifests
```
mkdir -p manifests/cmo/crd manifests/cmo/not_crd
cp ocp-release/release-manifests/*cluster-monitoring-operator* manifests/cmo/not_crd
mv manifests/cmo/not_crd/*custom-resource-definition.yaml manifests/cmo/crd

rm manifests/cmo/not_crd/0000_50_cluster-monitoring-operator_05-deployment-ibm-cloud-managed.yaml \
   manifests/cmo/not_crd/0000_90_cluster-monitoring-operator_00-operatorgroup.yaml

# We need to create namespace so prereqs can be created inside
oc create -f manifests/cmo/not_crd/0000_50_cluster-monitoring-operator_01-namespace.yaml
```

### Metrics for kubelet
We need to create:
- configmap `kubelet-serving-ca` with the CA used for kubelet metrics
- endpoints and service for kubelet metrics

```
# kubelet
mkdir -p certs/kubelet
scp microshift:/var/lib/microshift/certs/ca-bundle/kubelet-ca.crt certs/kubelet/ca-bundle.crt
oc create namespace openshift-config-managed
oc create -n openshift-config-managed configmap --from-file=certs/kubelet kubelet-serving-ca

# kubelet metrics service
MICROSHIFT_NODE_IP=192.168.122.135 envsubst < manifests/cmo/manual/kubelet-service.yaml | oc create -f -
```

### Metrics for etcd
We need to get the CA and the cert/key pair used to authenticate to etcd metrics and put it in the openshift-config namespace

TODO: Since etcd-metrics is listening in the node, in 127.0.0.1:2381, we cannot access it without some kind of proxy. Ideally we should change the listen address to be 0.0.0.0 so metrics are accessible from inside the microshift cluster

```
mkdir -p certs/etcd
scp microshift:/var/lib/microshift/certs/etcd-signer/ca.crt certs/etcd/etcd-client-ca.crt
scp microshift:/var/lib/microshift/certs/etcd-signer/etcd-serving/peer.crt certs/etcd/etcd-client.crt
scp microshift:/var/lib/microshift/certs/etcd-signer/etcd-serving/peer.key certs/etcd/etcd-client.key
oc create -n openshift-config secret tls --cert certs/etcd/etcd-client.crt --key certs/etcd/etcd-client.key etcd-metric-client
oc create -n openshift-config configmap --from-file=ca-bundle.crt=certs/etcd/etcd-client-ca.crt etcd-metric-serving-ca
```


### TODO rest of servicemonitors

### Deploy CMO
```
oc create -f manifests/cmo/crd
oc create -f manifests/cmo/not_crd
```
