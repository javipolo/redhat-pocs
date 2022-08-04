# Set WORKING_DIR to somewhere with enough disk space
export WORKING_DIR=/home/dev-scripts
#Go to https://console-openshift-console.apps.ci.l2s4.p1.openshiftapps.com/, click on your name in the top right, and use the token from the login command
export CI_TOKEN='mysecrettoken'
source ~/secrets.sh

# Cluster name
export CLUSTER_NAME="dev"
# Domain name
export BASE_DOMAIN="redhat.com"

export OPENSHIFT_VERSION=4.10.13
export OPENSHIFT_RELEASE_TYPE=ga
export IP_STACK=v4
export BMC_DRIVER=redfish-virtualmedia
export REDFISH_EMULATOR_IGNORE_BOOT_DEVICE=True

export NUM_WORKERS=0
export MASTER_VCPU=8
export MASTER_MEMORY=20000
export MASTER_DISK=60

export NUM_EXTRA_WORKERS=4
export WORKER_VCPU=8
export WORKER_MEMORY=35000
export WORKER_DISK=150

export VM_EXTRADISKS=true
export VM_EXTRADISKS_LIST="vda vdb"
export VM_EXTRADISKS_SIZE=120G
