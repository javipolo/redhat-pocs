# Create cluster and get kubeconfig

```
# Create and install cluster
make cluster
# Check that new context is added to our list
oc config get-contexts
```

# Install RHACM

```
oc create namespace open-cluster-management
oc create secret generic pull-secret -n open-cluster-management --from-file=.dockerconfigjson=../pull_secret.json --type=kubernetes.io/dockerconfigjson

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
  channel: release-2.4
  installPlanApproval: Automatic
  name: advanced-cluster-management

EOF
```

# Wait for CRD and install MCH
```
oc get csv -n open-cluster-management -w
oc get po -n open-cluster-management -w
```

# Create MultiClusterHub
```
cat << EOF | oc apply -f -
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: open-cluster-management
spec: {}
EOF
```

# And wait for everything to be deployed
```
oc get mch -n open-cluster-management -w
oc get po -n open-cluster-management -w
```

# Setup local-storage operator
```
cat << EOF | oc apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-local-storage
spec: {}

---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: local-operator-group
  namespace: openshift-local-storage
spec:
  targetNamespaces:
  - openshift-local-storage

---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: local-storage-operator
  namespace: openshift-local-storage
spec:
  channel: "4.10"
  installPlanApproval: Automatic
  name: local-storage-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

# Wait for it to be deployed
```
oc get po -n openshift-local-storage -w
```

# And set-up a localVolume

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
        - /dev/vdc
EOF
```

# See that eventually PersistentVolumes are created:
```
oc get po -n openshift-local-storage -w
oc get pv -w
```


# Set storageclass as cluster default
```
oc patch storageclass localstorage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

# Setup Hive and Assisted Service

# Tweak hive config
```
oc patch hiveconfig hive --type merge -p '{"spec":{"targetNamespace":"hive","logLevel":"debug","featureGates":{"custom":{"enabled":["AlphaAgentInstallStrategy"]},"featureSet":"Custom"}}}'
```

# Setup assisted-service
```
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
  # ### This is a ConfigMap that only will make sense on Disconnected environments
  # mirrorRegistryRef:
  #   name: "lab-index-mirror"
  # ###
  osImages:
    - openshiftVersion: "4.10"
      version: 410.84.202202251620-0
      url: "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.10/latest/rhcos-4.10.3-x86_64-live.x86_64.iso"
      rootFSUrl: "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.10/latest/rhcos-4.10.3-x86_64-live-rootfs.x86_64.img"
      cpuArchitecture: "x86_64"
EOF
```

# We need assisted-installer DNS entry so ztp machines can access assisted-service for installation purposes


# Create spoke cluster

In AgentClusterInstall we define the spoke cluster configuration
in imageSetRef we put the reference to the ClusterImageSet resource that defines the openshift release that we want to install

For more detailed information on what's each field, we can use oc explain to get more information:
`oc explain agentclusterinstall.spec.apiVIP`

```
oc create namespace cluster1
oc create secret generic assisted-deployment-pull-secret -n cluster1 --from-file=.dockerconfigjson=/root/pull_secret.json --type=kubernetes.io/dockerconfigjson

cat << EOF | oc apply -f -
---
apiVersion: extensions.hive.openshift.io/v1beta1
kind: AgentClusterInstall
metadata:
  name: cluster1
  namespace: cluster1
spec:
  clusterDeploymentRef:
    name: cluster1
  imageSetRef:
    name: img4.10.5-x86-64-appsub
  apiVIP: "192.168.122.220"
  ingressVIP: "192.168.122.221"
  networking:
    clusterNetwork:
      - cidr: "172.20.0.0/22"
        hostPrefix: 25
    serviceNetwork:
      - "172.21.0.0/24"
    # machineNetwork:
    #   - cidr: "192.168.122.0/24"
  provisionRequirements:
    controlPlaneAgents: 3
    workerAgents: 2
  sshPublicKey: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDVMrusn8G4xSqVL98NUGIqDvDQK3MwiLenSDmZXZeH92djIhEi7wdecIc3s8KQ0EG16Avi5qs7rp1X8dmACNLY6O/WPeF8LhuC3+T8f1+rE3O+GQ/VFrCSUxQNrZZ92+o6FQPW9A9+OGcwL+ywBN2HKf3G15mX44Q/W4KnQ7dubwXHRYUX4vDiz7XplxU5tyC5eszYDQZ87ljnxPM6ZRglINkGqgacyDBiuV7GRrnPH7V1PAb/vOSRaJrRmJoiZqgurFd5xtK0kmUrLEUGzNfi3H+qLL6oujN2g4SOZZ/HFPPpXbfSO5gpQ5ote3BBsLOu+ovBYhiKoowEWMs1kNPVqKoV8PxOjrcJZ1r0Vx3c4FPGmleR179hxFE0AHfCioU+UOAJkplM9ZhwuMM+09fHVYRmCiFoIxXkm0hsJdfww4VKROqpIF5oLW9+0oZY5VPgWClko3Y/eqdHvyuNt6LOitm8S5oDyyZlCGfg0C1W9SBbaiJwBjbOZZDeQ4wak08="

---
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  name: cluster1
  namespace: cluster1
spec:
  baseDomain: redhat.com
  clusterName: cluster1
  controlPlaneConfig:
    servingCertificates: {}
  installed: false
  clusterInstallRef:
    group: extensions.hive.openshift.io
    kind: AgentClusterInstall
    name: cluster1
    version: v1beta1
  platform:
    agentBareMetal:
      agentSelector:
        matchLabels:
          infraenv: my-infraenv
  pullSecretRef:
    name: assisted-deployment-pull-secret

---
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: cluster1
  namespace: cluster1
spec:
  clusterName: cluster1
  clusterNamespace: cluster1
  clusterLabels:
    cloud: auto-detect
    vendor: auto-detect
  applicationManager:
    enabled: false
  certPolicyController:
    enabled: false
  iamPolicyController:
    enabled: false
  policyController:
    enabled: false
  searchCollector:
    enabled: false

---
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: cluster1
  namespace: cluster1
spec:
  hubAcceptsClient: true
EOF
```

# Create infraenv
In this example will create a infraenv in its own namespace, so we can use it in different clusters
Since the infraenv wont be bound to any cluster, we will later need to bind each agent to the ztp cluster that we want

An alternative would be to create it in the same namespace as spoke cluster, and directly binding infraenv to a cluster (by uncommenting clusterRef in infraenv). This way we wouldnt need to bind the agents to the cluster in one of the next steps

```
oc create namespace my-infraenv
oc create secret generic assisted-deployment-pull-secret -n my-infraenv --from-file=.dockerconfigjson=/root/pull_secret.json --type=kubernetes.io/dockerconfigjson

cat << EOF | oc apply -f -
---
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: my-infraenv
  namespace: my-infraenv
spec:
  # clusterRef:
  #   name: cluster1
  #   namespace: cluster1
  agentLabels:
    infraenv: my-infraenv
  sshAuthorizedKey: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDVMrusn8G4xSqVL98NUGIqDvDQK3MwiLenSDmZXZeH92djIhEi7wdecIc3s8KQ0EG16Avi5qs7rp1X8dmACNLY6O/WPeF8LhuC3+T8f1+rE3O+GQ/VFrCSUxQNrZZ92+o6FQPW9A9+OGcwL+ywBN2HKf3G15mX44Q/W4KnQ7dubwXHRYUX4vDiz7XplxU5tyC5eszYDQZ87ljnxPM6ZRglINkGqgacyDBiuV7GRrnPH7V1PAb/vOSRaJrRmJoiZqgurFd5xtK0kmUrLEUGzNfi3H+qLL6oujN2g4SOZZ/HFPPpXbfSO5gpQ5ote3BBsLOu+ovBYhiKoowEWMs1kNPVqKoV8PxOjrcJZ1r0Vx3c4FPGmleR179hxFE0AHfCioU+UOAJkplM9ZhwuMM+09fHVYRmCiFoIxXkm0hsJdfww4VKROqpIF5oLW9+0oZY5VPgWClko3Y/eqdHvyuNt6LOitm8S5oDyyZlCGfg0C1W9SBbaiJwBjbOZZDeQ4wak08="
  pullSecretRef:
    name: assisted-deployment-pull-secret
EOF
```

# Download ISO
```
oc get infraenv -n my-infraenv my-infraenv -o jsonpath='{.status.isoDownloadURL}' | xargs curl -kLo /home/isos/ztp-cluster1.iso
```

# Create VMs
```
make ztp-vms
```

# Wait for agents to pop up
```
oc get agent -n my-infraenv -w
```

# Patch the agents to bind to cluster
```
oc get agent -n my-infraenv -ojson | jq -r '.items[] | select(.spec.approved==false) | .metadata.name' | xargs oc -n my-infraenv patch -p '{"spec":{"clusterDeploymentName":{"name": "cluster1", "namespace": "cluster1"}}}' --type merge agent
```

# Approve agents
oc get agent -n my-infraenv -ojson | jq -r '.items[] | select(.spec.approved==false) | .metadata.name'| xargs oc -n my-infraenv patch -p '{"spec":{"approved":true}}' --type merge agent

# Wait for installation process to complete
while true; do oc get agent -n my-infraenv -ojson  | jq -r '.items[] | "\(.status.inventory.hostname) \(.status.role) \(.metadata.name) \(.status.debugInfo.state) \(.status.progress.currentStage)"'| sort ; sleep 10; echo ""; done

# Get kubeconfig and check nodes
oc extract -n cluster1 secret/cluster1-admin-kubeconfig --to=- > cluster1-kubeconfig
KUBECONFIG=cluster1-kubeconfig oc get node

# Day 2 operations
We will start a new node after the cluster has been provisioned

# Boot the machine with the same ISO
```
make ztp-day2
```

# Wait for agent to pop up
```
oc get agent -n my-infraenv -w
```

# Bind to cluster and approve agent
```
oc get agent -n my-infraenv -ojson | jq -r '.items[] | select(.spec.approved==false) | .metadata.name' | xargs oc -n my-infraenv patch -p '{"spec":{"clusterDeploymentName":{"name": "cluster1", "namespace": "cluster1"}}}' --type merge agent
oc get agent -n my-infraenv -ojson | jq -r '.items[] | select(.spec.approved==false) | .metadata.name'| xargs oc -n my-infraenv patch -p '{"spec":{"approved":true}}' --type merge agent
```

# Monitor agent/node status
We will monitor the state of the agent, and at some point it will get stuck in . Then we proceed to next step
```
while true; do oc get agent -n my-infraenv -ojson  | jq -r '.items[] | "\(.status.inventory.hostname) \(.status.role) \(.metadata.name) \(.status.debugInfo.state) \(.status.progress.currentStage)"'| sort ; sleep 10; echo ""; done
```

# Approve CertificateSigningRequest
Now we wait until a CertificateSigningRequest is created in cluster1, and we will need to approve it. Once approved, a new CSR will be created, and we need to also approve it too


```
KUBECONFIG=cluster1-kubeconfig oc get csr -w | grep Pending
KUBECONFIG=cluster1-kubeconfig oc get csr -o json | jq '.items[] | select(.status.conditions==null) | .metadata.name' -r | KUBECONFIG=cluster1-kubeconfig xargs -n1 oc adm certificate approve
KUBECONFIG=cluster1-kubeconfig oc get csr -w | grep Pending
KUBECONFIG=cluster1-kubeconfig oc get csr -o json | jq '.items[] | select(.status.conditions==null) | .metadata.name' -r | KUBECONFIG=cluster1-kubeconfig xargs -n1 oc adm certificate approve
```

# Wait for node to be appear as Ready
```
KUBECONFIG=cluster1-kubeconfig oc get node -w
```
