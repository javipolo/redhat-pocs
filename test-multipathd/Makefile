include ../Makefile.globals

CLUSTER_NAME=javipolo-mpath
SNO-NAME=mpath-sno

MPATH_A_NET=mpa
MPATH_A_ADDRESS=192.168.130.1
MPATH_B_NET=mpb
MPATH_B_ADDRESS=192.168.131.1

cluster: ## Create cluster
	mkdir -p $(CLUSTER_DIR)
	jq '. + { name: "$(CLUSTER_NAME)" }' templates/cluster.json | $(apicurl) -XPOST -d @- $(API_URL)/v2/clusters | tee $(CLUSTER_DIR)/cluster.json

get-cluster: ## Get cluster.json from API
	mkdir -p $(CLUSTER_DIR)
	$(apicurl) $(API_URL)/v2/clusters | jq '.[] | select(.name=="$(CLUSTER_NAME)")' > $(CLUSTER_DIR)/cluster.json

ignition.json: ## Generate ignition.json from files
	jq -n --arg MULTIPATHCONF $(shell base64 -w0 templates/files/multipath.conf) --arg INITIATOR $(shell base64 -w0 templates/files/initiatorname.iscsi) --arg SETUPISCSI $(shell base64 -w0 templates/files/setup-iscsi.sh) $(file < templates/ignition.tpl)

iso-test: ## Create ISO update JSON
	jq -n '{ ssh_authorized_key: "$(file < $(SSH_KEY))", ignition_config_override: $(shell jq -c . templates/ignition.json | jq -R .)}'

iso: ## Create ISO
	mkdir -p $(ISO_DIR)
	jq -n '{ ssh_authorized_key: "$(file < $(SSH_KEY))", ignition_config_override: $(shell jq -c . templates/ignition.json | jq -R .)}' | $(apicurl) -XPATCH -d @- $(API_URL)/v2/infra-envs/$(shell $(apicurl) $(API_URL)/v2/infra-envs | jq -r '.[] | select(.cluster_id=="$(CLUSTER_ID)") | .id') | tee $(CLUSTER_DIR)/iso.json

get-iso: iso ## Download ISO
	jq -r .download_url $(CLUSTER_DIR)/iso.json | xargs -I% wget -O "$(ISO_DIR)/$(CLUSTER_NAME).iso" "%"

patch-host: INFRA_ENV_ID=$(shell $(apicurl) $(API_URL)/v2/infra-envs | jq -r '.[] | select(.cluster_id=="$(CLUSTER_ID)") | .id')
patch-host: HOST_ID=$(shell $(apicurl) $(API_URL)/v2/infra-envs/$(INFRA_ENV_ID)/hosts | jq -r '.[] | select(.requested_hostname=="$(SNO-NAME)") | .id')
patch-host: ## Patch $(SNO-NAME) with ignition config
	jq -n '{"host-ignition-params": $(shell jq -c . templates/ignition.json | jq -R .)}' | $(apicurl) -XPATCH -d @- $(API_URL)/v2/infra-envs/$(INFRA_ENV_ID)/hosts/$(HOST_ID)/ignition | tee $(CLUSTER_DIR)/patch-host.json

network: ## Define network connections
	# Multipath net A
	nmcli connection add type bridge con-name $(MPATH_A_NET)-link ifname $(MPATH_A_NET)-nic
	nmcli connection modify $(MPATH_A_NET)-link ipv4.method manual ipv4.addresses '$(MPATH_A_ADDRESS)/24'
	nmcli connection up $(MPATH_A_NET)-link
	virsh net-define virsh/net-$(MPATH_A_NET).xml
	virsh net-start $(MPATH_A_NET)
	virsh net-autostart $(MPATH_A_NET)
	iptables -t nat -A POSTROUTING -s $(MPATH_A_ADDRESS)/24 ! -d $(MPATH_A_ADDRESS)/24 -j MASQUERADE
	# Multipath net B
	nmcli connection add type bridge con-name $(MPATH_B_NET)-link ifname $(MPATH_B_NET)-nic
	nmcli connection modify $(MPATH_B_NET)-link ipv4.method manual ipv4.addresses '$(MPATH_B_ADDRESS)/24'
	nmcli connection up $(MPATH_B_NET)-link
	virsh net-define virsh/net-$(MPATH_B_NET).xml
	virsh net-start $(MPATH_B_NET)
	virsh net-autostart $(MPATH_B_NET)
	iptables -t nat -A POSTROUTING -s $(MPATH_B_ADDRESS)/24 ! -d $(MPATH_B_ADDRESS)/24 -j MASQUERADE

network-clean: ## Cleanup network connections
	# Multipath net A
	nmcli connection delete $(MPATH_A_NET)-link
	virsh net-destroy $(MPATH_A_NET)
	iptables -t nat -D POSTROUTING -s $(MPATH_A_ADDRESS)/24 ! -d $(MPATH_A_ADDRESS)/24 -j MASQUERADE
	# Multipath net A
	nmcli connection delete $(MPATH_B_NET)-link
	virsh net-destroy $(MPATH_B_NET)
	iptables -t nat -D POSTROUTING -s $(MPATH_B_ADDRESS)/24 ! -d $(MPATH_B_ADDRESS)/24 -j MASQUERADE

vm-mpath-server: ## Provision iSCSI server VM
	$(kcli) create vm -i centos8 -P nets=['{"name": "default", "mac": "de:ad:de:ad:10:00"},{"name": "mpa", "mac": "de:ad:de:ad:10:01", "ip": "192.168.130.10", "mask": "255.255.255.0"},{"name": "mpb", "mac": "de:ad:de:ad:10:02", "ip": "192.168.131.10", "mask": "255.255.255.0"}'] -P memory=4092 -P numcpus=4 -P disks=['{"size": 500, "pool": "default"}'] mpathd

vm-mpath-client: ## Provision client VM
	$(kcli) create vm -i centos8 -P nets=['{"name": "default", "mac": "de:ad:de:ad:11:00"},{"name": "mpa", "mac": "de:ad:de:ad:11:01", "ip": "192.168.130.11", "mask": "255.255.255.0"},{"name": "mpb", "mac": "de:ad:de:ad:11:02", "ip": "192.168.131.11", "mask": "255.255.255.0"}'] -P memory=4092 -P numcpus=4 -P disks=['{"size": 500, "pool": "default"}'] mpath-client

vms: ## Provision SNO VM
	$(kcli) create vm -P nets=['{"name": "pxe", "mac": "de:ad:de:ad:11:10"},{"name": "mpa", "mac": "de:ad:de:ad:11:11", "ip": "192.168.130.12", "mask": "255.255.255.0"},{"name": "mpb", "mac": "de:ad:de:ad:11:12", "ip": "192.168.131.12", "mask": "255.255.255.0"}'] -P memory=32768 -P numcpus=16 -P disks=['{"size": 120, "pool": "default"}'] mpath-sno
