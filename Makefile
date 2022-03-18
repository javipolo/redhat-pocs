include Makefile.globals

network: ## Define network connections
	nmcli connection add type bridge con-name $(PXE_NET)-link ifname $(PXE_NET)-nic
	nmcli connection modify $(PXE_NET)-link ipv4.method manual ipv4.addresses '$(PXE_ADDRESS)/24'
	nmcli connection up $(PXE_NET)-link
	virsh net-define virsh/net-$(PXE_NET).xml
	virsh net-start $(PXE_NET)
	virsh net-autostart $(PXE_NET)
	$(kcli) create network -P macvtap=true -P nic=$(NET_MAIN_INTERFACE) macvtap
	iptables -t nat -A POSTROUTING -s $(PXE_ADDRESS)/24 ! -d $(PXE_ADDRESS)/24 -j MASQUERADE

network-clean: ## Cleanup network connections
	nmcli connection delete $(PXE_NET)-link
	virsh net-destroy $(PXE_NET)
	virsh net-destroy macvtap
	iptables -t nat -D POSTROUTING -s $(PXE_ADDRESS)/24 ! -d $(PXE_ADDRESS)/24 -j MASQUERADE

pxe-build: ## Build iso2pxe image
	cd $(PXE_DIR); podman build -f Dockerfile -t iso2pxe .

pxe: ## Run iso2pxe
	podman run --name pxe \
	  --detach \
	  --rm \
	  --privileged --network=host \
	  --env hypervisor=$(PXE_ADDRESS) \
	  --env interface=$(PXE_NET)-nic \
	  --volume $(ISO_DIR):/data/iso \
	  iso2pxe

pxe-logs: ## Show logs of iso2pxe
	podman logs --follow pxe

pxe-clean: ## Stop iso2pxe
	podman kill pxe

pxe-debug: ## Debug pxe instance
	podman exec -it pxe bash

nfs: ## Provision nfs server
	sudo mkdir -p $(NFS_DIR)
	sudo dnf install -y nfs-utils
	sudo systemctl enable --now nfs-server
	grep -q '^$(NFS_DIR) ' /etc/exports || echo '$(NFS_DIR) $(NFS_CIDR)(rw,no_root_squash)' | sudo tee -a /etc/exports
	sudo exportfs -r

deps: ## Install dependencies
	dnf install -y \
	  jq \
	  libvirt-client \
	  podman \
	  vim \
	  virt-install \
	  virt-manager \
	  wget \
	  xauth
	dnf group install -y "Virtualization Host"
	systemctl start libvirtd
	systemctl enable libvirtd
	curl -L https://github.com/openshift-online/ocm-cli/releases/download/v0.1.60/ocm-linux-amd64 -o /usr/local/bin/ocm
	chmod +x /usr/local/bin/ocm
	curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz | sudo tar xvzC usr/local/bin
	curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
	mkdir -p /root/.kcli $(ISO_DIR) $(IMG_DIR)
	grep -q kcli $(HOME)/.bashrc || echo "alias kcli='$(kcli)'" >> $(HOME)/.bashrc
	virsh pool-define virsh/storage-pool.xml
	# Install newer runc to address this bug
	# https://bugzilla.redhat.com/show_bug.cgi?id=2009047
	wget http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/runc-1.0.2-1.module_el8.6.0+926+8bef8ae7.x86_64.rpm -O /tmp/runc-1.0.2-1.module_el8.6.0+926+8bef8ae7.x86_64.rpm
	rpm -Uvh /tmp/runc-1.0.2-1.module_el8.6.0+926+8bef8ae7.x86_64.rpm
