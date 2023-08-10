# OSTree based dual boot

## Prerequisites

- Create pull-secret.json and write-secret.json files to write and read from the image repositories to be used

## Steps

1. Run backup.sh script in donor openshift
```
scp * core@donor-sno:.
ssh core@donor-sno sudo ./backup.sh
```
2. Run restore.sh script in the recipient openshift:
```
scp * core@recipient-sno:.
ssh core@recipient-sno sudo ./restore.sh
```
3. Reboot recipient and enjoy an in-place ingrade of openshift
