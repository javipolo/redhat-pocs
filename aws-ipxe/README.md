# Installing OpenShift with Assisted Installer via iPXE in AWS EC2 host

We will download the discovery iso, copy the required files to a webserver and then launch a new instance using an iPXE AMI image

## Steps
1. Generate the iso (full) on the AI UI
2. Run the following commands to download the ISO and extract the files
    ```
    sudo mkdir -p /var/tmp/discovery-files

    # Download ISO
    wget -O /var/tmp/discovery-image.iso 'https://<long s3 url provided by AI SaaS>'

    # Mount ISO image to extract files
    sudo mount -o loop /var/tmp/discovery-image.iso /mnt

    # Copy needed files
    sudo cp -v /mnt/images/pxeboot/* /var/tmp/discovery-files
    gzip -dc /mnt/images/ignition.img | sudo cpio -ivD /var/tmp/discovery-files

    # Umount ISO
    sudo umount /mnt
    ```

3. Copy the files to a webserver. In this example we will install a webserver in the same host
    ```
    # Install nginx
    sudo dnf install -y nginx
    sudo sed -i 's%/usr/share/nginx/html%/var/www%g' /etc/nginx/nginx.conf
    sudo systemctl start nginx

    # Copy files to webserver
    sudo cp -vr /var/tmp/discovery-files /var/www

    # Update selinux security context if needed
    sudo chcon -Rt httpd_sys_content_t /var/tmp/discovery-files
    ```

4. Create a new AWS EC2 instance
   Note that we need to set the webserver IP address or domain name in the second line of the user data
    - find and select the AMI `iPXE 1.21.1 (gfa012) (x86_64)`
    - In the section `Configure Instance Details`, in `Advanced Details` we will set the following `User data`:
        ```
        #!ipxe
        set web http://<IP-OF-WEBSERVER>/discovery-files
        initrd --name=initrd ${web}/initrd.img
        kernel ${web}/vmlinuz initrd=initrd coreos.live.rootfs_url=${web}/rootfs.img ignition.config.url=${web}/config.ign ignition.firstboot ignition.platform.id=metal ip=dhcp
        boot
        ```

5. The new instance will boot the discovery image
