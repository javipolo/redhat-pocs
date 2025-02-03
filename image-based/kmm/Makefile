IMAGE_NAME ?= quay.io/jpolo/rim-kmm
IMAGE_BUILDER_CONFIG=$(abspath .)/azure/config.toml
DISK_TYPE ?= vhd

BOOTC_IMAGE_BUILDER ?= quay.io/centos-bootc/bootc-image-builder
GRAPH_ROOT=$(shell podman info --format '{{ .Store.GraphRoot }}')
DISK_UID ?= $(shell id -u)
DISK_GID ?= $(shell id -g)
LIBVIRT_POOL ?= images
LIBVIRT_POOL_PATH ?= $(shell virsh pool-dumpxml ${LIBVIRT_POOL} --xpath "/pool/target/path/text()")

.PHONY: default
default: help

.PHONY: all
all: image disk vm-delete vm-create

.PHONY: kmm
kmm: ## Build kmm image
	podman build \
		-t ${IMAGE_NAME}:kmm \
		-f Containerfile.kmm \
	.

.PHONY: bootc
bootc: ## Build bootc image
	podman build \
		-t ${IMAGE_NAME}:bootc \
		-f Containerfile.bootc \
	.

.PHONY: azure
azure: ## Add azure bits to the botc image
	podman build \
		-t ${IMAGE_NAME}:azure \
		-f Containerfile.azure \
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
			$(IMAGE_NAME):azure
	mkdir -p images

.PHONY: help
help:
	@gawk -vG=$$(tput setaf 6) -vR=$$(tput sgr0) ' \
		match($$0,"^(([^:]*[^ :]) *:)?([^#]*)## (.*)",a) { \
			if (a[2]!="") {printf "%s%-30s%s %s\n",G,a[2],R,a[4];next}\
			if (a[3]=="") {print a[4];next}\
			printf "\n%-30s %s\n","",a[4]\
		}\
	' $(MAKEFILE_LIST)
