include ../Makefile.globals

CLUSTER_NAME=javipolo-bond-01

mycluster: ## Create cluster
	mkdir -p $(CLUSTER_DIR)
	jq '. + { name: "$(CLUSTER_NAME)" }' templates/cluster.json | jq '. + {pull_secret: $(shell jq -cR . $(PULL_SECRET))}' | jq '. + {ssh_public_key: "$(file < $(SSH_KEY))"}' | $(apicurl) -XPOST -d @- $(API_URL)/v2/clusters | tee $(CLUSTER_DIR)/cluster.json

create-iso: ## Create and get ISO
	mkdir -p $(ISO_DIR)
	jq ' . | {name: .name, cluster_id: .id, openshift_version: .openshift_version, ssh_authorized_key: .ssh_public_key, image_type: "full-iso" }' $(CLUSTER_DIR)/cluster.json | jq '. + {pull_secret: $(shell jq -cR . $(PULL_SECRET))}'| $(apicurl) -XPOST -d @- $(API_URL)/v2/infra-envs -d @- | tee $(CLUSTER_DIR)/iso.json

iso: create-iso ## Download iso file
	wget -O "$(ISO_DIR)/$(CLUSTER_NAME).iso" "$(shell jq -r .download_url $(CLUSTER_DIR)/iso.json)"

create-bonding-iso: ## Create bonding ISO
	mkdir -p $(ISO_DIR)
	jq '. | {name: .name, cluster_id: .id, openshift_version: .openshift_version, ssh_authorized_key: .ssh_public_key, image_type: "full-iso" }' $(CLUSTER_DIR)/cluster.json | jq '. + $(shell cat templates/bonding.json)' | jq '. + {pull_secret: $(shell jq -cR . $(PULL_SECRET))}' | $(apicurl) -XPOST -d @- $(API_URL)/v2/infra-envs -d @- | tee $(CLUSTER_DIR)/iso.json

bonding-iso: create-bonding-iso ## Download bonding ISO
	wget -O "$(ISO_DIR)/$(CLUSTER_NAME).iso" "$(shell jq -r .download_url $(CLUSTER_DIR)/iso.json)"

vms: ## Provision nodes
	$(kcli) create vm -P iso="$(ISO_DIR)/$(CLUSTER_NAME).iso" -P nets=['{"name": "default", "mac": "de:ad:de:ad:00:00"},{"name": "default", "mac": "de:ad:de:ad:00:01"}'] -P memory=16384 -P numcpus=16 -P disks=['{"size": 120, "pool": "default"}'] $(CLUSTER_NAME)-master-01
	$(kcli) create vm -P iso="$(ISO_DIR)/$(CLUSTER_NAME).iso" -P nets=['{"name": "default", "mac": "de:ad:de:ad:00:02"},{"name": "default", "mac": "de:ad:de:ad:00:03"}'] -P memory=16384 -P numcpus=16 -P disks=['{"size": 120, "pool": "default"}'] $(CLUSTER_NAME)-master-02
	$(kcli) create vm -P iso="$(ISO_DIR)/$(CLUSTER_NAME).iso" -P nets=['{"name": "default", "mac": "de:ad:de:ad:00:04"},{"name": "default", "mac": "de:ad:de:ad:00:05"}'] -P memory=16384 -P numcpus=16 -P disks=['{"size": 120, "pool": "default"}'] $(CLUSTER_NAME)-master-03
	$(kcli) create vm -P iso="$(ISO_DIR)/$(CLUSTER_NAME).iso" -P nets=['{"name": "default", "mac": "de:ad:de:ad:00:06"},{"name": "default", "mac": "de:ad:de:ad:00:07"}'] -P memory=8192 -P numcpus=8 -P disks=['{"size": 120, "pool": "default"}'] $(CLUSTER_NAME)-worker-01
	$(kcli) create vm -P iso="$(ISO_DIR)/$(CLUSTER_NAME).iso" -P nets=['{"name": "default", "mac": "de:ad:de:ad:00:08"},{"name": "default", "mac": "de:ad:de:ad:00:09"}'] -P memory=8192 -P numcpus=8 -P disks=['{"size": 120, "pool": "default"}'] $(CLUSTER_NAME)-worker-02

vms-clean: ## Delete nodes
	$(kcli) delete vm -y $(CLUSTER_NAME)-master-01
	$(kcli) delete vm -y $(CLUSTER_NAME)-master-02
	$(kcli) delete vm -y $(CLUSTER_NAME)-master-03
	$(kcli) delete vm -y $(CLUSTER_NAME)-worker-01
	$(kcli) delete vm -y $(CLUSTER_NAME)-worker-02

clean: ## Delete cluster, associated VMs and files
	$(apicurl) $(API_URL)/v2/infra-envs | jq -r '.[] | select(.cluster_id=="$(CLUSTER_ID)") | .id' | xargs --no-run-if-empty -n1 -I% $(apicurl) -XDELETE $(API_URL)/v2/infra-envs/%
	echo $(CLUSTER_ID) | xargs --no-run-if-empty -n1 -I% $(apicurl) -XDELETE $(API_URL)/v2/clusters/%
	rm -vfr $(CLUSTER_DIR)
	rm -vfr $(ISO_DIR)/$(CLUSTER_NAME).iso
