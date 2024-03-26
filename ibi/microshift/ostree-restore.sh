seed_image=$1
lvm_options="--karg-append rd.lvm.lv=rhel/root --karg-append root=/dev/mapper/rhel-root"

build_kargs(){
    local karg
    jq -r '.spec.kernelArguments[]' ${img_mnt}/mco-currentconfig.json \
        | while IFS= read -r line; do
            echo -n "--karg-append $line "
        done
}

podman pull --authfile /var/tmp/backup-secret.json $seed_image
img_mnt=$(podman image mount ${seed_image})
upg_booted_id=$(jq -r '.deployments[] | select(.booted == true) | .id' ${img_mnt}/rpm-ostree.json)
upg_booted_deployment=${upg_booted_id/*-}
upg_booted_ref=${upg_booted_deployment/\.*}
up_ver=$(jq -r '.seed_cluster_ocp_version' ${img_mnt}/manifest.json)
new_osname=rhcos_${up_ver}
echo $new_osname
ostree_repo=$(mktemp -d -p /var/tmp)
tar xzf $img_mnt/ostree.tgz --selinux -C $ostree_repo
ostree pull-local --repo /ostree/repo $ostree_repo
ostree admin os-init $new_osname
#ostree admin deploy --not-as-default --os ${new_osname} ${upg_booted_ref}
ostree admin deploy --os ${new_osname} $(build_kargs) $lvm_options ${upg_booted_ref}
ostree_deploy=$(ostree admin status | awk /$new_osname/'{print $2}')
deploy_path=/ostree/deploy/$new_osname/deploy/$ostree_deploy

cp ${img_mnt}/ostree-${upg_booted_deployment}.origin $deploy_path.origin
tar xzf ${img_mnt}/var.tgz -C /ostree/deploy/$new_osname --selinux
tar xzf ${img_mnt}/etc.tgz -C $deploy_path --selinux
cat ${img_mnt}/etc.deletions | xargs --no-run-if-empty -ifile rm -f $deploy_path/file

ostree admin status

# Manual tweaks
cp $deploy_path/usr/lib/os-release /sysroot/etc/
