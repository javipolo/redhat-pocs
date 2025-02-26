# Generic problems

## alternatives is not working
EDIT: Fixed in RHEL 9.5. See https://github.com/coreos/rpm-ostree/issues/1614
`alternatives` is not working, not in build time or runtime

To work at build time:
```
ln -s /usr/lib/alternatives /var/lib/alternatives
```

To work also at run time:
```
mkdir /var/lib/alternatives
```

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

First idea is that it should work properly, unless the playbook ends up trying to modify files outside of /var or /etc

It will obviously fail if it needs to install RPMs

However, it does not seem to be so straightforward

Known problems at runtime:
- files cannot be modified outside of /etc and /var (this is obvious0
- `package` fails to work properly, even to just check that some packages are ALREADY installed, because `ansible_pkg_mgr` is detected as `atomic_container`

### At build time

Known problems:

- Managing services (restart, or check) does not work. The roles need to be adjusted to include way sof skipping those checks, for example by adding tags, when clauses based in variables or any other way
- Using `package` seems to also be problematic: Unsupported parameters for (ansible.legacy.dnf) module: use_backend.

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
UPDATE: I downgraded datadog-agent RPM on build time, and then while running ansible on runtime, it did not try to update the RPM
