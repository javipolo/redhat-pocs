# Partition disk such that it contains an LVM volume group called `rhel` with a
# 10GB+ system root but leaving free space for the LVMS CSI driver for storing data.
#
# For example, a 20GB disk would be partitioned in the following way:
#
# NAME          MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
# sda             8:0    0  20G  0 disk
# ├─sda1          8:1    0 200M  0 part /boot/efi
# ├─sda1          8:1    0 800M  0 part /boot
# └─sda2          8:2    0  19G  0 part
#  └─rhel-root  253:0    0  10G  0 lvm  /sysroot
#
ostreesetup --nogpg --osname=rhel --remote=edge --url=file:///run/install/repo/ostree/repo --ref=rhel/9/x86_64/edge
zerombr
# clearpart --all --initlabel --disklabel=gpt
clearpart --all --initlabel
part /boot/efi --fstype=efi --size=200 --label=EFI-SYSTEM
part /boot     --fstype=xfs --size=800 --label=boot         --asprimary
# Uncomment this line to add a SWAP partition of the recommended size
#part swap --fstype=swap --recommended
part pv.01 --grow

volgroup rhel pv.01
logvol / --vgname=rhel --fstype=xfs --size=70000 --name=root

network --hostname=microshift --bootproto=dhcp --device=ens3
reboot

%post --log=/var/log/anaconda/post-install.log --erroronfail

# Add the pull secret to CRI-O and set root user-only read/write permissions
cat > /etc/crio/openshift-pull-secret << EOF
INSERT_PULL_SECRET_HERE
EOF
chmod 600 /etc/crio/openshift-pull-secret

echo 'user        ALL=(ALL)       NOPASSWD: ALL' >> /etc/sudoers

# Configure the firewall with the mandatory rules for MicroShift
firewall-offline-cmd --zone=trusted --add-source=10.42.0.0/16
firewall-offline-cmd --zone=trusted --add-source=169.254.169.1

%end
