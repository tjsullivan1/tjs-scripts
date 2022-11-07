#!/bin/bash

# Disable selinux
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# Disable firewall
## This step was already done 


# Configure sysctl file
echo "vm.overcommit_memory = 2 # See Segment Host Memory" | sudo tee -a /etc/sysctl.conf
echo "vm.overcommit_ratio = 95 # See Segment Host Memory" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.ip_local_reserved_ports=65330" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.ipfrag_high_thresh = 41943040" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.ipfrag_low_thresh = 31457280" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.ipfrag_time = 60" | sudo tee -a /etc/sysctl.conf
echo "vm.dirty_background_ratio = 0" | sudo tee -a /etc/sysctl.conf
echo "vm.dirty_ratio = 0" | sudo tee -a /etc/sysctl.conf
echo "vm.dirty_background_bytes = 1610612736 # 1.5GB" | sudo tee -a /etc/sysctl.conf
echo "vm.dirty_bytes = 4294967296 # 4GB" | sudo tee -a /etc/sysctl.conf 

sudo sysctl -p

# Configure limits.conf
sudo sed -i 's/4096/131072/' /etc/security/limits.d/20-nproc.conf
echo "* soft nofile 524288" | sudo tee -a  /etc/security/limits.d/20-nproc.conf
echo "* hard nofile 524288" | sudo tee -a  /etc/security/limits.d/20-nproc.conf
echo "* hard nproc 131072" | sudo tee -a  /etc/security/limits.d/20-nproc.conf

# Configure THP
sudo grubby --update-kernel=ALL --args="transparent_hugepage=never"