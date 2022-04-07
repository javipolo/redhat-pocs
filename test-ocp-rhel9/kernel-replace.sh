#!/bin/bash

set -e

rpm_url=http://download.eng.bos.redhat.com/rhel-9/nightly/RHEL-9/latest-RHEL-9/compose/BaseOS/x86_64/os/Packages
arch=x86_64
version=$(curl -sL $rpm_url | awk -F\" '/kernel-5/{print $6}'| sed -E "s/kernel-(.+).${arch}.rpm\$/\1/")
packages='kernel kernel-core kernel-modules kernel-modules-extra'

# Allow pods in default namespace to create privileged containers
oc adm policy add-scc-to-user privileged -z default

cat <<EOF | oc apply -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: kernel-replace
data:
  entrypoint.sh: |
    #!/bin/sh

    set -euo pipefail

    LOG_FILE="/opt/log/installed_rpms.txt"
    LOG_DIR=\$(dirname \${LOG_FILE})
    TEMP_DIR=\$(mktemp -d)

    function finish {
      rm -Rf \${TEMP_DIR}
    }
    trap finish EXIT

    if [ -f "\${LOG_FILE}" ]; then
      if grep -Fxq "\${RPMS_CM_ID}" \${LOG_FILE}; then
        echo "Kernel is already upgraded to ${version}"
        exit 0
      fi
    fi

    SYSTEMD_OFFLINE=1 rpm-ostree reset

    # Fetch required packages
    install_rpms=""
    for package in ${packages}; do
      rpm_name=\${package}-${version}.${arch}.rpm
      install_rpms="\${install_rpms} \${TEMP_DIR}/\${rpm_name}"
      curl -s $rpm_url/\${rpm_name} -o \${TEMP_DIR}/\${rpm_name}
    done

    SYSTEMD_OFFLINE=1 rpm-ostree override replace \${install_rpms}

    mkdir -p \${LOG_DIR}
    rm -rf \${LOG_FILE}
    echo \${RPMS_CM_ID} > \${LOG_FILE}

    rm -Rf \${TEMP_DIR}

    # Reboot to apply changes
    systemctl reboot
EOF

cm_id=$(oc get configmap kernel-replace -o jsonpath={.metadata.resourceVersion})

cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kernel-replace
  labels:
    app: kernel-replace
spec:
  selector:
    matchLabels:
      app: kernel-replace
  template:
    metadata:
      labels:
        app: kernel-replace
    spec:
      hostNetwork: true
      containers:
      - name: kernel-replace
        image: ubi8/ubi-minimal
        command: ['sh', '-c', 'cp /script/entrypoint.sh /host/tmp && chmod +x /host/tmp/entrypoint.sh && echo "Installing rpms" && chroot /host /tmp/entrypoint.sh && sleep infinity']
        securityContext:
          privileged: true
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: FallbackToLogsOnError
        env:
          - name: RPMS_CM_ID
            value: "${cm_id}"
        volumeMounts:
        - mountPath: /script
          name: rpms-script
        - mountPath: /host
          name: host
      hostNetwork: true
      restartPolicy: Always
      terminationGracePeriodSeconds: 10
      volumes:
      - configMap:
          name: kernel-replace
        name: rpms-script
      - hostPath:
          path: /
          type: Directory
        name: host
EOF
