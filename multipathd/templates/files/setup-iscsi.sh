#!/bin/sh

echo $ISCSI_TARGETS | tr , ' ' | xargs --max-args 1 --no-run-if-empty iscsiadm -m discovery -t sendtargets -p
iscsiadm -m node --login
