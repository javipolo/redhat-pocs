PROJECT ?= agent
PROJECT_ENV ?= $(wildcard .env.${PROJECT})
IMAGE_NAME ?= quay.io/jpolo/rhel-image-mode:${PROJECT}
IMAGE_BUILDER_CONFIG=$(abspath .)/config.toml
DISK_TYPE ?= qcow2
VM_NAME ?= rhel-image-mode
VM_MAC ?= fa:ba:da:ba:fa:da

-include .env
-include ${PROJECT_ENV}

BOOTC_IMAGE_BUILDER ?= quay.io/centos-bootc/bootc-image-builder
GRAPH_ROOT=$(shell podman info --format '{{ .Store.GraphRoot }}')
DISK_UID ?= $(shell id -u)
DISK_GID ?= $(shell id -g)
LIBVIRT_POOL ?= images
LIBVIRT_POOL_PATH ?= $(shell virsh pool-dumpxml ${LIBVIRT_POOL} --xpath "/pool/target/path/text()")

KCLI_IMAGE ?= quay.io/karmab/kcli
kcli ?= podman run --net host -i --rm --security-opt label=disable -v $(LIBVIRT_POOL_PATH):$(LIBVIRT_POOL_PATH) -v $(HOME)/.ssh:/root/.ssh -v $(HOME)/.kcli:/root/.kcli -v /var/run/libvirt:/var/run/libvirt -v $(PWD):/workdir -v /var/tmp:/ignitiondir $(KCLI_IMAGE)

.PHONY: default
default: help

.PHONY: all
all: image disk vm-delete vm-create

.PHONY: image
image: ansible/ansible.cfg ## Build container image
	podman build \
		-t $(IMAGE_NAME) \
		-f Containerfile.${PROJECT} \
		$(PROJECT:%=--build-arg PROJECT=%) \
		$(PROJECT_ENV:%=--build-arg-file %) \
	.

.PHONY: disk
disk: ## Build disk image
	mkdir -p build/store build/output
	podman run \
	  --rm \
	  -ti \
	  --privileged \
	  --pull newer \
	  -v $(GRAPH_ROOT):/var/lib/containers/storage \
	  -v ./build/store:/store \
	  -v ./build/output:/output \
	  $(IMAGE_BUILDER_CONFIG:%=-v %:/config$(suffix $(IMAGE_BUILDER_CONFIG))) \
	  ${CONTAINER_TOOL_EXTRA_ARGS} \
	  $(BOOTC_IMAGE_BUILDER) \
	    $(IMAGE_BUILDER_CONFIG:%=--config /config$(suffix $(IMAGE_BUILDER_CONFIG))) \
	    ${IMAGE_BUILDER_EXTRA_ARGS} \
	    --chown $(DISK_UID):$(DISK_GID) \
	    --local \
	    --type $(DISK_TYPE) \
	    $(IMAGE_NAME)
	mkdir -p images
	cp build/output/qcow2/disk.qcow2 images/${PROJECT}.qcow2

.PHONY: vm
vm: vm-delete vm-create

.PHONY: vm-create
vm-create: ## Create VM out of the qcow2 file
	sudo cp images/${PROJECT}.qcow2 ${LIBVIRT_POOL_PATH}/${VM_NAME}.qcow2
	sudo virt-install \
		--name ${VM_NAME} \
		--memory 4096 \
		--vcpus 4 \
		--disk path=${LIBVIRT_POOL_PATH}/${VM_NAME}.qcow2,bus=virtio \
		--disk size=10 \
		--network=network:default,mac="${VM_MAC}" \
		--network=network:default \
		--os-variant=rhel9.3 \
		--import \
		--noautoconsole \
		--graphics=vnc

.PHONY: vm-delete
vm-delete: ## Delete VM
	-$(kcli) delete vm -y ${VM_NAME}

.PHONY: help
help:
	@gawk -vG=$$(tput setaf 6) -vR=$$(tput sgr0) ' \
		match($$0,"^(([^:]*[^ :]) *:)?([^#]*)## (.*)",a) { \
			if (a[2]!="") {printf "%s%-30s%s %s\n",G,a[2],R,a[4];next}\
			if (a[3]=="") {print a[4];next}\
			printf "\n%-30s %s\n","",a[4]\
		}\
	' $(MAKEFILE_LIST)

ansible/ansible.cfg:
	@$(ANSIBLE_AUTOMATION_HUB_TOKEN:%=ANSIBLE_AUTOMATION_HUB_TOKEN=${ANSIBLE_AUTOMATION_HUB_TOKEN} envsubst < ansible/ansible.cfg.template > ansible/ansible.cfg)


run-ansible: ## Run ansible in the VM
	mkdir -p ansible/server/collections
	$(ANSIBLE_COLLECTION:%=ansible-galaxy collection install ${ANSIBLE_COLLECTION} --collections-path ansible/server/collections)
	ANSIBLE_CONFIG=ansible/server/ansible.cfg ansible-playbook ansible/${PROJECT}/playbook.yaml
