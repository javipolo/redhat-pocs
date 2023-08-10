#!/bin/bash

log_it(){
    echo $@ | tr [:print:] -
    echo $@
    echo $@ | tr [:print:] -
}

log_it Stopping kubelet and crio
systemctl stop kubelet
crictl ps -q | xargs crictl stop
systemctl stop crio

log_it Cleaning /var
# Clean journal
journalctl --flush --rotate --vacuum-time=1s
journalctl --user --flush --rotate --vacuum-time=1s
rm -fr /var/log/pods/*
for i in $(find /var/log -type f -name "*.log"); do > $i; done

log_it Creating backup datadir
mkdir /var/tmp/backup
tar czf /var/tmp/backup/var.tgz \
    --exclude='/var/tmp/*' \
    --exclude='/var/lib/log/*' \
    --exclude='/var/lib/containers/*' \
    --exclude='/var/lib/kubelet/pods/*' \
    --selinux \
    /var
ostree admin config-diff | awk '{print "/etc/" $2}' | xargs tar czf /var/tmp/backup/etc.tgz
rpm-ostree status > /var/tmp/backup/rpm-ostree.status
ostree commit --branch backup /var/tmp/backup

# Create credentials for pushing the generated image
mkdir /root/.docker
cp write-secret.json /root/.docker/config.json

log_it Encapsulating and pushing backup OCI
ostree container encapsulate backup registry:quay.io/jpolo/ostmagic:backup --repo /ostree/repo --label ostree.bootable=true
