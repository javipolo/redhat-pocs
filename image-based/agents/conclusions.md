# Generic problems

## system manager detection
Methods for detecting the system manager might fail when running in `podman build` environment

## /opt is read-only
Since /opt is read-only, if there is the need to update or create something there for agent operation, it will fail

### Possible solutions
#### Symlink /opt to /var/opt
```
mkdir -p /var/opt && rmdir /opt && ln -s /var/opt /opt
```

##### Pros

- It works as other things in rhcos, like /usr/local being a symlink to /var/usrlocal

##### Cons

- SELinux rules that apply to /opt need to be redefined to apply also to /var/opt

#### Use an overlay filesystem

```
[Unit]
Description=OverlayFS for /opt
DefaultDependencies=no
After=local-fs.target
Before=multi-user.target

[Mount]
What=overlay
Where=/opt
Type=overlay
Options=lowerdir=/opt,upperdir=/var/opt/overlay-upper,workdir=/var/opt/overlay-work

[Install]
WantedBy=multi-user.target
```

##### Pros

- The real paths will still be in /opt, so no SELinux tweaks need to be done

##### Cons

- One extra layer while reading/writing on /opt

# Specific problems with agents

## Oracle mgmt_agent

- The way it detects the init service (initd vs systemd) does not work when running inside of a container
```
processName=$(ps --no-headers -o comm 1)
if [[ $processName != "systemd" && $processName != "init" && $processName != *"init"* ]]; then
  log "This Operating System does not have systemd, initd or init.d, aborting the install" "\t\t%s\n"
  exit 1
fi
```
- After trying to manually run all the pre/post installation scripts, they always fail to detect the initd/systemd and thus fail to create the systemd services

## crowdstrike falcon

There is already work done by crowdstrike for this: https://github.com/CrowdStrike/falcon-bootc
- The main problem is that /opt is not writeable. It can be solved either with symlinks or overlayfs solution
