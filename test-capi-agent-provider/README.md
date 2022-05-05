# Using hypershift and cluster-api-agent-provider

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
oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true}}'
cd ..
```

## Steps to provision a minimal hypershift cluster
```
NAMESPACE=mynamespace
CLUSTERNAME=mycluster
INFRAENV=myinfraenv
BASEDOMAIN=redhat.com
SSHKEY=~/.ssh/id_rsa.pub

# Install hypershift
HYPERSHIFT_IMAGE=quay.io/hypershift/hypershift-operator:latest
podman pull $HYPERSHIFT_IMAGE
alias hypershift="podman run --net host --rm --entrypoint /usr/bin/hypershift -e KUBECONFIG=/working_dir/dev-scripts/ocp/dev/auth/kubeconfig -v $HOME/.ssh:/root/.ssh -v $(pwd):/working_dir $HYPERSHIFT_IMAGE"
hypershift install --hypershift-image $HYPERSHIFT_IMAGE

# Create namespace
oc create namespace $NAMESPACE

# Create pull secret
cat << EOF | oc apply -n $NAMESPACE -f -
apiVersion: v1
kind: Secret
type: kubernetes.io/dockerconfigjson
metadata:
  name: my-pull-secret
data:
  .dockerconfigjson: $(cat ~/dev-scripts/pull_secret.json | base64 -w0)
EOF

# Create infraenv
cat << EOF | oc apply -n $NAMESPACE -f -
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: $INFRAENV
spec:
  pullSecretRef:
    name: my-pull-secret
  sshAuthorizedKey: $(cat $SSHKEY)
EOF

# We should now wait for the ISO image to be created, then we can create the BareMetalHost resources
# If we dont wait enough time we risk that ISO cannot be fetched and hosts start with ironic IPA instead of discovery ISO
oc get po -wA|grep -vE 'Completed|Running'
oc get infraenv $INFRAENV -n $NAMESPACE -o json| jq -r .status.isoDownloadURL| xargs curl -kI

# Create BareMetalHosts
cat  dev-scripts/ocp/dev/saved-assets/assisted-installer-manifests/06-extra-host-manifests.yaml | sed "s/assisted-installer/$NAMESPACE/g; s/myinfraenv/$INFRAENV/g" | oc apply -f -

# And wait until the baremetalhosts boot and register their respective agents
oc get -n $NAMESPACE agent -w

# Create hypershift cluster
hypershift create cluster agent --name $CLUSTERNAME --base-domain $BASEDOMAIN --pull-secret /working_dir/pull_secret.json  --ssh-key $SSHKEY --agent-namespace $NAMESPACE --namespace $NAMESPACE

# Wait for everything to be OK
oc get po -n $NAMESPACE-$CLUSTERNAME -w

# Generate full kubeconfig
KUBECONFIG=dev-scripts/ocp/dev/auth/kubeconfig:<(hypershift create kubeconfig) kubectl config view --flatten > ~/.kube/config
oc config get-contexts
```

Now we should have a running hypershift cluster with no worker nodes


## Scaling up
We can start by scaling up one node and wait until a random node it's added to the cluster

```
oc scale nodepool/$CLUSTERNAME -n $NAMESPACE --replicas=2
# Monitor agents status to see how it's moving through different states, until it is finally added to the cluster
while true; do oc get agent -n $NAMESPACE -o json | jq -r '.items[] | "\(.metadata.labels."agent-install.openshift.io/bmh") \(.metadata.name) \(.status.debugInfo.state)"'|sort; sleep 3; done
# Then we will need to wait for the nodes to be fully provisioned and in a Ready state
oc get node --context $NAMESPACE-$CLUSTERNAME -w
```

## Scaling down

We can scale down the cluster, and a random node will deprovision and the agent will be able for reusing on a future scale-up

```
oc scale nodepool/$CLUSTERNAME -n $NAMESPACE --replicas=1
# There are some bugs sitting around BMAC-BMO, and the agent stays "pending-user-action" so by now we need to run this script to workaround them
./workaround
# We'll see how the agent goes back to known-unbound state
while true; do oc get agent -n $NAMESPACE -o json | jq -r '.items[] | "\(.metadata.labels."agent-install.openshift.io/bmh") \(.metadata.name) \(.status.debugInfo.state)"'|sort; sleep 3; done
```

## Using labels
For scaling up, we can use matchLabels or matchExpressions to instruct the nodepool to only use the matching agents

We can use predefined labels, or set our own labels

```
# Label agents
oc label -n $NAMESPACE agent --selector agent-install.openshift.io/bmh=dev-extraworker-2 tier=custom
oc label -n $NAMESPACE agent --selector agent-install.openshift.io/bmh=dev-extraworker-3 tier=custom
# Patch nodepool
oc patch -n $NAMESPACE nodepool $CLUSTERNAME  --type merge -p '{"spec":{"platform":{"agent":{"agentLabelSelector":{"matchLabels":{"tier":"custom"}}}}}}'
# Now we can see how existing nodes are migrated
# We need the workaround again
./workaround
# And if we scale up we can see how the matching agents are picked up
oc scale nodepool/$CLUSTERNAME -n $NAMESPACE --replicas=2
```
