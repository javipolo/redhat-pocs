# Replication of SNO-vDU environment on RHEL

We're going to use RHEL for performance testing because mangling with kernel, packages, files and everything is simpler, and it should not affect the overall performance of the system

## Install and register server
We're using as base RHEL 8.7 with an additional disk that will be used for microshift's LVM
```
kcli download image rhel8
kcli create vm -i rhel8 -P disks=['{"size":120,"pool":"default"},{"size":120,"pool":"default"},{"size":120,"pool":"default"}'] -P memory=16000 -P numcpus=4 rhel
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

## Node Tuning Operator
We will apply the tunning profiles using tuned, which is already available both in RHEL and rhel4edge

### Initial profile copy
The profiles are already provided in this repo, but here's the method used to extract them from a working cluster:

- Apply the vDU profiles to a working SNO cluster
```
oc --context $SNO_CONTEXT apply -f manifests/nto
```
- Copy the rendered profiles from a tuned pod, and "fix" them as needed
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


## Cluster Monitoring Operator

### Prepare CMO manifests
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


### Deploy CMO
```
oc create -f manifests/cmo/crd
oc create -f manifests/cmo/not_crd
```
