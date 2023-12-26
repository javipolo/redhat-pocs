#!/bin/bash
set -e

MASTER_IP=$(virsh domifaddr ${VM_NAME} | grep ipv4 | awk -F " " '{print $4}' | cut -d'/' -f1)
CLUSTER_ID=$(uuidgen)

sed -e "s/REPLACE_CLUSTER_ID/${CLUSTER_ID}/" \
-e "s/REPLACE_MASTER_IP/${MASTER_IP}/" \
-e "s/REPLACE_CLUSTER_NAME/$CLUSTER_NAME/" \
-e "s/REPLACE_DOMAIN/$DOMAIN/" \
-e "s/REPLACE_HOSTNAME/$HOSTNAME/" \
$1 > $2 

