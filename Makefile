include Makefile.globals

network: ## Define network connections
	nmcli connection add type bridge con-name $(PXE_NET)-link ifname $(PXE_NET)-nic
	nmcli connection modify $(PXE_NET)-link ipv4.method manual ipv4.addresses '$(PXE_ADDRESS)/24'
	nmcli connection up $(PXE_NET)-link
	virsh net-define virsh/net-$(PXE_NET).xml
	virsh net-start $(PXE_NET)
	virsh net-autostart $(PXE_NET)
	iptables -t nat -A POSTROUTING -s $(PXE_ADDRESS)/24 ! -d $(PXE_ADDRESS)/24 -j MASQUERADE
	#$(kcli) create network -P macvtap=true -P nic=$(NET_MAIN_INTERFACE) macvtap

network-clean: ## Cleanup network connections
	virsh net-destroy $(PXE_NET)
	virsh net-undefine $(PXE_NET)
	nmcli connection delete $(PXE_NET)-link
	iptables -t nat -D POSTROUTING -s $(PXE_ADDRESS)/24 ! -d $(PXE_ADDRESS)/24 -j MASQUERADE
	#virsh net-destroy macvtap
	#virsh net-undefine macvtap

iso2pxe: ## Download
	@test -d $(PXE_DIR) || git clone https://github.com/javipolo/iso2pxe $(PXE_DIR)

pxe-build: iso2pxe ## Build iso2pxe image
	cd $(PXE_DIR); podman build -f Dockerfile -t iso2pxe .

pxe: ## Run iso2pxe
	podman run --name pxe \
	  --detach \
	  --rm \
	  --privileged --network=host \
	  --env hypervisor=$(PXE_ADDRESS) \
	  --env interface=$(PXE_NET)-nic \
	  --env dnsmasq_port=0 \
	  --env webserver_port=12345 \
	  --env extra_kernel_args='console=tty1 console=ttyS0,115200n8' \
	  --volume $(ISO_DIR):/data/iso \
	  iso2pxe

pxe-logs: ## Show logs of iso2pxe
	podman logs --follow pxe

pxe-clean: ## Stop iso2pxe
	podman kill pxe

pxe-debug: ## Debug pxe instance
	podman exec -it pxe bash

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
	grep -q aicli $(HOME)/.bashrc || echo "alias aicli='$(aicli)'" >> $(HOME)/.bashrc
	virsh pool-define virsh/storage-pool.xml
	virsh pool-start $(VIRSH_DISK_POOL)
	virsh pool-autostart $(VIRSH_DISK_POOL)
	# Install newer runc to address this bug
	# https://bugzilla.redhat.com/show_bug.cgi?id=2009047
	wget http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/runc-1.0.2-1.module_el8.6.0+926+8bef8ae7.x86_64.rpm -O /tmp/runc-1.0.2-1.module_el8.6.0+926+8bef8ae7.x86_64.rpm
	rpm -Uvh /tmp/runc-1.0.2-1.module_el8.6.0+926+8bef8ae7.x86_64.rpm
