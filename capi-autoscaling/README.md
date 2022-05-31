# Demonstrating autoscaling on an hypershift cluster + agent CAPI provider

This is an extension to the "[Using hypershift and cluster-api-agent-provider](https://github.com/javipolo/openshift-assisted-installer-tests/tree/main/test-capi-agent-provider)" demonstration

## Prerequisites
- Save the secret obtained from [cloud.openshift.com](https://cloud.redhat.com/openshift/install/pull-secret) to
`pull_secret.json`
- provision a HUB cluster. For simplicity we will deploy the cluster using [dev-scripts](https://github.com/openshift-metal3/dev-scripts)


### Deploying a HUB cluster using dev-scripts
Edit config.sh to fit your environment (especially `WORKING_DIR` and `CI_TOKEN`)
~~~bash
git clone https://github.com/openshift-metal3/dev-scripts.git
cd dev-scripts
ln -s ../config.sh config_$USER.sh
ln -s ../pull_secret.json
make all assisted
cp ocp/dev/auth/kubeconfig ~/.kube/config
oc patch storageclass assisted-service -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true}}'
cd ..
~~~

## Steps to provision a minimal hypershift cluster
~~~bash
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
  .dockerconfigjson: $(cat pull_secret.json | base64 -w0)
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
~~~

Now we should have a running hypershift cluster with no worker nodes
Since we have no workers, we can see that we have pods in Pending state
~~~bash
oc --context $NAMESPACE-$CLUSTERNAME get po -A
~~~

## Enable autoscaling
To enable autoscaling, we should change `replicas` for `autoScaling` in `NodePool` spec:
~~~bash
oc patch nodepool -n $NAMESPACE $CLUSTERNAME --type=json -p '[{"op": "remove", "path": "/spec/replicas"},{"op":"add", "path": "/spec/autoScaling", "value": { "max": 4, "min": 1 }}]'
~~~

This should aready trigger an scale up to accomodate all the current pending pods
We can check the agents status, until the agent is marked as `added-to-existing-cluster`
~~~bash
while true; do oc get agent -n mynamespace --context dev -o json | jq -r '.items[] | "\(.metadata.labels."agent-install.openshift.io/bmh") \(.metadata.name) \(.status.debugInfo.state)"'|sort; sleep 3; done
~~~

And then wait for the node to be finally added to the cluster:
~~~bash
oc --context $NAMESPACE-$CLUSTERNAME get node -w
~~~

## Triggering scale up and down
We're going to create a dummy deployment of nginx, with huge memory requirements, to trigger scale ups and downs by scaling this deployment:
~~~bash
oc --context $NAMESPACE-$CLUSTERNAME create deployment nginx --image=quay.io/jpolo/nginx:latest --replicas=0
oc --context $NAMESPACE-$CLUSTERNAME set resources deployment nginx --requests=memory=2Gi
~~~

### Scale up
If we scale this up, we can see that this triggers a new scale up, and the new node provisioning process kicks in:
~~~bash
# Scale up deployment
oc --context $NAMESPACE-$CLUSTERNAME scale deployment nginx --replicas=30

# Get events to see how a node scale up is triggered
oc get --context $NAMESPACE-$CLUSTERNAME po --field-selector status.phase=Pending -n default -ojsonpath='{.items[].metadata.name}' \
    | xargs -i% oc --context $NAMESPACE-$CLUSTERNAME get events --field-selector involvedObject.name=%
~~~

We can check the agents status, until the agents are marked as `added-to-existing-cluster`
~~~bash
while true; do oc get agent -n mynamespace --context dev -o json | jq -r '.items[] | "\(.metadata.labels."agent-install.openshift.io/bmh") \(.metadata.name) \(.status.debugInfo.state)"'|sort; sleep 3; done
~~~

And then wait for the nodes to be finally added to the cluster:
~~~bash
oc --context $NAMESPACE-$CLUSTERNAME get node -w
~~~

### Scale down
Now we can do the reverse process and see how removing nginx replicas triggers a scale down of the cluster

~~~bash
oc --context $NAMESPACE-$CLUSTERNAME scale deployment nginx --replicas=10
~~~

We can check that cluster-autoscaler decides that a scale down is needed, and performs the scale down process. With default settings of cluster-autoscaler, this process takes between 10 and 15 minutes

~~~bash
oc logs -n $NAMESPACE-$CLUSTERNAME -l app=cluster-autoscaler --tail 10 -f
~~~

We can check the agents status
~~~bash
while true; do oc get agent -n mynamespace --context dev -o json | jq -r '.items[] | "\(.metadata.labels."agent-install.openshift.io/bmh") \(.metadata.name) \(.status.debugInfo.state)"'|sort; sleep 3; done
~~~

#### libvirt + baremetal-controller bug

If we're running nodes in libvirt and we see the agents in `pending-user-action` state, we probably hit a bug that happens when reprovisioning an existing node. To workaround this we simply run the workaround script and this will unlock the nodes and boot again the discovery ISO, able to be reused

~~~bash
./workaround
# We'll see how the agent goes back to known-unbound state, able to be reused
while true; do oc get agent -n $NAMESPACE -o json | jq -r '.items[] | "\(.metadata.labels."agent-install.openshift.io/bmh") \(.metadata.name) \(.status.debugInfo.state)"'|sort; sleep 3; done
~~~

Now we should see the nodes being removed from the cluster

~~~bash
oc --context $NAMESPACE-$CLUSTERNAME get node -w
~~~
