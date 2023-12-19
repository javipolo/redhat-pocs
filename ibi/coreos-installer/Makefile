.PHONY: default-help
default-help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

include ../../Makefile.globals

VM_NAME=ibi
VM_MAC=fa:ba:da:1b:11:b1
TMPDIR=tmp
RHCOS_LIVE_ISO_URL=https://mirror.openshift.com/pub/openshift-v4/amd64/dependencies/rhcos/latest/rhcos-live.x86_64.iso
RHCOS_LIVE_ISO=$(TMPDIR)/rhcos-live.iso
COREOS_INSTALLER_URL=https://mirror.openshift.com/pub/openshift-v4/amd64/clients/coreos-installer/latest/coreos-installer
COREOS_INSTALLER=$(TMPDIR)/coreos-installer
ISO_PATH=$(ISO_DIR)/rhcos-ibi.iso
KCLI_TEMPLATE=-P iso="$(ISO_PATH)" -P memory=33792 -P numcpus=16 -P disks=['$(KCLI_TEMPLATE_DISK)']
SSH_PUBLIC_KEY=$(HOME)/.ssh/id_rsa.pub

$(TMPDIR):
	mkdir $@

$(COREOS_INSTALLER): $(TMPDIR)
	curl -o $@ $(COREOS_INSTALLER_URL)
	chmod +x $@

$(RHCOS_LIVE_ISO):
	curl -L $(RHCOS_LIVE_ISO_URL) > $@

.PHONY: $(TMPDIR)/ignition.json
$(TMPDIR)/ignition.json: credentials $(TMPDIR)
	SSH_PUBLIC_KEY="$(shell cat $(SSH_PUBLIC_KEY))" \
	SEED_IMAGE="$(SEED_IMAGE)" \
	  envsubst < butane-ignition.yaml | \
		podman run -i -v $(shell pwd):/scripts/:rw,Z  --rm quay.io/coreos/butane:release --pretty --strict -d /scripts > $@

.PHONY: iso
iso: $(COREOS_INSTALLER) $(RHCOS_LIVE_ISO) $(TMPDIR)/ignition.json ## Embed ignition into live ISO
	-rm -f $(ISO_PATH)
	$(COREOS_INSTALLER) iso ignition embed -i $(TMPDIR)/ignition.json -o $(ISO_PATH) $(RHCOS_LIVE_ISO)
	chmod a+r $(ISO_PATH)

.PHONY: iso-clean
iso-clean: ## Delete ISO
	-rm -f $(ISO_PATH) $(RHCOS_LIVE_ISO)

.PHONY: vm
vm: ## Provision VM
	@$(kcli) create vm $(KCLI_TEMPLATE) -P nets=['{"name": "default", "mac": "$(VM_MAC)"}'] $(VM_NAME)

.PHONY: vm-clean
vm-clean: ## Delete VM
	-@$(kcli) delete vm -y $(VM_NAME)

.PHONY: clean
clean: vm-clean iso-clean ## Clean all
	-rm -f $(TMPDIR)

.PHONY: credentials
credentials:
	@test '$(BACKUP_SECRET)' || { echo "BACKUP_SECRET must be defined"; exit 1; }
	@test '$(PULL_SECRET)' || { echo "PULL_SECRET must be defined"; exit 1; }
	@mkdir -p credentials
	@echo '$(PULL_SECRET)' > $(TMPDIR)/pull-secret.json
	@echo '$(BACKUP_SECRET)' > $(TMPDIR)/backup-secret.json

.PHONY: logs
logs: ## Show logs of the installation process
	echo "Waiting for $(VM_NAME) to be accessible"
	@until ssh core@$(VM_NAME) true; do sleep 5; echo -n .; done; echo
	ssh core@$(VM_NAME) sudo journalctl -flu install-rhcos-and-restore-seed.service

.PHONY: ostree-restore
ostree-restore: credentials
	echo "Waiting for $(VM_NAME) to be accessible"
	@until ssh core@$(VM_NAME) true; do sleep 5; echo -n .; done
	scp certs.tgz ostree-restore.sh $(TMPDIR)/*-secret.json core@$(VM_NAME):/var/tmp
	ssh core@$(VM_NAME) sudo /var/tmp/ostree-restore.sh $(SEED_IMAGE)

