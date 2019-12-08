#!/bin/bash
# installBastion.sh
# 
# Execute this script as root


# DNS installation
echo 'installing bind-chroot DNS server...'

dnf install -y bind-chroot

echo 'bind-chroot DNS server installed!'


# TFTP installation
echo 'installing TFTP server and iPXE boot images...'

dnf install -y tftp-server ipxe-bootimgs
mkdir -p /var/lib/tftpboot
cp /usr/share/ipxe/undionly.kpxe /var/lib/tftpboot

echo 'TFTP server and iPXE boot images installed!'


# DHCP installation
echo 'installing DHCP server...'

dnf install -y dhcp-server

echo 'DHCP server installed!'


# Matchbox installation
echo 'installing Matchbox server...'

pushd /tmp
wget https://github.com/poseidon/matchbox/releases/download/v0.8.0/matchbox-v0.8.0-linux-amd64.tar.gz
tar -xzf matchbox-v0.8.0-linux-amd64.tar.gz
cd matchbox-v0.8.0-linux-amd64
cp matchbox /usr/local/bin
cp contrib/systemd/matchbox-local.service /etc/systemd/system/matchbox.service
mkdir /etc/matchbox
mkdir -p /var/lib/matchbox/{assets,groups,ignition,profiles}
cd /var/lib/matchbox/assets
RHCOS_BASEURL=https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/
wget ${RHCOS_BASEURL}/4.2/latest/rhcos-4.2.0-x86_64-installer-initramfs.img
wget ${RHCOS_BASEURL}/4.2/latest/rhcos-4.2.0-x86_64-installer-kernel
wget ${RHCOS_BASEURL}/4.2/latest/rhcos-4.2.0-x86_64-metal-bios.raw.gz
useradd -U -r matchbox
popd

echo 'Matchbox server installed!'


# HAProxy installation
echo 'installing HAProxy server...'

dnf install -y haproxy
setsebool -P haproxy_connect_any on

echo 'HAProxy server installed!'



# Firewall configuration
echo 'configuring firewall...'

# Enable IP-forwarding immediately
sysctl -w net.ipv4.ip_forward=1

# Enable IP-forwarding on boot
sysctl net.ipv4.ip_forward > /etc/sysctl.d/1_ip_forward.conf

# Enable router
# firewall-cmd --permanent --zone=external --add-masquerade
# Set via zones assigned to network interfaces

# Open ports
firewall-cmd --permanent --zone internal --add-service=dns
firewall-cmd --permanent --zone internal --add-service=tftp
firewall-cmd --permanent --zone internal --add-service=dhcp
# Matchbox port
firewall-cmd --permanent --zone internal --add-port=8080/tcp
firewall-cmd --permanent --zone internal --add-port=22623/tcp
firewall-cmd --permanent --zone internal --add-service=http
firewall-cmd --permanent --zone internal --add-service=https
firewall-cmd --permanent --zone internal --add-port=6443/tcp

firewall-cmd --permanent --zone external --add-service=http
firewall-cmd --permanent --zone external --add-service=https
firewall-cmd --permanent --zone external --add-port=6443/tcp


# Apply changes
systemctl restart firewalld

echo 'firewall configured!'


# Apply configuration
cp -r bastion/* /

systemctl daemon-reload

# Enable and start services
systemctl enable named-chroot.service
systemctl enable tftp.service
systemctl enable dhcpd.service
systemctl enable matchbox.service
systemctl enable haproxy.service

systemctl start named-chroot.service
systemctl start tftp.service
systemctl start dhcpd.service
systemctl start matchbox.service
systemctl start haproxy.service


# Create SSH keypair
ssh-keygen -t rsa -b 2048 -N '' -f /root/.ssh/id_rsa


# OpenShift installation binaries
OCP4_BASEURL=https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.8
curl -s ${OCP4_BASEURL}/openshift-install-linux-4.2.8.tar.gz | tar -xzf - -C /usr/local/bin/ openshift-install
curl -s ${OCP4_BASEURL}/openshift-client-linux-4.2.8.tar.gz | tar -xzf - -C /usr/local/bin/ oc






