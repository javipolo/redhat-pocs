CLUSTER_NAME ?= compact
CLUSTER_HOST_NUM ?= 3
CLUSTER_OCP_VERSION ?= 4.19.1
CLUSTER_API_VIP ?= 192.168.122.250
CLUSTER_INGRESS_VIP ?= 192.168.122.251
CLUSTER_NETWORK_TYPE ?= OVNKubernetes
# Add extra disk
KCLI_TEMPLATE_CLUSTER ?= -P iso="$(CLUSTER_ISO_PATH)" -P memory=$(KCLI_MEMORY) -P numcpus=$(KCLI_NUMCPUS) -P disks=['$(KCLI_TEMPLATE_DISK)','$(KCLI_TEMPLATE_DISK)']
DAY2_ISO ?= $(ISO_DIR)/$(CLUSTER_NAME)2.iso

include ../Makefile.globals

.PHONY: vms
vms: ## Provision cluster nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:da"}'] $(CLUSTER_NAME)-1
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:db"}'] $(CLUSTER_NAME)-2
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:dc"}'] $(CLUSTER_NAME)-3

.PHONY: assisted-local-cluster-import
assisted-local-cluster-import: ## Enable local-cluster import in assisted service
	oc annotate agentserviceconfig agent agent-install.openshift.io/enable-local-cluster-import=true
	oc wait agentserviceconfig agent --for=condition=LocalClusterManaged

.PHONY: day2-iso-download
day2-iso-download: ## Download day2 ISO for local-cluster
	oc get infraenv -n local-cluster local-cluster -ojsonpath={.status.isoDownloadURL} | xargs curl -k -o $(DAY2_ISO)

.PHONY: extra-vms
CLUSTER_ISO_PATH=$(DAY2_ISO)
extra-vms: ## Provision cluster nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:dd"}'] $(CLUSTER_NAME)-4

.PHONY: wait-for-agent
wait-for-agent: ## Wait for day2 agent to show up
	@echo "Waiting for agent"
	@until oc get agent -n local-cluster -oname | grep .; do sleep 1; done

.PHONY: approve-agent
approve-agent: ## Approve agent for day2 node installation
	@echo "Approving agent"
	oc get agent -n local-cluster -ojson | jq -r '.items[] | select(.spec.approved==false) | .metadata.name' | xargs oc -n local-cluster patch -p '{"spec":{"approved":true}}' --type merge agent

.PHONY: rm-worker-role-from-cp
rm-worker-role-from-cp: ## Remove the worker role from control plane nodes
	oc patch scheduler cluster --type merge -p '{"spec":{"mastersSchedulable":false}}'

.PHONY: clean-vms
clean-vms: ## Delete cluster nodes
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-1
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-2
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-3
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-4

.PHONY: clean
clean: clean-vms clean-cluster
