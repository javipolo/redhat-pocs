# Openshift Multi Architecture heterogeneous cluster provisioned with Assisted Installer

In this PoC we will show how to install a openshift cluster with x86 control plane, and arm worker nodes

## In X86 node
```
# Start custom assisted install with podman
make assisted

# Create the cluster
make cluster

# Configure cluster as day2, so it allows installation of new nodes
make set-allow-add-workers

# Create ARM infraenv
make arm-infraenv

# Create IPIP tunnel to the ARM node
make tunnel
```

## In ARM node
```
# Create IPIP tunnel
make tunnel

# Download iso, and start new VM
make arm-iso
make arm-vms
```

## In X86 node
```
# Wait for host to be registered and in known state
while true; do aicli -U $ASSISTED_SERVICE list hosts: sleep 20; done

# Start installation
make arm-install

# Wait for CSRs to appear, and approve them (we need to approve two of them)
oc get csr -w
oc adm certificate approve CSR_ID

# See that the arm host is added to the cluster
oc get node -w
```
