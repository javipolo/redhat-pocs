# Image Based Installation (IBI) using coreos-installer

This PoC will:
- Install vanilla RHCOS to disk
- Mount the installation disk
- Create shared /var/lib/containers directory
- Restore SNO present in SEED_IMAGE

### TODO
- Use LifeCycle Agent binary to perform the restoration
- Add example configuration files/certs so we can have a working full run
- Embed pull-secret for downloading the seed image

## Steps
1. Define a few environment variables:
```
export SEED_IMAGE=quay.io/whatever/ostbackup:seed
export SSH_PUBLIC_KEY=~/.ssh/id_dsa.pub
export PULL_SECRET=$(jq -c . /path/to/my/pull-secret.json)
export BACKUP_SECRET=$(jq -c . /path/to/my/repo/credentials.json)
```

2. Prepare a coreos live iso with a custom ignition
```
make iso
```

3. Provision VM
```
make vm
```

3. Check progress
```
make logs
```

4. Attach configuration ISO
5. Reboot VM
```
virsh reboot ibi
```
