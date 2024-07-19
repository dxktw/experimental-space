#!/usr/bin/env bash

# Export OpenStack environment variables
export OS_AUTH_TYPE=v3applicationcredential
export OS_AUTH_URL=https://keystone.rumble.cloud
export OS_APPLICATION_CREDENTIAL_ID=a18f623f2cb4495e8440d9d5267c2578
export OS_APPLICATION_CREDENTIAL_SECRET=If6bLp19BuZJ8KEwZT_J7hGSFRIrwXe9qVyFKTQoqrYrF7BcZXtufYgr3_yPNRqArsh2ZEmCXX1ayaroyYNOKA
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
export OS_REGION_NAME=us-east-1

# Ensure openrc.sh exists and source it
if [ -f openrc.sh ]; then
    source openrc.sh
else
    echo "Error: openrc.sh file not found."
    exit 1
fi

# Ensure necessary security group rules
openstack security group rule create --proto tcp --dst-port 22 default
openstack security group rule create --proto tcp --dst-port 80 default
openstack security group rule create --proto tcp --dst-port 443 default

# Correct image ID for Ubuntu-22.04
IMAGE_ID=6bdb68e8-bcfc-4e1d-a714-4041f04b1b5e

# Create instances
openstack server create --flavor 58ca36f0-7ffa-42e6-aea1-1d4b0471d18a --image $IMAGE_ID --nic net-id=ffb9d04d-64f4-43e7-bace-0a5fa5935b95 --security-group default ansible-host
openstack server create --flavor be1edaa1-2048-425e-b047-70632e487b20 --image $IMAGE_ID --nic net-id=ffb9d04d-64f4-43e7-bace-0a5fa5935b95 --security-group default mail-server
openstack server create --flavor f9f64ab1-1288-4cb9-8785-b930d65296b6 --image $IMAGE_ID --nic net-id=ffb9d04d-64f4-43e7-bace-0a5fa5935b95 --security-group default web-server

# Check instance status
for instance in ansible-host mail-server web-server; do
    status=$(openstack server show $instance -f value -c status)
    if [ "$status" != "ACTIVE" ]; then
        echo "Error: Instance $instance is not active. Status: $status"
        exit 1
    fi
done

echo "All instances created and are active."
