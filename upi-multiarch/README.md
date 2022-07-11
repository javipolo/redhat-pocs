# Openshift heterogeneous cluster with User Provisioned Infrastructure

The goal is to install a openshift cluster with 3 nodes acting as a control plane, running in x86 architecture

Then, we will provision a worker node running in arm64 architecture

## Prerquisites
- Save the secret obtained from [cloud.openshift.com](https://cloud.redhat.com/openshift/install/pull-secret) to
`pull_secret.json`
- Set up DNS, we're using dnsmasq
```
cat << EOF >> /etc/hosts
192.168.122.23 m-haproxy m-haproxy.multiarch.redhat.com
192.168.122.33 m-bstrap m-bstrap.multiarch.redhat.com
192.168.122.34 m-master-1 m-master-1.multiarch.redhat.com
192.168.122.35 m-master-2 m-master-2.multiarch.redhat.com
192.168.122.36 m-master-3 m-master-3.multiarch.redhat.com
192.168.122.23 api.multiarch.redhat.com
192.168.122.23 api-int.multiarch.redhat.com
192.168.122.23 apps.multiarch.redhat.com
192.168.122.23 oauth-openshift.apps.multiarch.redhat.com
192.168.122.23 console-openshift-console.apps.multiarch.redhat.com
EOF

pkill -HUP dnsmasq
```

## Provision cluster
```
# Extract openshift-install
make get-openshift-install

# Create install-config
make create-config

# Create manifests and ignition files
make manifests ignition

# Start a webserver for the ignition files
make webserver

# Download RHCOS live
make get-rhcos

# Provision and configure haproxy
make haproxy-vm
make haproxy-config

# Start VMs on RHCOS live
make vms
```

Now we need to access via console to each of the VMs and run coreos installer with the proper role:
bootstrap
```
virsh console m-bstrap
$ sudo coreos-installer install --insecure-ignition --ignition-url=http://192.168.122.1:12345/bootstrap.ign /dev/vda
$ sudo reboot
```

And in each of the nodes
```
virsh console m-node
$ sudo coreos-installer install --insecure-ignition --ignition-url=http://192.168.122.1:12345/bootstrap.ign /dev/vda
$ sudo reboot
```
