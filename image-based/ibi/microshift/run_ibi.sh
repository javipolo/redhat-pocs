pull_secret=path/to/pull-secret.json
backup_secret=path/to/backup-secret.json
lca_image=quay.io/openshift-kni/lifecycle-agent-operator:latest
seed_version=4.15.2
seed_image=quay.io/user/whatever:${seed_version}-directory

scp $pull_secret user@microshift:/var/tmp/pull-secret.json
scp $backup_secret user@microshift:/var/tmp/backup-secret.json

cat << EOF | ssh user@microshift bash -s
sudo podman pull --authfile /var/tmp/backup-secret.json $seed_image
echo sudo mount -o bind /sysroot /mnt
echo sudo podman run --privileged --rm --pid=host -v /:/host --entrypoint /usr/local/bin/lca-cli $lca_image ibi \
    --precache-disabled \
    --seed-image $seed_image \
    --seed-version $seed_version \
    --authfile /var/tmp/backup-secret.json \
    --pullSecretFile /var/tmp/pull-secret.json
EOF
