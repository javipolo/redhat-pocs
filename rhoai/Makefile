KUBECONFIG ?= ~/.kube/configs/kubeconfig.$(CLUSTER_NAME)
CLUSTER_NAME ?= rhoai
# CLUSTER_HOST_NUM ?= 3
CLUSTER_OCP_VERSION ?= 4.15
# CLUSTER_API_VIP ?= 192.168.122.240
# CLUSTER_INGRESS_VIP ?= 192.168.122.241
CLUSTER_NETWORK_TYPE ?= OVNKubernetes
# KCLI_MEMORY ?= 50000
# KCLI_NUMCPUS ?= 24

VIRSH_POOL_DIR=$(shell virsh pool-dumpxml $(VIRSH_DISK_POOL) | xq -r .pool.target.path)
CLUSTER_ISO_PATH=$(ISO_DIR)/$(CLUSTER_NAME).iso

# Add extra disk
KCLI_TEMPLATE_DISK ?= {"size": $(DISK_SIZE), "pool": "$(VIRSH_DISK_POOL)"}, {"size": $(DISK_SIZE), "pool": "$(VIRSH_DISK_POOL)"}, {"size": $(DISK_SIZE), "pool": "$(VIRSH_DISK_POOL)"}

include ../Makefile.globals

# vms: ## Provision cluster nodes
# 	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:0a:a1:da"}'] $(CLUSTER_NAME)-1
# 	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:0a:a1:db"}'] $(CLUSTER_NAME)-2
# 	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "fa:ba:da:0a:a1:dc"}'] $(CLUSTER_NAME)-3

# clean-vms: ## Delete cluster nodes
# 	-@$(kcli) delete vm -y $(CLUSTER_NAME)-1
# 	-@$(kcli) delete vm -y $(CLUSTER_NAME)-2
# 	-@$(kcli) delete vm -y $(CLUSTER_NAME)-3

sno: ## Create RHOAI sno cluster
	make -f Makefile.sno cluster

multinode: ## Create RHOAI multinode cluster
	make -f Makefile.multinode cluster

backup-sno: ## Backup RHOAI SNO
	virsh shutdown $(CLUSTER_NAME)-1
	until sudo virsh domstate $(CLUSTER_NAME)-1 | grep shut; do sleep 1; done
	cp $(KUBECONFIGS_DIR)/kubeconfig.$(CLUSTER_NAME) $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-$(CLUSTER_OCP_VERSION).kubeconfig
	cp $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_0.img $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_0-$(CLUSTER_OCP_VERSION).img
	cp $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_1.img $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_1-$(CLUSTER_OCP_VERSION).img
	cp $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_2.img $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_2-$(CLUSTER_OCP_VERSION).img
	virsh start $(CLUSTER_NAME)-1

restore-sno: ## Restore RHOAI SNO
	virsh destroy $(CLUSTER_NAME)-1
	until sudo virsh domstate $(CLUSTER_NAME)-1 | grep shut; do sleep 1; done
	cp $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_0-$(CLUSTER_OCP_VERSION).img $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_0.img
	cp $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_1-$(CLUSTER_OCP_VERSION).img $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_1.img
	cp $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_2-$(CLUSTER_OCP_VERSION).img $(VIRSH_POOL_DIR)/$(CLUSTER_NAME)-1_2.img
	virsh start $(CLUSTER_NAME)-1

clean: clean-multinode

clean-sno: clean-cluster
	make -f Makefile.sno clean-vms

clean-multinode: clean-cluster
	make -f Makefile.multinode clean-vms

deploy: ## Deploy RHOAI
	KUBECONFIG=$(KUBECONFIG) ./deploy.sh

configure: ## Install and configure RHOAI components
	KUBECONFIG=$(KUBECONFIG) ./configure.sh
