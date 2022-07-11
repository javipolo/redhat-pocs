include ../Makefile.globals

ASSISTED_SERVICE=http://10.1.155.22:8080

CLUSTER_NAME=multiarch
CLUSTER_HOST_NUM=3
CLUSTER_OCP_VERSION=4.11
CLUSTER_OCP_RELEASE=quay.io/openshift-release-dev/ocp-release:4.11.0-0.nightly-multi-2022-07-04-160826-x86_64
CLUSTER_API_VIP=192.168.122.253
CLUSTER_INGRESS_VIP=192.168.122.252
CLUSTER_NETWORK_TYPE=OVNKubernetes

# Tunnel
TUNNEL_DEVICE=ipip0

IP_X86=10.1.155.22
IP_TUNNEL_X86=10.10.10.1
NET_X86=192.168.122.0/24

IP_ARM=10.8.1.154
IP_TUNNEL_ARM=10.10.10.2
NET_ARM=192.168.133.0/24

CPU_TYPE=$(shell uname -m)
ifeq ($(CPU_TYPE), aarch64)
	LOCAL=$(IP_ARM)
	REMOTE=$(IP_X86)
	TUNNEL_LOCAL_IP=$(IP_TUNNEL_ARM)
	TUNNEL_REMOTE_IP=$(IP_TUNNEL_X86)
	SET_ROUTE=$(NET_X86)
else
	LOCAL=$(IP_X86)
	REMOTE=$(IP_ARM)
	TUNNEL_LOCAL_IP=$(IP_TUNNEL_X86)
	TUNNEL_REMOTE_IP=$(IP_TUNNEL_ARM)
	SET_ROUTE=$(NET_ARM)
endif

# kcli/aicli
ifeq ($(CPU_TYPE), aarch64)
	kcli=kcli
	aicli=aicli -U $(ASSISTED_SERVICE)
endif

assisted: ## Start assisted installer on podman
	podman play kube --configmap podman/configmap.yml podman/pod-persistent.yml

clean-assisted: ## Stop assisted installer
	podman play kube --down podman/pod-persistent.yml

vms: ## Provision cluster nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:01"}'] $(CLUSTER_NAME)-1
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:02"}'] $(CLUSTER_NAME)-2
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:03"}'] $(CLUSTER_NAME)-3

set-allow-add-workers: CLUSTER_ID=$(shell $(aicli) info cluster $(CLUSTER_NAME) | yq -r .id)
set-allow-add-workers: ## Update cluster to allow adding new workers
	@curl -XPOST -s $(API_URL)/v2/clusters/$(CLUSTER_ID)/actions/allow-add-workers | jq -r 'if has("code") then . else [.status,.status_info] | join(" ") end'

arm-infraenv: ## Create ARM infraenv
	$(aicli) create infraenv $(CLUSTER_NAME)-arm \
	  -P cluster=$(CLUSTER_NAME) \
	  -P pull_secret=$(CLUSTER_PULL_SECRET) \
	  -P cpu_architecture=arm64

arm-iso: ## Download ARM ISO
	@$(aicli) download iso --path $(git_root) $(CLUSTER_NAME)-arm
	@mv $(git_root)/$(CLUSTER_NAME)-arm.iso $(CLUSTER_ISO_PATH)

arm-install: ## Start installation of arm hosts
	$(aicli) start infraenv $(CLUSTER_NAME)-arm

arm-vms: ## Provision ARM nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:ad:ab:af"}'] arm-01

clean-arm-infraenv:
	@$(aicli) list hosts | awk '/$(CLUSTER_NAME)-arm/{print $$2}' | xargs --no-run-if-empty $(aicli) delete host
	@$(aicli) delete infraenv $(CLUSTER_NAME)-arm

clean-arm-vms: ## Provision ARM nodes
	@$(kcli) delete vm -y arm-01

clean-vms: ## Delete cluster nodes
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-1
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-2
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-3

tunnel: ## Create ipip tunnel
	ip link add name $(TUNNEL_DEVICE) type ipip local $(LOCAL) remote $(REMOTE)
	ip link set $(TUNNEL_DEVICE) up
	ip address add $(TUNNEL_LOCAL_IP)/30 dev $(TUNNEL_DEVICE)
	ip route add $(SET_ROUTE) via $(TUNNEL_REMOTE_IP)
	iptables -I FORWARD -i $(TUNNEL_DEVICE) -j ACCEPT

clean-tunnel:
	ip link del $(TUNNEL_DEVICE)
	iptables -D FORWARD -i $(TUNNEL_DEVICE) -j ACCEPT

clean: clean-vms clean-cluster clean-arm-infraenv clean-tunnel

clean-arm: clean-arm-vms clean-tunnel

tmp:
	@echo $(aicli)
