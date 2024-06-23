#!/usr/bin/env bash

# Source the openrc.sh file
source openrc.sh

# Create instances
openstack server create --flavor 58ca36f0-7ffa-42e6-aea1-1d4b0471d18a --image ubuntu-20.04 --nic net-id=ffb9d04d-64f4-43e7-bace-0a5fa5935b95 --security-group default ansible-host
openstack server create --flavor be1edaa1-2048-425e-b047-70632e487b20 --image ubuntu-20.04 --nic net-id=ffb9d04d-64f4-43e7-bace-0a5fa5935b95 --security-group default mail-server
openstack server create --flavor f9f64ab1-1288-4cb9-8785-b930d65296b6 --image ubuntu-20.04 --nic net-id=ffb9d04d-64f4-43e7-bace-0a5fa5935b95 --security-group default web-server
