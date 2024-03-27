default: help

KCLI_IMAGE=quay.io/karmab/kcli
ISO_DIR=/home/isos
IMG_DIR=/home/images
kcli=podman run --net host -i --rm --security-opt label=disable -v $(ISO_DIR):$(ISO_DIR) -v $(IMG_DIR):$(IMG_DIR) -v $(HOME)/.ssh:/root/.ssh -v $(HOME)/.kcli:/root/.kcli -v /var/lib/libvirt/images:/var/lib/libvirt/images -v /var/run/libvirt:/var/run/libvirt $(KCLI_IMAGE)

vm-create: ## Create new VM using microshift iso
	$(kcli) create vm -P iso=/home/isos/microshift.iso -P memory=33792 -P numcpus=16 -P disks='[{"size": 120, "pool": "ocp"}]' -P nets='[{"name": "default", "mac": "fa:ba:da:fa:ba:69"}]' microshift

vm-delete: ## Delete microshift VM
	-$(kcli) delete vm -y microshift

wait-for-vm: ## Wait for VM to be accessible by ssh
	@until ssh microshift true; do sleep 5; echo -n .; done; echo

build-installer: ## Build the microshift.iso using composer-cli
	./build_microshift_installer.sh

embed-kickstart: ## Embed kickstart on a pre-baked microshift-installer ISO
	mkksiso kickstart/microshift.ks microshift-installer-vanilla.iso microshift.iso
	mv microshift.iso /home/isos/microshift.iso

ibi: ## Run IBI script in microshift VM
	./run_ibi.sh

manual: ## Run IBI script in microshift VM
	./manual_ibi.sh

help:   ## Shows this message.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(shell echo "$(MAKEFILE_LIST) " | tac -s' ') | perl -pe 's/^.*Makefile.*?://g' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
