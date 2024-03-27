# Image Based Upgrades using bifrost containers as seed images

## Creating a seed image
So far the seed image is generated with several steps:

1. Once you have a seed cluster, generate a OCI image with
```
ostree container encapsulate --repo /ostree/repo $(rpm-ostree status --booted --json | jq -r '.deployments[0]["checksum"]') registry:quay.io/jpolo/bifrost:base
```

I'm also experimenting doing it with

```
REGISTRY_AUTH_FILE=/var/tmp/config.json rpm-ostree compose container-encapsulate --repo /ostree/repo $(rpm-ostree status --booted --json | jq -r '.deployments[0]["checksum"]') registry:quay.io/jpolo/bifrost:base
```

2. Build a normal seed image, and copy the contents to rhcos/seed/ directory, excluding the ostree.tgz file

3. Combine everything into a bootable container with
```
make build push
```

4. Now, deploy a modified LCA version to handle this type of images into a cluster you want to upgrade. The modified LCA is in https://github.com/javipolo/lifecycle-agent/tree/bifrost. If you want to avoid creating a container from this, you can deploy quay.io/jpolo/lifecycle-agent:bifrost container

5. Now, do a normal IBU using the modified image
