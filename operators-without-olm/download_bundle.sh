#!/bin/bash

action=download
image="$1"
name="$2"
local_name=tmp_$RANDOM
pull_secret=$HOME/.pull-secret.json
tmp_dir=$(mktemp -d)
outdir=bundles

function cleanup(){
    rm -fr $tmp_dir
    podman rm $local_name > /dev/null
}
trap cleanup EXIT

podman create --authfile "$pull_secret" --name $local_name "$image" true > /dev/null

podman export $local_name | tar xC $tmp_dir

if [[ -z "$name" ]]; then
    csv_file=$(grep -rl '^kind: ClusterServiceVersion' $tmp_dir/manifests | head -n1)
    name=$(yq -r .metadata.name $csv_file | cut -d . -f 1)
fi

echo "Downloading to $outdir/$name"
if [[ -e $outdir/$name ]]; then
    echo "ERROR. $outdir/$name already exists"
    exit 1
fi

mkdir -p $outdir
cp -a $tmp_dir $outdir/$name
