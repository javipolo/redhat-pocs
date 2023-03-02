# Install RT kernel in microshift r4e

## Download RPMs
We need to download the needed RPMs and all the dependencies

We will do this in the host used to create the microshift-r4e ISO image
```
sudo subscription-manager repos --enable rhel-8-for-x86_64-rt-rpms
mkdir -p kernel-packages/all
cd kernel-packages/all
sudo dnf download kernel-rt --resolve --alldeps
cd -
```

## Copy the packages to the microshift-edge host
```
scp -r kernel-packages redhat@microshift-edge:.
```

## Sort the packages
We need to first install all the dependencies, update a couple of packages, and then replace the kernel packages
We will sort all this out in directories for simpliticy

### Find out whats needed
By trying to install the kernel-rt package, dependencies will keep popping up, and with this we will make a list of the needed packages
```
cd kernel-packages
sudo rpm-ostree update override all/kernel-rt-*
```

### Do the sorting
Here's the list of things I needed, if the RHEL version changes, the list might be different
```
mkdir replace deps kernel python
mv all/dracut-049-218.git20221019.el8_7.x86_64.rpm \
   all/dracut-network-049-218.git20221019.el8_7.x86_64.rpm \
   all/dracut-config-generic-049-218.git20221019.el8_7.x86_64.rpm \
   replace

mv all/dmidecode-3.3-4.el8.x86_64.rpm \
   all/dracut-squash-049-218.git20221019.el8_7.x86_64.rpm \
   all/ethtool-5.13-2.el8.x86_64.rpm \
   all/kexec-tools-2.0.24-6.el8.x86_64.rpm \
   all/lzo-2.08-14.el8.x86_64.rpm \
   all/rt-setup-2.1-4.el8.x86_64.rpm \
   all/snappy-1.1.8-3.el8.x86_64.rpm \
   all/squashfs-tools-4.3-20.el8.x86_64.rpm \
   all/tuna-0.18-1.el8.noarch.rpm \
   all/tuned-2.19.0-1.1.20221013git12fa4d58.el8fdp.noarch.rpm \
   all/tuned-profiles-realtime-2.19.0-1.1.20221013git12fa4d58.el8fdp.noarch.rpm \
   all/virt-what-1.25-1.el8.x86_64.rpm \
   deps

# IDK why trying to install python packages with the rest created a weird rpm-ostree error, so I just did it in a different batch
mv all/python3-ethtool-0.14-5.el8.x86_64.rpm \
   all/python3-linux-procfs-0.7.0-1.el8.noarch.rpm \
   all/python3-perf-4.18.0-425.10.1.el8_7.x86_64.rpm \
   all/python3-pyudev-0.21.0-7.el8.noarch.rpm \
   all/python3-syspurpose-1.28.32-1.el8.x86_64.rpm \
   python

mv all/kernel-rt* kernel
```


## Install RPMs
```
sudo rpm-ostree override replace replace/*
sudo rpm-ostree install python/*
sudo rpm-ostree install deps/*
sudo rpm-ostree override remove kernel kernel-core kernel-modules --install kernel/kernel-rt-4.18.0-425.10.1.rt7.220.el8_7.x86_64.rpm --install kernel/kernel-rt-core-4.18.0-425.10.1.rt7.220.el8_7.x86_64.rpm --install kernel/kernel-rt-modules-4.18.0-425.10.1.rt7.220.el8_7.x86_64.rpm
```

## Reboot the node
```
sudo systemctl reboot
```
