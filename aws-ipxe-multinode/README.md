# AWS OpenShift cluster using Assisted Installer via iPXE

We will create a 5 node private cluster in our own VPC

## Steps to automate the provision
1. Create a cluster on [Hybrid Cloud Console](https://console.redhat.com/openshift/assisted-installer/clusters)
2. Prepare a webserver with the needed files. Just follow steps 1, 2 and 3 from the [Guide to Assisted Installer via iPXE in AWS](https://github.com/javipolo/openshift-assisted-installer-tests/tree/main/aws-ipxe#readme)
3. Create your params file. You can use javipolo-aws-ipxe-multi.params as a template
   - Note that you will need an iPXE AMI in your region. If you need to build one, read the last section of this README
4. Apply the cloudformation template:
    ```../bin/cloudformation create yourcluster.params```
5. Follow the wizard in the [Hybrid Cloud Console](https://console.redhat.com/openshift/assisted-installer/clusters), setting `User-Managed Networking`

## Detail of the infrastructure created in AWS
- Launch Template
- 5 EC2 Instances
- 1 Network Load Balancer
- 4 Target groups to be used in the load balancer
   - API
   - MachineConfig
   - Ingress HTTP
   - Ingress HTTPS
- Security group
- Route53 Zone and DNS Records

For sake of simplicity we allow all internal VPC traffic into the security group. It's out of the scope of this demo to harden this better, but due to limitations on Network Load Balancers healthchecks this was the easiest way to achieve this

## How to create your own iPXE AMI
You can create and push your own AMI using iPXE's [aws-import script](https://github.com/ipxe/ipxe/blob/master/contrib/cloud/aws-import)
```
AWS_REGION=eu-west-3
git clone https://github.com/ipxe/ipxe
cd ipxe/src
make CONFIG=cloud EMBED=config/cloud/aws.ipxe bin/ipxe.usb
../contrib/cloud/aws-import -r $AWS_REGION -n "iPXE 1.21.1" bin/ipxe.usb
```
