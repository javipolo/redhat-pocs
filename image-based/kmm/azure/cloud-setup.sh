#!/bin/bash

set -o errexit

# mv /etc/selinux /etc/selinux.tmp
dnf install -y --nobest \
    cloud-init \
    hyperv-daemons \
    langpacks-en \
    NetworkManager-cloud-setup \
    nvme-cli \
    patch \
    rng-tools \
    uuid \
    WALinuxAgent
# mv /etc/selinux.tmp /etc/selinux

# WAAgent configuration
sed -i \
    -e '/^ResourceDisk.Format=y/c\ResourceDisk.Format=n' \
    -e '/^ResourceDisk.EnableSwap=y/c\ResourceDisk.EnableSwap=n' \
    -e '/^Provisioning.RegenerateSshHostKeyPair=y/c\Provisioning.RegenerateSshHostKeyPair=n' \
    /etc/waagent.conf
