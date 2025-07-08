# Adding day2 workers to a cluster, using ACM/assisted installed in the same cluster

## Steps
- Create cluster
```
# Create and install cluster
make cluster
```

- Install RHACM and Assisted Service
```
make lvms assisted-service
```

- Import cluster as local-cluster
Create annotation into AgentServiceConfig to import the cluster as local-cluster
```
make assisted-local-cluster-import
```

- Download day2 ISO
```
make day2-iso-download
```

- Start new VM with day2 ISO
```
make extra-vms
```

- Wait for agent CR to show up
```
make wait-for-agent
```

- Approve agent
```
make approve-agent
```

- Wait for the agent to provision the cluster
```
oc get agent -n local-cluster -w
```
Note: It might get stuck in `Waiting for Control Plane` for long time. It's due to a [bug that will be fixed in future versions](https://github.com/openshift/assisted-installer/pull/1117)
If this happens, the node provision will take 20 extra minutes, until a fallback installation method will kick in. Eventually, the host will be installed

- Check that the node shows up as ready
```
oc get node -w
```
## Bonus. Remove worker role from masters
Since we started with a compact cluster, where all 3 existing nodes have both roles, `master` and `worker`, we can improve the cluster
by leaving the control-plane nodes to serve only as `masters`
To do so, we can just run
make rm-worker-role-from-cp
