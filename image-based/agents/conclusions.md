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

## running ansible

### At runtime

It should work properly, unless the playbook ends up trying to modify files outside of /var or /etc

It will obviously fail if it needs to install RPMs

#### Possible solutions

Run ansible at build time to install and set everything up, then ansible can be run in runtime to update configurations and control that services are up and running

### At build time

When running ansible at build time, everything that tries to check or restart a service will fail, so the roles need to be adjusted to include way sof skipping those checks, for example by adding tags, when clauses based in variables or any other way

# Problems with specific agents

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

## datadog-agent

When running ansible at build time, there were two things to tweak to prevent ansible from trying to check or restart the datadog-agent service
- Setting up a variable `datadog_skip_running_check=true`
- Disabling the handlers that restart the agents. To do so I needed to modify the ansible code:
```
yq -y 'map(.when = false)' /tmp/ansible/ansible_collections/datadog/dd/roles/agent/handlers/main.yml
```

With those tweaks, the image builds without problems, and I can run ansible in the installed system without problems

I assume that if there is an update of the RPM in the repo there will be problems, though, so probably there should also be a condition to disable the update of the agent in the ansible code
