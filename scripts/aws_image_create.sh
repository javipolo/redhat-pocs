#!/bin/bash

set -o errexit # Halt on error

usage(){
    cat << EOF
    $0 - Upload AMI raw file to AWS and convert it to AMI Image ready to use

    Usage:
    $0 local_raw_ami ami_name region bucket

    Example
    $0 path/to/disk.raw rhelai-custom-version us-east-1 my-ami-bucket
EOF
exit 1
}

if [[ $# -lt 4 ]]; then
    usage
fi

local_ami="$1"
ami_name="$2"
region="$3"
bucket="$4"

# Volume size in GB
default_volume_size=1000
raw_ami="$(basename "$local_ami")-${ami_name}.raw"
s3_ami="s3://${bucket}/${raw_ami}"
tmpfile=$(mktemp)

echo "== Convert to AMI =="
echo "====================="
echo "Source file:    $local_ami"
echo "Output AMI:     $ami_name"
echo "Region:         $region"
echo "Bucket:         $bucket"
echo "Temporary file: $s3_ami"
echo "====================="
echo

echo "Uploading $local_ami to S3"
aws s3 cp "$local_ami" "$s3_ami"

echo "Importing Snapshot"
printf '{ "Description": "my-image", "Format": "raw", "UserBucket": { "S3Bucket": "%s", "S3Key": "%s" } }' $bucket "$raw_ami" > $tmpfile
task_id=$(aws ec2 import-snapshot --region $region --disk-container file://$tmpfile | jq -r .ImportTaskId)

# Wait for snapshot to be imported
while aws ec2 describe-import-snapshot-tasks --region $region --filters Name=task-state,Values=active | jq -r '.ImportSnapshotTasks[].ImportTaskId' | grep -qx $task_id; do
    echo -n .; sleep 1
done; echo

snapshot_id=$(aws ec2 describe-snapshots --region $region | jq -r '.Snapshots[] | select(.Description | contains("'${task_id}'")) | .SnapshotId')
aws ec2 create-tags --region $region --resources $snapshot_id --tags Key=Name,Value="$ami_name"

echo "Registering AMI"
ami_id=$(aws ec2 register-image  \
    --name "$ami_name" \
    --description "$ami_name" \
    --architecture x86_64 \
    --root-device-name /dev/sda1 \
    --ena-support \
    --region $region \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=${default_volume_size},SnapshotId=${snapshot_id}}" \
    --virtualization-type hvm \
    | jq -r .ImageId)
aws ec2 create-tags --region $region --resources $ami_id --tags Key=Name,Value="$ami_name"

# Cleanup
aws s3 rm "$s3_ami"
rm -f "$tmpfile"

echo "Created AMI $ami_id with name $ami_name"
