include ../Makefile.globals

NET_NAME=ipxe

net:
	-sudo virsh net-define net.xml
	-sudo virsh net-autostart ${NET_NAME}
	-sudo virsh net-start ${NET_NAME}

clean: clean-vms clean-cluster
