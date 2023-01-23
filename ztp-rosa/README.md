# Create ROSA HUB cluster and get kubeconfig

```
# Create and install cluster
CLUSTERNAME=$USERNAME
rosa create cluster --cluster-name=$CLUSTERNAME
rosa create idp --cluster=$USERNAME --type=htpasswd
rosa grant user cluster-admin --user=$USERNAME --cluster=$CLUSTERNAME
```

Copy ROSA kubeconfig to ~/.kube/config

# VPN configuration

## Overview
We will be creating a site to site VPN connection that will link together the client networks with the ROSA VPC:

[ 192.168.111.0/24 ] <----> [ CLIENT ] <====vpn====> [ SERVER ] <----> [ ROSA Subnets ]

This way, 192.168.111.0/24 network will be able to ping and access ROSA hosts, and from within the ROSA cluster we will be able to access hosts in the 192.168.111.0/24 network

We will use the subnet 192.168.250.0/24 to link client and server through the VPN

## Prerequisites
We will need epel-release repository to install openvpn in both server and client. We will also need easy-rsa in our workstation or wherever we want to generate the certificates
```
sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
sudo dnf install -y openvpn
sudo dnf install -y easy-rsa
```

We will need IP forwarding enabled in both server and client
```
sudo tee /etc/sysctl.d/99-ip_forward.conf <<< "net.ipv4.ip_forward = 1"
sudo systemctl restart systemd-sysctl
```

## Configuration/Customization
We will set a few environment variables to define IPs and networks
```
# Public IP address of VPN server
SERVER_IP=1.2.3.4
AWS_SSH_KEY=~/.ssh/my_aws_key
# Client network that we want to route through the VPN
CLIENT_NETWORK=192.168.111.0
CLIENT_NETMASK=255.255.255.0
# ROSA network that we want to route through the VPN
ROSA_NETWORK=10.0.0.0
ROSA_NETMASK=255.255.0.0
# Network used on the VPN links (not important, only make sure it wont collision your existing networks)
VPN_NETWORK=192.168.250.0
VPN_NETMASK=255.255.255.0
```

## Generate keys
Install easy-rsa and generate keys and certificates that will be used for authentication
```
# Create alias to be more confortable
alias easyrsa=$(find /usr/share/easy-rsa -type f -name easyrsa)

# Create a directory to work
mkdir easyrsa
cd easyrsa

# Init directory
easyrsa init-pki

# Create CA
easyrsa build-ca

# Create server certificate
easyrsa gen-req rosa-server nopass
easyrsa sign-req server rosa-server

# Create client certificate
easyrsa gen-req rosa-client nopass
easyrsa sign-req client rosa-client

# Generate DH key
easyrsa gen-dh

cd ..
```

## VPN Server
### VPN server configuration
```
# Create config
mkdir -p rosa-server/ccd
cp easyrsa/pki/ca.crt rosa-server/rosa-ca.crt
cp easyrsa/pki/dh.pem rosa-server/rosa-dh.pem
cp easyrsa/pki/issued/rosa-server.crt easyrsa/pki/private/rosa-server.key rosa-server/
cat > rosa-server/rosa.conf << EOF
port 1194
proto tcp
dev tun

ca rosa-ca.crt
cert rosa-server.crt
key rosa-server.key
dh rosa-dh.pem

# Network Configuration - Internal network
server $VPN_NETWORK $VPN_NETMASK
# Routes to push to clients
push "route $ROSA_NETWORK $ROSA_NETMASK"

# Networks to be routed to client
client-config-dir ccd
route $CLIENT_NETWORK $CLIENT_NETMASK

# Enable multiple clients to connect with the same certificate key
# duplicate-cn

# TLS Security
cipher AES-256-CBC
tls-version-min 1.2
tls-cipher TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-128-GCM-SHA256:TLS-DHE-RSA-WITH-AES-128-CBC-SHA256
auth SHA512
auth-nocache

# Other Configuration
keepalive 20 60
persist-key
persist-tun
daemon
user nobody
group nobody
verb 3
EOF

# Client routes
cat > rosa-server/ccd/rosa-client << EOF
iroute $CLIENT_NETWORK $CLIENT_NETMASK
EOF

# copy files to the VPN server. We use tar to directly extract on /etc/openvpn/server so files have proper selinux contexts
tar czC rosa-server . | ssh client_ip sudo tar xvzC /etc/openvpn/server
```

### Start OpenVPN server
```
systemctl start openvpn-server@rosa
systemctl status openvpn-server@rosa
```

## VPN client
### VPN client configuration
```
# Create configs
mkdir rosa-client
cp easyrsa/pki/ca.crt rosa-client/rosa-ca.crt
cp easyrsa/pki/issued/rosa-client.crt easyrsa/pki/private/rosa-client.key rosa-client/
cat > rosa-client/rosa.conf << EOF
client
dev tun
proto tcp

remote $SERVER_IP 1194

ca rosa-ca.crt
cert rosa-client.crt
key rosa-client.key

cipher AES-256-CBC
auth SHA512
auth-nocache
tls-version-min 1.2
tls-cipher TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-128-GCM-SHA256:TLS-DHE-RSA-WITH-AES-128-CBC-SHA256

resolv-retry infinite
nobind
persist-key
persist-tun
mute-replay-warnings
verb 3
daemon
EOF

# copy files to the VPN client machine. We use tar to directly extract on /etc/openvpn/client so files have proper selinux contexts
tar czC rosa-client . | ssh -i $AWS_SSH_KEY ec2-user@$SERVER_IP sudo tar xvzC /etc/openvpn/client
```

### Start OpenVPN client

```
systemctl start openvpn-client@rosa
systemctl status openvpn-client@rosa
```

### AWS networking settings

#### Update route tables
We need to update ROSA's VPC route tables to add the route towards $CLIENT_NETWORK
VPC -> Route tables -> Filter rosas's route tables -> Add route to each:
$CLIENT_NETWORK/$CLIENT_NETMASK via the VPN instance that we just created

#### Disable src-dest check on network interface
We need to disable src-dest check on the network interface of the VPN server:
Instance -> Select the openvpn instance -> Networking -> Network interfaces -> Click on the name of network interface
There select the network interface, and:
Actions -> Change source/dest. check -> Uncheck enable, and save

#### Allow traffic to masters metal3-media port
Modify the security group of the ROSA master nodes to allow traffic to the tcp port 6183
I allowed traffic from anywhere, since it's in a private network, but allowing only traffic from $CLIENT_NETWORK should be enough

### Tweak VPN server firewalling and NAT

```
# Allow forwarding traffic that comes through the VPN
iptables -I FORWARD -j ACCEPT -i tun0
# Disable NAT for traffic going to the VPN
iptables -t nat -I POSTROUTING -o tun0 -j ACCEPT
```

# Enable Metal platform

```
cat << EOF | oc apply -f -
apiVersion: metal3.io/v1alpha1
kind: Provisioning
metadata:
  name: provisioning-configuration
spec:
  provisioningNetwork: "Disabled"
  watchAllNamespaces: true
EOF
```

# Install RHACM

```
oc create namespace open-cluster-management
oc create secret generic pull-secret -n open-cluster-management --from-file=.dockerconfigjson=../pull_secret.json --type=kubernetes.io/dockerconfigjson

cat << EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: acm-operator
  namespace: open-cluster-management
spec:
  targetNamespaces:
  - open-cluster-management

---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: acm-operator-subscription
  namespace: open-cluster-management
spec:
  sourceNamespace: openshift-marketplace
  source: redhat-operators
  channel: release-2.6
  installPlanApproval: Automatic
  name: advanced-cluster-management

EOF
```

# Wait for CRD and install MCH
```
oc get csv -n open-cluster-management -w
oc get po -n open-cluster-management -w
```

# Create MultiClusterHub
```
cat << EOF | oc apply -f -
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: open-cluster-management
spec: {}
EOF
```

# And wait for everything to be deployed
```
oc get mch -n open-cluster-management -w
oc get po -n open-cluster-management -w
```

# Setup assisted-service
```
cat << EOF | oc apply -f -
apiVersion: agent-install.openshift.io/v1beta1
kind: AgentServiceConfig
metadata:
  name: agent
  namespace: open-cluster-management
spec:
  databaseStorage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 40Gi
  filesystemStorage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 40Gi
  osImages:
    - openshiftVersion: "4.12"
      version: 412.86.202208101039-0
      url: "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/pre-release/4.12.0-ec.2/rhcos-4.12.0-ec.2-x86_64-live.x86_64.iso"
      rootFSUrl: "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/pre-release/4.12.0-ec.2/rhcos-4.12.0-ec.2-x86_64-live-rootfs.x86_64.img"
      cpuArchitecture: "x86_64"
EOF
```

# Create ClusterImageSet

```
cat << EOF | oc apply -f -
apiVersion: hive.openshift.io/v1
kind: ClusterImageSet
metadata:
  name: openshift-v4.12
  namespace: open-cluster-management
spec:
  releaseImage: quay.io/openshift-release-dev/ocp-release:4.12.0-rc.1-x86_64
EOF
```

# Define some variables
```
NAMESPACE=cluster1
CLUSTERNAME=cluster1
INFRAENV=myinfraenv
```

# Create spoke cluster

In AgentClusterInstall we define the spoke cluster configuration
in imageSetRef we put the reference to the ClusterImageSet resource that defines the openshift release that we want to install

```
oc create namespace $NAMESPACE
oc create secret generic assisted-deployment-pull-secret -n $NAMESPACE --from-file=.dockerconfigjson=../pull_secret.json --type=kubernetes.io/dockerconfigjson

cat << EOF | oc apply -f -
---
apiVersion: extensions.hive.openshift.io/v1beta1
kind: AgentClusterInstall
metadata:
  name: $CLUSTERNAME
  namespace: $NAMESPACE
spec:
  clusterDeploymentRef:
    name: $CLUSTERNAME
  imageSetRef:
    name: openshift-v4.12
  apiVIP: "192.168.111.220"
  ingressVIP: "192.168.111.221"
  networking:
    clusterNetwork:
      - cidr: "172.20.0.0/22"
        hostPrefix: 25
    serviceNetwork:
      - "172.21.0.0/24"
    # machineNetwork:
    #   - cidr: "192.168.111.0/24"
  provisionRequirements:
    controlPlaneAgents: 3
    workerAgents: 2
  sshPublicKey: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDVMrusn8G4xSqVL98NUGIqDvDQK3MwiLenSDmZXZeH92djIhEi7wdecIc3s8KQ0EG16Avi5qs7rp1X8dmACNLY6O/WPeF8LhuC3+T8f1+rE3O+GQ/VFrCSUxQNrZZ92+o6FQPW9A9+OGcwL+ywBN2HKf3G15mX44Q/W4KnQ7dubwXHRYUX4vDiz7XplxU5tyC5eszYDQZ87ljnxPM6ZRglINkGqgacyDBiuV7GRrnPH7V1PAb/vOSRaJrRmJoiZqgurFd5xtK0kmUrLEUGzNfi3H+qLL6oujN2g4SOZZ/HFPPpXbfSO5gpQ5ote3BBsLOu+ovBYhiKoowEWMs1kNPVqKoV8PxOjrcJZ1r0Vx3c4FPGmleR179hxFE0AHfCioU+UOAJkplM9ZhwuMM+09fHVYRmCiFoIxXkm0hsJdfww4VKROqpIF5oLW9+0oZY5VPgWClko3Y/eqdHvyuNt6LOitm8S5oDyyZlCGfg0C1W9SBbaiJwBjbOZZDeQ4wak08="

---
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  name: $CLUSTERNAME
  namespace: $NAMESPACE
spec:
  baseDomain: redhat.com
  clusterName: $CLUSTERNAME
  controlPlaneConfig:
    servingCertificates: {}
  installed: false
  clusterInstallRef:
    group: extensions.hive.openshift.io
    kind: AgentClusterInstall
    name: $CLUSTERNAME
    version: v1beta1
  platform:
    agentBareMetal:
      agentSelector:
        matchLabels:
          infraenv: $INFRAENV
  pullSecretRef:
    name: assisted-deployment-pull-secret

---
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: $CLUSTERNAME
  namespace: $NAMESPACE
spec:
  clusterName: $CLUSTERNAME
  clusterNamespace: $NAMESPACE
  clusterLabels:
    cloud: auto-detect
    vendor: auto-detect
  applicationManager:
    enabled: false
  certPolicyController:
    enabled: false
  iamPolicyController:
    enabled: false
  policyController:
    enabled: false
  searchCollector:
    enabled: false

---
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: $CLUSTERNAME
  namespace: $NAMESPACE
spec:
  hubAcceptsClient: true
EOF
```

# Create infraenv
```
cat << EOF | oc apply -f -
---
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: $INFRAENV
  namespace: $NAMESPACE
spec:
  clusterRef:
    name: $CLUSTERNAME
    namespace: $NAMESPACE
  agentLabels:
    infraenv: $INFRAENV
  sshAuthorizedKey: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDVMrusn8G4xSqVL98NUGIqDvDQK3MwiLenSDmZXZeH92djIhEi7wdecIc3s8KQ0EG16Avi5qs7rp1X8dmACNLY6O/WPeF8LhuC3+T8f1+rE3O+GQ/VFrCSUxQNrZZ92+o6FQPW9A9+OGcwL+ywBN2HKf3G15mX44Q/W4KnQ7dubwXHRYUX4vDiz7XplxU5tyC5eszYDQZ87ljnxPM6ZRglINkGqgacyDBiuV7GRrnPH7V1PAb/vOSRaJrRmJoiZqgurFd5xtK0kmUrLEUGzNfi3H+qLL6oujN2g4SOZZ/HFPPpXbfSO5gpQ5ote3BBsLOu+ovBYhiKoowEWMs1kNPVqKoV8PxOjrcJZ1r0Vx3c4FPGmleR179hxFE0AHfCioU+UOAJkplM9ZhwuMM+09fHVYRmCiFoIxXkm0hsJdfww4VKROqpIF5oLW9+0oZY5VPgWClko3Y/eqdHvyuNt6LOitm8S5oDyyZlCGfg0C1W9SBbaiJwBjbOZZDeQ4wak08="
  pullSecretRef:
    name: assisted-deployment-pull-secret
EOF
```

# Check that the ISO image has been created
```
oc get infraenv $INFRAENV -n $NAMESPACE -o json| jq -r .status.isoDownloadURL| xargs curl -kI
```

# Create BareMetalHosts

```
# Ensure proper network permissions are met
firewall-cmd --zone=public --add-port=8000/tcp

# Create BareMetalHosts
cat  bmh-manifests.yaml | sed "s/assisted-installer/$NAMESPACE/g; s/myinfraenv/$INFRAENV/g" | oc apply -f -

# And wait until the baremetalhosts boot and register their respective agents
oc get -n $NAMESPACE agent -w
```

# Wait for installation process to complete
```
while true; do oc get agent -n $NAMESPACE -ojson  | jq -r '.items[] | "\(.status.inventory.hostname) \(.status.role) \(.metadata.name) \(.status.debugInfo.state) \(.status.progress.currentStage)"'| sort ; sleep 10; echo ""; done

# Get kubeconfig and check nodes
oc extract -n cluster1 secret/cluster1-admin-kubeconfig --to=- > cluster1-kubeconfig
KUBECONFIG=cluster1-kubeconfig oc get node
```
