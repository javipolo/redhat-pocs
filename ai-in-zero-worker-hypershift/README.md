# assisted-service as a control-plane service in a zero worker Hypershift cluster

The goal of this PoC is to deploy assisted-service in a zero-worker hypershift cluster, running as part of the control plane
This mode of operation will run all required pods in L0 hub cluster, in the namespace-clustername namespace, but will be monitoring and validating resources created in L1 hypershift cluster

## Provision base L0 hub and L1 hypershift clusters

First of all I'm gonna deploy a Openshift cluster with assisted installer using dev-scripts

### Deploy an L0 hub cluster using dev-scripts
```
git clone https://github.com/openshift-metal3/dev-scripts
cd dev-scripts
ln -s ../../pull-secret.json pull_secret.json
ln -s ../config.sh config_$USER.sh

make all assisted
sed s/admin/dev/g ocp/dev/auth/kubeconfig > ~/.kube/configs/kubeconfig.dev
eval 'KUBECONFIG=$(ls ~/.kube/configs/*| paste -s -d:) oc config view --flatten' > ~/.kube/config
oc config get-contexts
oc patch storageclass assisted-service -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
cd ..
```

### Set up our environment
```
AGENT_NAMESPACE=myclusters
CLUSTERNAME=acm-1
CLUSTER_NAMESPACE=${AGENT_NAMESPACE}-${CLUSTERNAME}
BASEDOMAIN=redhat.com
SSHKEY=~/.ssh/id_rsa.pub
```

### Install hypershift
```
HYPERSHIFT_IMAGE=quay.io/hypershift/hypershift-operator:latest
alias hypershift="podman run --net host --rm --entrypoint /usr/bin/hypershift -e KUBECONFIG=/credentials/kubeconfig -v $HOME/.ssh:/root/.ssh -v $(pwd)/dev-scripts/ocp/dev/auth/kubeconfig:/credentials/kubeconfig -v $(pwd)/../pull-secret.json:/credentials/pull-secret.json $HYPERSHIFT_IMAGE"
hypershift install --hypershift-image $HYPERSHIFT_IMAGE
```

### Create hypershift cluster
```
# Create namespace
oc create namespace $AGENT_NAMESPACE

# Create hypershift cluster
hypershift create cluster agent --name $CLUSTERNAME --base-domain $BASEDOMAIN --pull-secret /credentials/pull-secret.json  --ssh-key $SSHKEY --agent-namespace $AGENT_NAMESPACE --namespace $AGENT_NAMESPACE

# Wait for hypershift cluster
oc get po -n $CLUSTER_NAMESPACE -w

# Generate full kubeconfig
hypershift create kubeconfig --name $CLUSTERNAME --namespace $AGENT_NAMESPACE | sed s/admin/$CLUSTERNAME/g > ~/.kube/configs/kubeconfig.$CLUSTERNAME
eval 'KUBECONFIG=$(ls ~/.kube/configs/*| paste -s -d:) oc config view --flatten' > ~/.kube/config

# Now we should have a running hypershift cluster with no worker nodes
# Since we have no workers, we can see that we have pods in Pending state
oc --context $CLUSTERNAME get po -A
```

## Install assisted service in hypershift's control-plane


### Install HIVE dependency CRDs
```
oc --context $CLUSTERNAME apply -f https://raw.githubusercontent.com/openshift/assisted-service/master/hack/crds/hive.openshift.io_clusterdeployments.yaml
oc --context $CLUSTERNAME apply -f https://raw.githubusercontent.com/openshift/assisted-service/master/hack/crds/hive.openshift.io_clusterimagesets.yaml
oc --context $CLUSTERNAME apply -f https://raw.githubusercontent.com/openshift/assisted-service/master/hack/crds/metal3.io_baremetalhosts.yaml
```

### Install assisted-service CRDs
```
git clone https://github.com/openshift/assisted-service
cd assisted-service
go mod vendor
go install golang.org/x/tools/cmd/goimports@latest
go install sigs.k8s.io/controller-tools/cmd/controller-gen@v0.4.0
KUBECONFIG=~/.kube/configs/kubeconfig.$CLUSTERNAME ENABLE_KUBE_API=true make deploy-resources
cd ..
```

### Set up environment
```
export AGENT_NAMESPACE=myclusters
export CLUSTERNAME=acm-1
export NAMESPACE=${AGENT_NAMESPACE}-${CLUSTERNAME}
export CONTEXT_L0=dev
export CONTEXT_L1=$CLUSTERNAME
```

### Deploy assisted-service resources
We have few variables in the yaml definitions, so we need to substitute them using the tpl.sh script:
```
# Create namespace in L1 cluster
deploy/tpl.sh deploy/l1/00-* | oc apply --context $CONTEXT_L1 -f -
# Create serviceaccounts in L1 cluster
deploy/tpl.sh deploy/l1/01-* | oc apply --context $CONTEXT_L1 -f -
# Generate kubeconfigs from L1 serviceaccounts, and save them as secrets in L0
deploy/genKubeConfig.sh assisted-service agentinstalladmission
# Deploy the rest of resources
deploy/tpl.sh deploy/l0/01-* | oc apply --context $CONTEXT_L0 -f -
deploy/tpl.sh deploy/l0/02-* | oc apply --context $CONTEXT_L0 -f -
deploy/tpl.sh deploy/l1/02-* | oc apply --context $CONTEXT_L1 -f -
```
## Test it a little bit
### Create an infraenv
```
oc create --context $CLUSTERNAME ns test

# Create pull secret
oc create --context $CLUSTERNAME secret generic pull-secret -n test --from-file=.dockerconfigjson=pull-secret.json --type=kubernetes.io/dockerconfigjson

# Create infraenv
cat << EOF | oc apply --context $CLUSTERNAME -f -
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: test
  namespace: test
spec:
  pullSecretRef:
    name: pull-secret
EOF

# Check that discovery ISO is generated and downloadable
oc get infraenv --context $CLUSTERNAME -n test test -ojsonpath={.status.isoDownloadURL} | xargs curl -kI

# Look in agentinstalladmission logs that validations have been done for new infraenv
oc logs -n $NAMESPACE -l app=agentinstalladmission
```
