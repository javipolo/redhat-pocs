#!/bin/bash

# Script to extract certificates from a running SNO to be used for IBI during recert phase
# This is just to help development, it will not be the "right way" to do so

set -e # Halt on error

export KUBECONFIG=/etc/kubernetes/static-pod-resources/kube-apiserver-certs/secrets/node-kubeconfigs/lb-ext.kubeconfig

echo "Waiting for API"
until oc get clusterversion &>/dev/null; do
    sleep 5
done

echo "Backing up certificates to be used by recert"
certs_dir=/var/tmp/certs
mkdir -p $certs_dir
oc extract -n openshift-config configmap/admin-kubeconfig-client-ca --keys=ca-bundle.crt --to=- > $certs_dir/admin-kubeconfig-client-ca.crt
for secret in {loadbalancer,localhost,service-network}-serving-signer; do
    oc extract -n openshift-kube-apiserver-operator secret/$secret --keys=tls.key --to=- > $certs_dir/$secret.key
done
oc extract -n openshift-ingress-operator secret/router-ca --keys=tls.key --to=- > "$certs_dir/ingresskey-ingress-operator.key"

tar czf /var/tmp/certs.tgz -C $certs_dir .
