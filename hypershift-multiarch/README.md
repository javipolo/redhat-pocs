# Demonstrating autoscaling on an hypershift cluster + agent CAPI provider

This is an extension to the "[Using hypershift and cluster-api-agent-provider](https://github.com/javipolo/openshift-assisted-installer-tests/tree/main/test-capi-agent-provider)" demonstration

## Prerequisites
- Save the secret obtained from [cloud.openshift.com](https://cloud.redhat.com/openshift/install/pull-secret) to
`pull_secret.json`
- provision a HUB cluster. For simplicity we will deploy the cluster using [dev-scripts](https://github.com/openshift-metal3/dev-scripts)


### Deploying a HUB cluster using dev-scripts
Edit config.sh to fit your environment (especially `WORKING_DIR` and `CI_TOKEN`)
```
git clone https://github.com/openshift-metal3/dev-scripts.git
cd dev-scripts
ln -s ../config.sh config_$USER.sh
ln -s ../pull_secret.json
make all assisted
cp ocp/dev/auth/kubeconfig ~/.kube/config
oc patch storageclass assisted-service -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
cd ..
```

### Create tunnel

We need to first gather the main IP address in both the x86 host, and in the arm host

```
# Get IPs
# HUB
ip -o -4 a
# ARM
ip -o -4 a
```

And then configure the tunnel also in each of the hosts
```
# Add tunnel
# HUB
ip link add name ipip0 type ipip local 10.1.155.22 remote 10.8.1.154
ip link set ipip0 up
ip a add 10.10.10.1/30 dev ipip0
iptables -I FORWARD -i ipip0 -j ACCEPT
# using 192.168.133.0/24 as the CIDR for VMs in ARM host
ip route add 192.168.133.0/24 via 10.10.10.1

# ARM
ip link add name ipip0 type ipip local 10.8.1.154 remote 10.1.155.22
ip link set ipip0 up
ip a add 10.10.10.2/30 dev ipip0
iptables -I FORWARD -i ipip0 -j ACCEPT
# dev-scripts uses 192.168.111.0/24 as CIDR for VMs
ip route add 192.168.111.0/24 via 10.10.10.1

ping -c 1 192.168.111.20
```

## Provision an hypershift cluster
```
NAMESPACE=multiarch
CLUSTERNAME=multiarch
INFRAENV=multiarch
BASEDOMAIN=redhat.com
SSHKEY=~/.ssh/id_rsa.pub
OCP_RELEASE=quay.io/openshift-release-dev/ocp-release:4.11.0-0.nightly-multi-2022-06-22-080235

# Install hypershift
HYPERSHIFT_IMAGE=quay.io/hypershift/hypershift-operator:latest
alias hypershift="podman run --net host --rm --entrypoint /usr/bin/hypershift -e KUBECONFIG=/working_dir/dev-scripts/ocp/dev/auth/kubeconfig -v $HOME/.ssh:/root/.ssh -v $(pwd):/working_dir $HYPERSHIFT_IMAGE"
hypershift install --hypershift-image $HYPERSHIFT_IMAGE

# Create namespace
oc create namespace $NAMESPACE

# Create hypershift cluster
hypershift create cluster agent --name $CLUSTERNAME --base-domain $BASEDOMAIN --pull-secret /working_dir/pull_secret.json  --ssh-key $SSHKEY --agent-namespace $NAMESPACE --namespace $NAMESPACE  --release-image $OCP_RELEASE

# Wait for hypershift cluster
oc get po -n $NAMESPACE-$CLUSTERNAME -w

# Generate full kubeconfig
hypershift create kubeconfig > ~/.kube/configs/kubeconfig.hyper
eval 'KUBECONFIG=$(ls ~/.kube/configs/*| paste -s -d:) oc config view --flatten' > ~/.kube/config

# Now we should have a running hypershift cluster with no worker nodes
# Since we have no workers, we can see that we have pods in Pending state
oc --context $NAMESPACE-$CLUSTERNAME get po -A
```

## Provision ARM worker

### Run on X86 host
```
# Create pull secret
cat << EOF | oc apply -n $NAMESPACE -f -
apiVersion: v1
kind: Secret
type: kubernetes.io/dockerconfigjson
metadata:
  name: my-pull-secret
data:
  .dockerconfigjson: $(cat pull_secret.json | base64 -w0)
EOF

# Create infraenv for ARM architecture
cat << EOF | oc apply -n $NAMESPACE -f -
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: ${INFRAENV}-arm
spec:
  cpuArchitecture: arm64
  pullSecretRef:
    name: my-pull-secret
  sshAuthorizedKey: $(cat $SSHKEY)
EOF

# Get the URL to be used in next step, in the ARM host
oc get infraenv ${INFRAENV}-arm -n $NAMESPACE -o json| jq -r .status.isoDownloadURL
```

### Run on ARM host

```
# Download ISO remotely
url=URL_OF_ISO

curl -ko /home/isos/arm.iso "$url"

# Create VM
kcli create vm -P iso=/home/isos/arm.iso -P nets=['{"name":"default","mac":"de:ad:be:ef:ba:ba"}'] -P memory=8192 -P numcpus=8 -P disks=['{"size":120,"pool":"default"}'] arm-01
```

### Run on X86 host

```
# Replace with agentID and patch it
oc get agent -n $NAMESPACE
agent=AGENT_ID

oc get agent -n $NAMESPACE $agent -o yaml | yq -y .spec
oc patch -n $NAMESPACE agent $agent --type merge -p '{ "spec": { "clusterDeploymentName": { "name": "'$CLUSTERNAME'", "namespace": "'$NAMESPACE'"}, "approved": true}}'
oc get agent -n $NAMESPACE $agent -o yaml | yq -y .spec

# Scale cluster
oc scale nodepool -n $NAMESPACE $CLUSTERNAME --replicas=1

# And wait for node to be installed
while true; do oc get agent -n multiarch -o json | jq -r '.items[] | "\(.metadata.name) \(.status.debugInfo.state)"'|sort; sleep 3; done

oc get node --context $NAMESPACE-$CLUSTERNAME -w
oc get po --context $NAMESPACE-$CLUSTERNAME -A
```

## BONUS install also a x86 worker

```
# Create infraenv for x86 architecture
cat << EOF | oc apply -n $NAMESPACE -f -
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: ${INFRAENV}-x86
spec:
  cpuArchitecture: x86_64
  pullSecretRef:
    name: my-pull-secret
  sshAuthorizedKey: $(cat $SSHKEY)
EOF

# Download ISO
oc get infraenv ${INFRAENV}-x86 -n $NAMESPACE -o json| jq -r .status.isoDownloadURL | xargs curl -ko /home/isos/x86.iso

# Create VM
kcli create vm -P iso=/home/isos/x86.iso -P nets=['{"name":"default","mac":"de:ad:be:ef:be:be"}'] -P memory=8192 -P numcpus=8 -P disks=['{"size":120,"pool":"default"}'] x86-01

# Wait for agent to appear
oc get agent -n $NAMESPACE -w

# Replace with agentID and patch it
oc get agent -n $NAMESPACE
agent=

oc get agent -n $NAMESPACE $agent -o yaml | yq -y .spec
oc patch -n $NAMESPACE agent $agent --type merge -p '{ "spec": { "clusterDeploymentName": { "name": "'$CLUSTERNAME'", "namespace": "'$NAMESPACE'"}, "approved": true}}'

# Scale cluster
oc scale nodepool -n $NAMESPACE $CLUSTERNAME --replicas=2

# And wait for node to be installed
while true; do oc get agent -n multiarch -o json | jq -r '.items[] | "\(.metadata.name) \(.status.debugInfo.state)"'|sort; sleep 3; done

oc get node --context $NAMESPACE-$CLUSTERNAME -w
```
