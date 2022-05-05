{
  "ignition": {
    "version": "3.1.0"
  },
  "storage": {
    "files": [
      {
        "contents": {
          "source": ("data:text/plain;charset=utf-8;base64," + $MULTIPATHCONF)
        },
        "filesystem": "root",
        "mode": 420,
        "path": "/etc/multipath.conf"
      },
      {
        "contents": {
          "source": ("data:text/plain;charset=utf-8;base64," + $INITIATOR)
        },
        "filesystem": "root",
        "mode": 420,
        "path": "/etc/iscsi/initiatorname.iscsi"
      },
      {
        "contents": {
          "source": ("data:text/plain;charset=utf-8;base64," + $SETUPISCSI)
        },
        "filesystem": "root",
        "mode": 493,
        "path": "/usr/local/bin/setup-iscsi.sh"
      }
    ]
  },
  "systemd": {
    "units": [
      {
        "name": "iscsid.service",
        "enabled": true
      },
      {
        "name": "multipathd.service",
        "enabled": true
      },
      {
        "name": "iscsi-autodiscover.service",
        "enabled": true,
        "contents": "[Unit]\nAfter=iscsi.service\n[Service]\nEnvironment=ISCSI_TARGETS=192.168.130.10,192.168.131.10\nType=oneshot\nExecStart=/usr/local/bin/setup-iscsi.sh\n[Install]\nWantedBy=multi-user.target"
      }
    ]
  }
}
