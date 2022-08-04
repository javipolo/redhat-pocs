export REPLACE_NAMESPACE=${AGENT_NAMESPACE}-${CLUSTERNAME}
# Both namespaces have to be the same, otherwise the certificate created for agentinstalladmission will not validate
export REPLACE_NAMESPACE_L1=$REPLACE_NAMESPACE
export REPLACE_WEBHOOK_CABUNDLE=$(oc get cm --context $CONTEXT_L0 -n openshift-service-ca-operator openshift-service-ca.crt -ojsonpath='{.data.service-ca\.crt}' | base64 -w0)
export REPLACE_ASSISTED_KUBECONFIG=managed-assisted-service-kubeconfig
export REPLACE_WEBHOOK_KUBECONFIG=managed-agentinstalladmission-kubeconfig
oc get --context $CONTEXT_L0 -n $REPLACE_NAMESPACE svc agentinstalladmission &>/dev/null && \
    export REPLACE_WEBHOOK_CLUSTER_IP=$(oc get --context $CONTEXT_L0 -n $REPLACE_NAMESPACE svc agentinstalladmission -ojsonpath={.spec.clusterIP})

for i in $@; do
    envsubst < $i
done
