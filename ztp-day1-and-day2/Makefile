include ../Makefile.globals

ASSISTED_SERVICE=http://10.1.155.22:6000

# hub cluster
CLUSTER_NAME=hub
CLUSTER_HOST_NUM=6
CLUSTER_OCP_VERSION=4.10
CLUSTER_API_VIP=192.168.122.253
CLUSTER_INGRESS_VIP=192.168.122.252
KCLI_TEMPLATE_CLUSTER=-P iso="$(CLUSTER_ISO_PATH)" -P memory=16384 -P numcpus=8 -P disks=['$(KCLI_TEMPLATE_DISK),$(KCLI_TEMPLATE_DISK),$(KCLI_TEMPLATE_DISK)']

# spoke cluster
SPOKE_NAME=cluster1
SPOKE_ISO_PATH=$(ISO_DIR)/ztp-$(SPOKE_NAME).iso
KCLI_TEMPLATE_SPOKE=-P iso="$(SPOKE_ISO_PATH)" -P memory=16384 -P numcpus=8 -P disks=['$(KCLI_TEMPLATE_DISK)']

clean: clean-cluster clean-vms clean-ztp clean-isos ## Delete everything (cluster, vms, ztp-vms, isos, ..)

clean-isos: ## Delete iso files
	-rm -f $(CLUSTER_ISO_PATH)
	-rm -f $(SPOKE_ISO_PATH)


vms: ## Provision cluster nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:01"}'] $(CLUSTER_NAME)-1
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:02"}'] $(CLUSTER_NAME)-2
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:03"}'] $(CLUSTER_NAME)-3
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:04"}'] $(CLUSTER_NAME)-4
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:05"}'] $(CLUSTER_NAME)-5
	@$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:06"}'] $(CLUSTER_NAME)-6

clean-vms: ## Delete cluster nodes
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-1
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-2
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-3
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-4
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-5
	-@$(kcli) delete vm -y $(CLUSTER_NAME)-6

ztp-vms: ## Provision ztp nodes
	@$(kcli) create vm $(KCLI_TEMPLATE_SPOKE) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:11"}'] $(SPOKE_NAME)-1
	@$(kcli) create vm $(KCLI_TEMPLATE_SPOKE) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:12"}'] $(SPOKE_NAME)-2
	@$(kcli) create vm $(KCLI_TEMPLATE_SPOKE) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:13"}'] $(SPOKE_NAME)-3
	@$(kcli) create vm $(KCLI_TEMPLATE_SPOKE) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:14"}'] $(SPOKE_NAME)-4
	@$(kcli) create vm $(KCLI_TEMPLATE_SPOKE) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:15"}'] $(SPOKE_NAME)-5

ztp-day2: ## Provision ztp day2 node in different network
	@$(kcli) create vm $(KCLI_TEMPLATE_SPOKE) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:16"}'] $(SPOKE_NAME)-6

clean-ztp: ## Delete ZTP cluster nodes
	-@$(kcli) delete vm -y $(SPOKE_NAME)-1
	-@$(kcli) delete vm -y $(SPOKE_NAME)-2
	-@$(kcli) delete vm -y $(SPOKE_NAME)-3
	-@$(kcli) delete vm -y $(SPOKE_NAME)-4
	-@$(kcli) delete vm -y $(SPOKE_NAME)-5
	-@$(kcli) delete vm -y $(SPOKE_NAME)-6

simple: ## Create only one node
	$(kcli) create vm $(KCLI_TEMPLATE_CLUSTER) -P nets=['{"name": "default", "mac": "de:ad:be:ef:de:ff"}'] simple
