CLUSTER_NAME=multiarch
ISO_NAME=/home/isos/rhcos.iso
OCP_RELEASE=quay.io/openshift-release-dev/ocp-release:4.11.0-0.nightly-multi-2022-07-04-160826
SSH_KEY=$(HOME)/.ssh/id_rsa.pub
PULL_SECRET=../pull-secret.json

kcli=podman run --net host -it --rm --security-opt label=disable -v /home:/home -v $(HOME)/.ssh:/root/.ssh -v $(HOME)/.kcli:/root/.kcli -v /var/lib/libvirt/images:/var/lib/libvirt/images -v /var/run/libvirt:/var/run/libvirt -v $(PWD):/workdir -v /var/tmp:/ignitiondir quay.io/karmab/kcli

default: help

get-rhcos: isos/$(shell basename $(ISO_NAME)) ## Download RHCOS live iso

isos/$(shell basename $(ISO_NAME)): ## Download RHCOS live iso
	@ln -sf $(shell dirname $(ISO_NAME)) isos
	curl -Lo "$(ISO_NAME)" https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/latest/rhcos-live.x86_64.iso

manifests: ## Create manifests
	./openshift-install create manifests --dir config

ignition: ## Create ignition config files
	./openshift-install create ignition-configs --dir config

webserver: ## Run a webserver to serve the ignition files
	python -m http.server --directory config 12345 &

cluster: get-openshift-install create-config manifests ignition webserver get-rhcos vms ## Create all needed files, webserver and VMs

get-openshift-install: openshift-install ## Extract openshift installer from multiarch release (needs latest oc)
	 oc adm release extract -a /root/pull_secret.json --command openshift-install --from=$(OCP_RELEASE)

create-config: ## Creates full install-config.yaml
	mkdir -p config
	cat install-config.yaml \
	  | yq '. + { pullSecret: $(shell jq -cR . $(PULL_SECRET))}' -y \
	  | yq '. + { sshKey: "$(shell cat $(SSH_KEY))"}' -y \
	  > config/install-config.yaml

vms: ## Provision nodes
	@$(kcli) create vm -P iso="$(ISO_NAME)" -P nets=['{"name":"default","mac":"fa:ba:da:fa:ba:da"}'] -P memory=16384 -P numcpus=16 -P disks=['{"size": 120, "pool": "default"}'] m-bstrap
	@$(kcli) create vm -P iso="$(ISO_NAME)" -P nets=['{"name":"default","mac":"fa:ba:da:fa:ba:db"}'] -P memory=16385 -P numcpus=16 -P disks=['{"size": 120, "pool": "default"}'] m-master-1
	@$(kcli) create vm -P iso="$(ISO_NAME)" -P nets=['{"name":"default","mac":"fa:ba:da:fa:ba:dc"}'] -P memory=16384 -P numcpus=16 -P disks=['{"size": 120, "pool": "default"}'] m-master-2
	@$(kcli) create vm -P iso="$(ISO_NAME)" -P nets=['{"name":"default","mac":"fa:ba:da:fa:ba:dd"}'] -P memory=16384 -P numcpus=16 -P disks=['{"size": 120, "pool": "default"}'] m-master-3

haproxy-vm:
	@$(kcli) create vm -i fedora35          -P nets=['{"name":"default","mac":"fa:ba:da:fa:ba:d0"}'] -P memory=4096 -P numcpus=2 -P disks=['{"size": 10, "pool": "default"}'] m-haproxy

haproxy-config:
	ssh m-haproxy sudo dnf install -y haproxy
	scp haproxy.cfg m-haproxy:/etc/haproxy/haproxy.cfg
	ssh m-haproxy sudo setsebool -P haproxy_connect_any 1
	ssh m-haproxy sudo systemctl enable --now haproxy

clean: ## Delete nodes
	-@$(kcli) delete vm -y m-bstrap
	-@$(kcli) delete vm -y m-master-1
	-@$(kcli) delete vm -y m-master-2
	-@$(kcli) delete vm -y m-master-3

clean-all: clean
	-@$(kcli) delete vm -y m-haproxy

help:   ## Shows this message.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(shell echo "$(MAKEFILE_LIST) " | tac -s' ') | perl -pe 's/^.*Makefile.*?://g' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
