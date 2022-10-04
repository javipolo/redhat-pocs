include ../Makefile.globals

CLUSTER_NAME=compact
CLUSTER_HOST_NUM=3
CLUSTER_OCP_VERSION=4.11
CLUSTER_API_VIP=192.168.122.253
CLUSTER_INGRESS_VIP=192.168.122.252
CLUSTER_NETWORK_TYPE=OVNKubernetes

vms: ## Provision cluster nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:da"}'] $(CLUSTER_NAME)-1
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:db"}'] $(CLUSTER_NAME)-2
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:dc"}'] $(CLUSTER_NAME)-3

CLUSTER_ISO_PATH=$(ISO_DIR)/$(CLUSTER_NAME)2.iso
extra-vms: ## Provision cluster nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:dd"}'] $(CLUSTER_NAME)-4

clean-vms: ## Delete cluster nodes
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-1
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-2
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-3
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-4

clean: clean-vms clean-cluster
