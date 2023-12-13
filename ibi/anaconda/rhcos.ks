text

# Basic partitioning
clearpart --all --initlabel --disklabel=gpt

part biosboot  --size=1    --fstype=biosboot
part /boot/efi --size=127  --fstype=efi      --label=EFI-SYSTEM
part /boot     --size=384  --fstype=ext2     --label=boot
part /         --grow      --fstype xfs      --label=root

ostreecontainer --url quay.io/jpolo/ibi:latest --no-signature-verification
firewall --disabled
services --enabled=sshd

# Only inject a SSH key for root
#rootpw --iscrypted locked
rootpw anaconda
sshkey --username root "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuJP7bS3YNBQz5fDlyyZ7FlIXEK9xaGLxGZcaH/7vTe root@rdu-infra-edge-13.infra-edge.lab.eng.rdu2.redhat.com"
# reboot

# Install via bootupd - TODO change anaconda to auto-detect this
bootloader --location=none --disabled
%post --log /var/log/bootupd.log

mkdir -p /boot/grub2
/bin/cp /etc/ibi/grub.cfg /boot/grub2/grub.cfg

mkdir -p /dev/disk/by-partlabel
ln -s /dev/disk/by-label/EFI-SYSTEM /dev/disk/by-partlabel/
/usr/bin/bootupctl backend install --with-uuids /

INSTALL_HD=$(find /dev -name "$(lsblk -ndo pkname /dev/disk/by-label/EFI-SYSTEM)")
grub2-install $INSTALL_HD

%end
