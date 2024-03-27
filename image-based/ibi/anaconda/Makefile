.PHONY: default-help
default-help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

include ../../Makefile.globals

VM_NAME=ibi
VM_MAC=fa:ba:da:1b:11:b1
ISO_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/39/Server/x86_64/iso/Fedora-Server-netinst-x86_64-39-1.5.iso
ISO_PATH=/home/isos/$(VM_NAME)-rhcos.iso
HTTP_PORT=8181
KCLI_TEMPLATE=-P iso="$(ISO_PATH)" -P memory=33792 -P numcpus=16 -P disks=['$(KCLI_TEMPLATE_DISK)']
VIRSH_POOL_DIR=$(shell virsh pool-dumpxml $(VIRSH_DISK_POOL) | xq -r .pool.target.path)
CONTAINER_IMAGE=quay.io/jpolo/ibi:latest

.PHONY: iso-download
iso-download: ## Download ISO
	curl -L $(ISO_URL) > netinst.iso

.PHONY: iso-prepare
iso-prepare: ## Update grub config in ISO
	-rm $(ISO_PATH)
	xorriso -indev netinst.iso -outdev $(ISO_PATH) -compliance no_emul_toc -map netinst-grub.cfg /boot/grub2/grub.cfg -boot_image any replay

.PHONY: iso-clean
iso-clean: ## Delete ISO
	-rm $(ISO_PATH)

.PHONY: vm
vm: ## Provision VM
	@$(kcli) create vm $(KCLI_TEMPLATE) -P nets=['{"name": "default", "mac": "$(VM_MAC)"}'] $(VM_NAME)

.PHONY: vm-clean
vm-clean: ## Delete VM
	-@$(kcli) delete vm -y $(VM_NAME)

.PHONY: http
http: ## Start HTTP server
	python3 -m http.server --directory . $(HTTP_PORT) & \
		echo $$! > .http.pid

.PHONY: http-clean
http-clean: ## Stop HTTP server
	-kill $(shell cat .http.pid)
	-rm .http.pid

.PHONY: bp-image
bp-image: ## Build and push docker image
	podman build . -t $(CONTAINER_IMAGE)
	podman push $(CONTAINER_IMAGE)

.PHONY: clean
clean: vm-clean iso-clean http-clean ## Clean all
