include ../Makefile.globals

CLUSTER_NAME=sno
CLUSTER_HOST_NUM=1
CLUSTER_OCP_VERSION=4.12
# CLUSTER_API_VIP=192.168.122.233
# CLUSTER_INGRESS_VIP=192.168.122.232
CLUSTER_NETWORK_TYPE=OVNKubernetes
AICLI_EXTRA_PARAMS=-P sno=true

vms: ## Provision cluster nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:fa:ba:01"}'] $(CLUSTER_NAME)

clean-vms: ## Delete cluster nodes
	-@$(kcli) delete vm -y $(CLUSTER_NAME)

clean: clean-vms clean-cluster
