#!/usr/bin/env bash

export OS_AUTH_TYPE=v3applicationcredential
export OS_AUTH_URL=https://keystone.rumble.cloud

# With Keystone you pass the keystone password.
export OS_APPLICATION_CREDENTIAL_ID=a18f623f2cb4495e8440d9d5267c2578

export OS_APPLICATION_CREDENTIAL_SECRET=If6bLp19BuZJ8KEwZT_J7hGSFRIrwXe9qVyFKTQoqrYrF7BcZXtufYgr3_yPNRqArsh2ZEmCXX1ayaroyYNOKA

export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
export OS_REGION_NAME=us-east-1

# Source the openrc.sh file
source openrc.sh

# Create instances
openstack server create --flavor 58ca36f0-7ffa-42e6-aea1-1d4b0471d18a --image ubuntu-20.04 --nic net-id=ffb9d04d-64f4-43e7-bace-0a5fa5935b95 --security-group default ansible-host
openstack server create --flavor be1edaa1-2048-425e-b047-70632e487b20 --image ubuntu-20.04 --nic net-id=ffb9d04d-64f4-43e7-bace-0a5fa5935b95 --security-group default mail-server
openstack server create --flavor f9f64ab1-1288-4cb9-8785-b930d65296b6 --image ubuntu-20.04 --nic net-id=ffb9d04d-64f4-43e7-bace-0a5fa5935b95 --security-group default web-server
