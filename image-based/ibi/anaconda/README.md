# Install RHCOS container using anaconda

Take in mind that this is just a PoC to see if our approach works

## Steps
1. Download fedora netinst and update grub configuration to include the kickstart installation options `inst.ks=http://192.168.122.1:8181/rhcos.ks inst.profile=rhel`
```make iso-download iso-prepare```

2. Start an HTTP server that will serve the kickstart file
```
make http
```

3. Add a grub.cfg file to the bootable container. We will use this file in the anaconda post installation script
```
make bp-image
```

4. Provision VM
```
make vm
```
