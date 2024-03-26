pull_secret=path/to/pull-secret.json
backup_secret=path/to/backup-secret.json
seed_version=4.15.2
seed_image=quay.io/user/whatever:${seed_version}-directory

scp $pull_secret user@microshift:/var/tmp/pull-secret.json
scp $backup_secret user@microshift:/var/tmp/backup-secret.json
scp ostree-restore.sh user@microshift:/var/tmp/ostree-restore.sh

ssh user@microshift sudo bash /var/tmp/ostree-restore.sh "$seed_image"
