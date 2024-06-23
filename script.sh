#!/bin/bash

# Create OpenStack Instances
openstack server create --flavor $ANSIBLE_HOST_FLAVOR --image ubuntu-20.04 --nic net-id=$OS_NETWORK_ID --security-group default ansible-host
ANSIBLE_HOST_IP=$(openstack server list --name ansible-host -f value -c Networks | awk -F'=' '{print $2}')

openstack server create --flavor $MAIL_SERVER_FLAVOR --image ubuntu-20.04 --nic net-id=$OS_NETWORK_ID --security-group default mail-server
MAIL_SERVER_IP=$(openstack server list --name mail-server -f value -c Networks | awk -F'=' '{print $2}')

# Wait for instances to be ready
sleep 60
