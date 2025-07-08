include ../Makefile.globals

CLUSTER_NAME ?= sno

ifeq ($(CLUSTER_NAME),snoc)
# snoc
	SNO_MAC=fa:ba:da:fa:ba:0c
	CLUSTER_OCP_VERSION=4.13
else ifeq ($(CLUSTER_NAME),snod)
# snod
	SNO_MAC=fa:ba:da:fa:ba:0d
	CLUSTER_OCP_VERSION=4.14.1
else ifeq ($(CLUSTER_NAME),test)
# snod
	SNO_MAC=52:54:00:ee:42:e1
	CLUSTER_OCP_VERSION=4.14.1
else
# sno
	SNO_MAC=fa:ba:da:fa:ba:01
	CLUSTER_OCP_VERSION=4.19.1
endif

CLUSTER_HOST_NUM=1
CLUSTER_NETWORK_TYPE=OVNKubernetes
AICLI_EXTRA_PARAMS=-P sno=true
KCLI_TEMPLATE_CLUSTER=-P iso="$(CLUSTER_ISO_PATH)" -P memory=33792 -P numcpus=16 -P disks=['$(KCLI_TEMPLATE_DISK)']
VIRSH_POOL_DIR=$(shell virsh pool-dumpxml $(VIRSH_DISK_POOL) | xq -r .pool.target.path)

# Use local assisted-service
# ASSISTED_SERVICE=http://10.1.155.22:8080

vms: ## Provision cluster nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "$(SNO_MAC)"}'] $(CLUSTER_NAME)

clean-vms: ## Delete cluster nodes
	-@$(kcli) delete vm -y $(CLUSTER_NAME)

backup:
	virsh shutdown $(CLUSTER_NAME)
	until sudo virsh domstate $(CLUSTER_NAME) | grep shut; do sleep 1; done
	cp $(KUBECONFIGS_DIR)/kubeconfig.$(CLUSTER_NAME) $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-$(CLUSTER_OCP_VERSION).kubeconfig
	cp $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)_0.img $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-$(CLUSTER_OCP_VERSION).img
	virsh start $(CLUSTER_NAME)

restore:
	-virsh destroy $(CLUSTER_NAME)
	until sudo virsh domstate $(CLUSTER_NAME) | grep shut; do sleep 1; done
	cp $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-$(CLUSTER_OCP_VERSION).img $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)_0.img
	virsh start $(CLUSTER_NAME)

clean: clean-vms clean-cluster
