CLUSTER_NAME ?= big-cluster
CLUSTER_HOST_NUM ?= 6
CLUSTER_OCP_VERSION ?= 4.19
CLUSTER_API_VIP ?= 192.168.122.250
CLUSTER_INGRESS_VIP ?= 192.168.122.251
CLUSTER_NETWORK_TYPE ?= OVNKubernetes

# Include 3 disks
KCLI_TEMPLATE_DISK ?= ${KCLI_TEMPLATE_ONE_DISK},${KCLI_TEMPLATE_ONE_DISK},${KCLI_TEMPLATE_ONE_DISK}

include ../Makefile.globals

vms: ## Provision cluster nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:da"}'] $(CLUSTER_NAME)-1
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:db"}'] $(CLUSTER_NAME)-2
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:dc"}'] $(CLUSTER_NAME)-3
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:dd"}'] $(CLUSTER_NAME)-4
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:de"}'] $(CLUSTER_NAME)-5
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:df"}'] $(CLUSTER_NAME)-6

clean-vms: ## Delete cluster nodes
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-1
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-2
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-3
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-4
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-5
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-6

clean: clean-vms clean-cluster
