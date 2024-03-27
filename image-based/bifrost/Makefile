SSHKEY ?= ~/.ssh/id_rsa.pub
ARCH ?= x86_64
PROJECT ?= rhcos
IMAGE ?= quay.io/jpolo/bifrost:$(PROJECT)
PULL_SECRET_FILE ?= $(HOME)/pull_secret.json

VM_NAME ?= bifrost
RAM_MB ?= 32768
CPU_CORE ?= 16
HOST_MAC ?= fa:ba:da:fa:ba:44
NET_NAME ?= default
DISK_PATH ?= /home/libvirt/images/$(VM_NAME).qcow2

default: help

all: build push disk-image vm-remove vm-create ## Build, push and create disk image

build: ## Build OCI image
	podman build --authfile $(PULL_SECRET_FILE) --tag $(IMAGE) $(PROJECT)

push: ## Push OCI image
	podman push $(IMAGE)

run: ## Run the OCI image with podman
	podman run --privileged --replace --rm --name $(PROJECT) -d $(IMAGE)

exec: ## Run bash inside a running OCI image
	podman exec -it $(PROJECT) bash

kill: ## Kill the running OCI image
	podman kill $(PROJECT)

podman-bootc:
	podman-bootc run $(IMAGE)

disk-image: ## Create qcow2 file
	podman run --rm --privileged -it -v .:/output quay.io/centos-bootc/bootc-image-builder --type qcow2 $(IMAGE)
	-mv qcow2/disk.qcow2 $(PROJECT).qcow2
	-rm manifest-qcow2.json

vm-create: ## Creates bifrost VM
	test ! -f $(DISK_PATH)
	cp $(PROJECT).qcow2 $(DISK_PATH)
	virt-install \
		--connect qemu:///system \
		-n $(VM_NAME) \
		-r "$(RAM_MB)" \
		--vcpus "$(CPU_CORE)" \
		--os-variant rhel9-unknown \
		--import \
		--network=network:"$(NET_NAME)",mac="$(HOST_MAC)" \
		--graphics=vnc \
		--events on_reboot=restart \
		--disk source.file=$(DISK_PATH) \
		--check disk_size=off \
		--boot hd \
		--noautoconsole

vm-remove: ## Delete bifrost VM
	-virsh destroy $(VM_NAME)
	-virsh undefine $(VM_NAME) --remove-all-storage

help:   ## Shows this message.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(shell echo "$(MAKEFILE_LIST) " | tac -s' ') | perl -pe 's/^.*Makefile.*?://g' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

